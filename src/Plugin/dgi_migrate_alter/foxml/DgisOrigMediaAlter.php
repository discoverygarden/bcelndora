<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_orig_media migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_orig_media_alter",
 *   label = @Translation("DGIS Orig Media Migration Alteration"),
 *   description = @Translation("Alters the DGIS Orig Media migration."),
 *   migration_id = "dgis_orig_media"
 * )
 */
class DgisOrigMediaAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $process =& $migration['process'];

    $process['bundle'][0]['map']['info:fedora/ir:thesisCModel'] = 'file';

    $logger->info('Migration altered for dgis_orig_media.');
  }

}
