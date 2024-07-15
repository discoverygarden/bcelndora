<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\spreadsheet;

use Drupal\Component\Utility\NestedArray;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dssi_node migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dssi_node_alter",
 *   label = @Translation("DSSI Node Migration Alteration"),
 *   description = @Translation("Alters the DSSI Node migration."),
 *   migration_id = "dssi_node"
 * )
 */
class DssiNodeAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $process =& $migration['process'];

    $process['field_resource_type'][1]['bundle'] = 'library_of_congress_resource_typ';

    // Add Text (plain) delimited fields.
    $fields_to_add = [
      ['field_local_contexts', 'local_contexts', ';'],
      ['field_access_id', 'access_id', ';'],
    ];

    foreach ($fields_to_add as $field) {
      $process[$field[0]] = [
        [
          'plugin' => 'skip_on_empty',
          'source' => $field[1],
          'method' => 'process',
        ],
        [
          'plugin' => 'dgi_migrate.process.explode',
          'delimiter' => $field[2],
        ],
        [
          'plugin' => 'skip_on_empty',
          'method' => 'row',
          'message' => 'Empty ' . $field[1] . '.',
        ],
      ];
    }

    // Add Text (plain) non-delimited fields.
    $fields_to_add = [
      ['field_scale', 'scale'],
    ];

    foreach ($fields_to_add as $field) {
      $process[$field[0]] = [
        [
          'plugin' => 'skip_on_empty',
          'source' => $field[1],
          'method' => 'process',
        ],
      ];
    }

    // Add tertiary delimiters.
    $fields_to_add = [
      ['field_origin_information', 'field_place', 'place', '^'],
      ['field_origin_information', 'field_publisher', 'publisher', '^'],
      ['field_origin_information', 'field_edition', 'edition', '^'],
      ['field_origin_information', 'field_issuance', 'issuance', '^'],
      ['field_origin_information', 'field_frequency', 'frequency', '^'],
    ];

    foreach ($fields_to_add as $field) {
      $process[$field[0]][2]['values'][$field[1]] = [
        [
          'plugin' => 'log',
        ],
        [
          'plugin' => 'skip_on_empty',
          'source' => "parent_value/$field[2]",
          'method' => 'process',
        ],
        [
          'plugin' => 'dgi_migrate.process.explode',
          'delimiter' => $field[3],
        ],
        [
          'plugin' => 'skip_on_empty',
          'method' => 'row',
          'message' => 'Empty ' . $field[2] . '.',
        ]
      ];
    }

    $fields_to_add = [
      ['field_target_audience', ';'],
      ['field_issn', ';'],
      ['field_reformatting_quality', ';'],
      ['field_digital_origin', ';'],
      ['field_physical_location', ';'],
      ['field_shelf_locator', ';'],
      ['field_electronic_locator', ';'],
      ['field_item_identifier', ';'],
    ];

    // Add delimiters.
    foreach ($fields_to_add as $field) {
      $process[$field[0]][] = [
        'plugin' => 'dgi_migrate.process.explode',
        'delimiter' => $field[1],
      ];

      $process[$field[0]][] = [
        'plugin' => 'skip_on_empty',
        'method' => 'row',
        'message' => 'Empty ' . $field[0] . '.',
      ];
    }

    $process['field_identifier_uri'] = $process['field_url'];
    $process['field_identifier_uri'][0]['source'] = 'identifier_uri';

    $to_remove_and_reindex = [
      [
        ['field_origin_information', 1, 'keys', 2],
      ],
    ];

    foreach ($to_remove_and_reindex as $group) {
      foreach ($group as $path) {
        NestedArray::unsetValue($process, $path);
      }

      $array = array_values(
        NestedArray::getValue(
          $process, array_slice($group[0], 0, -1)
        )
      );
      NestedArray::setValue($process, array_slice($group[0], 0, -1), $array);
    }

    // Remove the following fields.
    $to_remove = [
      ['field_version_identifier'],
      ['field_resource_publication_statu'],
      ['field_change_note'],
      ['field_purl'],
      ['field_handle'],
      ['field_open_url'],
      ['field_ismn'],
      ['field_repec'],
      ['field_gpo_number'],
      ['field_oclc_number'],
      ['field_pubmed_number'],
      ['field_faceted_subject'],
      ['field_sudoc_number'],
      ['field_swank_classification'],
      ['field_state_gov_classification'],
      ['field_publication_volume_title'],
      ['field_publication_chapter_number'],
      ['field_publication_section'],
      ['field_publication_url'],
      ['field_origin_information', 2, 'values', 'field_date_created'],
      ['field_extent_total_pages'],
      ['field_conflict_of_interest'],
      ['field_funder'],
      ['field_grant_id'],
      ['field_sponsorship_information'],
      ['field_sub_location'],
      ['field_form'],
      ['field_note_location'],
      ['field_enumeration_and_chronology'],
      ['field_access_terms'],
      ['field_copyright_holder'],
      ['field_part'],
    ];

    foreach ($to_remove as $path) {
      NestedArray::unsetValue($process, $path);
    }

    $mig_dependencies =& $migration['migration_dependencies'];

    // Remove the following dependencies.
    $to_remove = [
      'dssi_stub_paragraph_part',
      'dssi_stub_paragraph_faceted_subject',
    ];

    foreach ($to_remove as $key) {
      NestedArray::unsetValue($mig_dependencies, ['required', $key]);
    }
  }

}
