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

    $migration['source']['ids']['culture_tid'] = ['type' => 'string'];
    $migration['source']['ids']['alt_name'] = ['type' => 'string'];
    $migration['source']['ids']['description'] = ['type' => 'string_long'];
    $migration['source']['ids']['other_id'] = ['type' => 'string'];
    $migration['source']['ids']['orcid'] = ['type' => 'string'];

    $process =& $migration['process'];

    $process['field_culture'] = [
      [
        'plugin' => 'get',
        'source' => 'culture_tid',
      ],
      [
        'plugin' => 'migration_lookup',
        'migration' => 'bcelndora_stub_terms_culture',
        'stub_id' => 'bcelndora_stub_terms_culture',
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'process',
      ],
    ];

    $process['field_person_alt_names'] = [
      [
        'plugin' => 'get',
        'source' => 'alt_name',
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

    if (!isset($migration['migration_dependencies']['required'])) {
      $migration['migration_dependencies']['required'] = [];
    }
    $migration['migration_dependencies']['required'][] = 'bcelndora_stub_terms_culture';

    $logger->info('Migration altered for dgis_stub_terms_person.');
  }

}
