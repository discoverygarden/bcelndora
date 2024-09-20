<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_tn_media migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_tn_media_alter",
 *   label = @Translation("DGIS Thumbnail Media Migration Alteration"),
 *   description = @Translation("Alters the DGIS TN Media migration."),
 *   migration_id = "dgis_tn_media"
 * )
 */
class DgisTnMediaAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $process =& $migration['process'];

    $process['bundle'][0]['map']['info:fedora/islandora:collectionCModel'] = 'image';

    $logger->info('Migration altered for dgis_tn_media.');
  }

}
