<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_tn_file migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_tn_file_alter",
 *   label = @Translation("DGIS Thumbnail File Migration Alteration"),
 *   description = @Translation("Alters the DGIS TN File migration."),
 *   migration_id = "dgis_tn_file"
 * )
 */
class DgisTnFileAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $process =& $migration['process'];

    $process['_source_dsid'][0]['map']['info:fedora/islandora:collectionCModel'] = 'TN';

    $logger->info('Migration altered for dgis_tn_file.');
  }

}
