<?php

namespace Drupal\bcelndora\Drush\Commands;

use Drupal\Core\Batch\BatchBuilder;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\node\NodeInterface;
use Drush\Attributes as CLI;
use Drush\Commands\AutowireTrait;
use Drush\Commands\DrushCommands;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * Command for BCELN to remove field_handle values.
 */
final class BcelndoraDrushCommands extends DrushCommands {
  use AutowireTrait;

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

    $nids = $query->sort('nid')->execute();
    $count = count($nids);

    if ($count === 0) {
      $this->io()->writeln('No matching nodes found.');
      return;
    }

    $this->io()->writeln(sprintf('Found %d nodes to process.', $count));
    if ($options['dry-run']) {
      $this->io()->warning('In dry run state.');
    }

    $nid_chunks = array_chunk($nids, self::BATCH_SIZE);

    $batch_builder = new BatchBuilder();
    $batch_builder
      ->setTitle('Clearing field_handle values')
      ->setInitMessage('Starting handle clearing process...')
      ->setErrorMessage('An error occurred during processing.')
      ->setFinishCallback([static::class, 'batchFinished']);

    foreach ($nid_chunks as $nid_chunk) {
      $batch_builder->addOperation([static::class, 'processBatch'], [$nid_chunk, $options]);
    }

    batch_set($batch_builder->toArray());
    drush_backend_batch_process();
  }

  /**
   * Batch processing for handle removal.
   */
  public static function processBatch(array $nids_to_process, array $options, array &$context): void {
    $messenger = \Drupal::messenger();
    $node_storage = \Drupal::entityTypeManager()->getStorage('node');
    $logger = \Drupal::logger(self::LOGGER_CHANNEL);

    if (empty($context['results'])) {
      $context['results'] = [
        'processed' => 0,
        'changed' => 0,
        'dry_run' => $options['dry-run'],
      ];
    }

    $nodes = $node_storage->loadMultiple($nids_to_process);

    foreach ($nodes as $node) {
      if (!$node instanceof NodeInterface || !$node->hasField('field_handle')) {
        continue;
      }

      $current_value = $node->get('field_handle')->value;
      $log_context = ['@nid' => $node->id(), '@current' => $current_value];

      if ($options['dry-run']) {
        $message = t('[DRY-RUN] Would clear handle on node @nid. Current value: "@current".', $log_context);
      }
      else {
        try {
          $node->set('field_handle', NULL);
          $node->save();
          $message = t('Cleared handle on node @nid. Old value was: "@current".', $log_context);
        }
        catch (\Exception $e) {
          $error_message = t('Failed to save node @nid. Error: @error', [
            '@nid' => $node->id(), 
            '@error' => $e->getMessage(),
          ]);
          $logger->error($error_message);
          if ($options['logging']) {
            $messenger->addError($error_message);
          }
          continue;
        }
      }

      $context['results']['changed']++;
      if ($options['logging']) {
        $messenger->addMessage($message);
        $logger->info($message);
      }
    }

    $context['results']['processed'] += count($nids_to_process);
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
        'Batch complete%s. Processed: %d. Handles cleared/to be cleared: %d.',
        $dry_run_notice,
        $results['processed'] ?? 0,
        $results['changed'] ?? 0
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
