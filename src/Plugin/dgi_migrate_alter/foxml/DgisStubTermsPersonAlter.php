<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_stub_terms_person migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_stub_terms_person_alter",
 *   label = @Translation("DGIS Stub Terms Person Migration Alteration"),
 *   description = @Translation("Alters the DGIS Stub Terms Person migration."),
 *   migration_id = "dgis_stub_terms_person"
 * )
 */
class DgisStubTermsPersonAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    unset($migration['source']['ids']['affiliation_tid']);
    $migration['source']['ids']['culture'] = ['type' => 'string'];
    $migration['source']['ids']['institution'] = ['type' => 'string'];
    $migration['source']['ids']['description'] = ['type' => 'string_long'];
    $migration['source']['ids']['other_id'] = ['type' => 'string'];
    $migration['source']['ids']['orcid'] = ['type' => 'string'];

    $process =& $migration['process'];

    $process['field_culture'] = [
      [
        'plugin' => 'get',
        'source' => 'culture',
      ],
      [
        'plugin' => 'migration_lookup',
        'migration' => 'bceln_stub_terms_culture',
        'stub_id' => 'bceln_stub_terms_culture',
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'process',
      ],
    ];

    $process['field_person_affiliation'] = [
      [
        'plugin' => 'get',
        'source' => 'institution',
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

    $process['field_description'] = [
      [
        'plugin' => 'get',
        'source' => 'description',
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'process',
      ],
    ];

    $process['field_identifier_other'] = [
      [
        'plugin' => 'get',
        'source' => 'other_id',
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'process',
      ],
    ];

    $process['field_orcid'] = [
      [
        'plugin' => 'get',
        'source' => 'orcid',
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'process',
      ],
    ];

    unset($process['field_relationship']);

    if (!isset($migration['migration_dependencies']['required'])) {
      $migration['migration_dependencies']['required'] = [];
    }
    $migration['migration_dependencies']['required'][] = 'bceln_stub_terms_culture';
    $migration['migration_dependencies']['required'][] = 'bceln_stub_terms_institution';

    $logger->info('Migration altered for dgis_stub_terms_person.');
  }

}
