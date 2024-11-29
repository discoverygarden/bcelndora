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
    unset($process['_latest']);

    $to_insert['_source_dsid_2'] = [
      [
        'plugin' => 'static_map',
        'source' => '@_models',
        'map' => [
          'info:fedora/islandora:sp_large_image_cmodel' => 'JP2',
          'info:fedora/islandora:pageCModel' => 'JP2',
          'info:fedora/islandora:newspaperPageCModel' => 'JP2',
        ],
        'default_value' => '',
      ],
      [
        'plugin' => 'extract',
        'index' => [0],
      ],
    ];

    $to_insert['_latest_1'] = [
      [
        'plugin' => 'dgi_migrate.subindex',
        'source' => '@_parsed',
        'index_from_destination' => '_source_dsid',
        'missing_behavior' => 'skip_process',
      ],
    ];

    $to_insert['_latest_2'] = [
      [
        'plugin' => 'skip_on_empty',
        'source' => '@_source_dsid_2',
        'method' => 'process',
      ],
      [
        'plugin' => 'dgi_migrate.subindex',
        'source' => '@_parsed',
        'index_from_destination' => '_source_dsid_2',
        'missing_behavior' => 'skip_process',
      ],
    ];

    $to_insert['_latest'] = [
      [
        'plugin' => 'null_coalesce',
        'source' => [
          '@_latest_1',
          '@_latest_2',
        ],
      ],
      [
        'plugin' => 'skip_on_empty',
        'method' => 'row',
      ],
      [
        'plugin' => 'dgi_migrate.method',
        'method' => 'latest',
      ],
    ];

    $position = array_search('_source_dsid', array_keys($process), TRUE);
    $process = array_merge(
      array_slice($process, 0, $position + 1, TRUE),
      $to_insert,
      array_slice($process, $position + 1, NULL, TRUE)
    );

    $logger->info('Migration altered for dgis_orig_file.');
  }

}
