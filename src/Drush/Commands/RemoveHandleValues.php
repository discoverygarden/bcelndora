<?php

namespace Drupal\bcelndora\Drush\Commands;

use Drupal\Core\Batch\BatchBuilder;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drush\Attributes as CLI;
use Drush\Commands\DrushCommands;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * Command for BCELN to remove field_handle values.
 */
class RemoveHandleValues extends DrushCommands {

  private const BATCH_SIZE = 100;
  private const LOGGER_CHANNEL = 'bcelndora';

  public function __construct(
    #[Autowire(service: 'entity_type.manager')]
    protected EntityTypeManagerInterface $entityTypeManager,
  ) {
    parent::__construct();
  }

  /**
   * Command to remove handles.
   */
  #[CLI\Command(name: 'bcelndora:remove-handle-values')]
  #[CLI\Option(name: 'dry-run', description: 'Simulate the command without making any changes.')]
  #[CLI\Option(name: 'only-if-value', description: 'Only process nodes where the handle matches this string exactly.')]
  #[CLI\Option(name: 'logging', description: 'Show logging messages per node.')]
  public function removeHandleValues(
    array $options = [
      'dry-run' => FALSE,
      'only-if-value' => NULL,
      'logging' => FALSE,
    ],
  ): void {
    $node_storage = $this->entityTypeManager->getStorage('node');
    $query = $node_storage->getQuery()
      ->condition('type', 'islandora_object')
      ->accessCheck(FALSE)
      ->exists('field_handle');

    if (!empty($options['only-if-value'])) {
      $this->io()->writeln(sprintf("Filtering for nodes where field_handle is '%s'.", $options['only-if-value']));
      $query->condition('field_handle', $options['only-if-value']);
    }

    $count = $query->count()->execute();

    if ($count === 0) {
      $this->io()->writeln('No matching nodes found.');
      return;
    }

    $this->io()->writeln(sprintf('Found %d nodes to process.', $count));
    if ($options['dry-run']) {
      $this->io()->warning('In dry run state.');
    }

    $batch_builder = new BatchBuilder();
    $batch_builder
      ->setTitle('Clearing field_handle values')
      ->setInitMessage('Starting handle clearing process...')
      ->setErrorMessage('An error occurred during processing.')
      ->setFinishCallback([static::class, 'batchFinished'])
      ->addOperation([static::class, 'processBatch'], [$options]);

    batch_set($batch_builder->toArray());
    drush_backend_batch_process();
  }

  /**
   * Batch processing for handle removal.
   */
  public static function processBatch(array $options, array &$context): void {
    $messenger = \Drupal::messenger();
    $node_storage = \Drupal::entityTypeManager()->getStorage('node');

    if (empty($context['sandbox'])) {
      $count_query = $node_storage->getQuery()
        ->condition('type', 'islandora_object')
        ->accessCheck(FALSE)
        ->exists('field_handle');

      if (!empty($options['only-if-value'])) {
        $count_query->condition('field_handle', $options['only-if-value']);
      }

      $context['sandbox']['progress'] = 0;
      $context['sandbox']['max'] = $count_query->count()->execute();
      $context['results'] = [
        'processed' => 0,
        'changed' => 0,
        'skipped_value' => 0,
        'skipped_empty' => 0,
        'dry_run' => $options['dry-run'],
      ];
    }

    $paged_query = $node_storage->getQuery()
      ->condition('type', 'islandora_object')
      ->accessCheck(FALSE)
      ->exists('field_handle')
      ->sort('nid')
      ->range($context['sandbox']['progress'], self::BATCH_SIZE);

    if (!empty($options['only-if-value'])) {
      $paged_query->condition('field_handle', $options['only-if-value']);
    }

    $nids_to_process = $paged_query->execute();

    if (empty($nids_to_process)) {
      $context['finished'] = 1;
      return;
    }

    $nodes = $node_storage->loadMultiple($nids_to_process);

    foreach ($nodes as $node) {
      $nid = $node->id();
      $current_value = $node->get('field_handle')->value;
      $log_context = ['@nid' => $nid, '@current' => $current_value];

      $context['results']['changed']++;
      if ($options['dry-run']) {
        if ($options['logging']) {
          $messenger->addMessage(t('[DRY-RUN] Would clear handle on node @nid. Current value: "@current".', $log_context));
        }
      }
      else {
        $node->set('field_handle', NULL);
        $node->save();
        if ($options['logging']) {
          $messenger->addMessage(t('Cleared handle on node @nid. Old value was: "@current".', $log_context));
        }
      }
    }

    $context['sandbox']['progress'] += count($nids_to_process);
    $context['results']['processed'] += count($nids_to_process);

    if ($context['sandbox']['progress'] < $context['sandbox']['max']) {
      $context['finished'] = $context['sandbox']['progress'] / $context['sandbox']['max'];
    }
    else {
      $context['finished'] = 1;
    }
  }

  /**
   * Batch finished.
   */
  public static function batchFinished($success, $results, $operations): void {
    $logger = \Drupal::logger(self::LOGGER_CHANNEL);
    $messenger = \Drupal::messenger();
    $dry_run_notice = !empty($results['dry_run']) ? ' (DRY RUN)' : '';

    if ($success) {
      $message = sprintf(
        'Batch complete%s. Processed: %d. Handles Cleared/To Clear: %d.',
        $dry_run_notice,
        $results['processed'],
        $results['changed']
      );
      $messenger->addStatus($message);
      $logger->notice($message);
    }
    else {
      $message = 'An error occurred during the batch process.';
      $messenger->addError($message);
      $logger->error($message);
    }
  }

}
