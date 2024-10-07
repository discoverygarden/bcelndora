<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\Component\Utility\NestedArray;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;
use Symfony\Component\Yaml\Yaml;

/**
 * Alter for dgis_stub_nodes migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_nodes_alter",
 *   label = @Translation("DGIS Stub Nodes Migration Alteration"),
 *   description = @Translation("Alters the DGIS Stub Nodes migration."),
 *   migration_id = "dgis_stub_nodes"
 * )
 */
class DgisStubNodesAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $process =& $migration['process'];

    $process['field_model'] = [
      [
        'plugin' => 'default_value',
        'default_value' => 'http://purl.org/dc/dcmitype/Collection',
      ],
      [
        'plugin' => 'dgi_migrate.required_entity_lookup',
        'bundle_key' => 'vid',
        'bundle' => 'islandora_models',
        'value_key' => 'field_external_uri',
        'entity_type' => 'taxonomy_term',
        'ignore_case' => TRUE,
      ]
    ];
  }
}
