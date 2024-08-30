<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_orig_file migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_orig_file_alter",
 *   label = @Translation("DGIS Orig File Migration Alteration"),
 *   description = @Translation("Alters the DGIS Orig File migration."),
 *   migration_id = "dgis_orig_file"
 * )
 */
class DgisOrigFileAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $process =& $migration['process'];

    $process['_source_dsid'][0]['map']['info:fedora/ir:thesisCModel'] = 'PDF';

    $logger->info('Migration altered for dgis_orig_file.');
  }

}
