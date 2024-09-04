<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_stub_terms_corporate_body migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_stub_terms_corporate_body_alter",
 *   label = @Translation("DGIS Stub Terms Corporate Body Migration Alteration"),
 *   description = @Translation("Alters the DGIS Stub Terms Corporate Body migration."),
 *   migration_id = "dgis_stub_terms_corporate_body"
 * )
 */
class DgisStubTermsCorporateBodyAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $migration['source']['ids']['institution_tid'] = ['type' => 'string'];

    $process =& $migration['process'];

    $process['field_corporate_body_affiliation'] = [
      [
        'plugin' => 'get',
        'source' => 'institution_tid',
      ],
      [
        'plugin' => 'migration_lookup',
        'migration' => 'bceln_stub_terms_institution',
        'stub_id' => 'bceln_stub_terms_institution',
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'process',
      ],
    ];

    if (!isset($migration['migration_dependencies']['required'])) {
      $migration['migration_dependencies']['required'] = [];
    }
    $migration['migration_dependencies']['required'][] = 'bcelndora_stub_terms_culture';
    $migration['migration_dependencies']['required'][] = 'bcelndora_stub_terms_institution';

    $logger->info('Migration altered for dgis_stub_terms_person.');
  }

}
