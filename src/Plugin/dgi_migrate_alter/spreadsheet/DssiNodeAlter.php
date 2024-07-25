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
   *
   * @throws \JsonException
   */
  public function alter(array &$migration): void {
    $process =& $migration['process'];

    $process['field_resource_type'][1]['bundle'] = 'library_of_congress_resource_typ';

    // Add Text (plain) delimited fields.
    $plain_text_delimited_fields_to_add = [
      'field_local_contexts' => ['local_contexts', ';'],
      'field_access_id' => ['access_id', ';'],
    ];

    foreach ($plain_text_delimited_fields_to_add as $field => $field_info) {
      [$source, $delimiter] = $field_info;
      $process[$field] = [
        [
          'plugin' => 'skip_on_empty',
          'source' => $source,
          'method' => 'process',
        ],
        [
          'plugin' => 'dgi_migrate.process.explode',
          'delimiter' => $delimiter,
        ],
        [
          'plugin' => 'skip_on_empty',
          'method' => 'row',
          'message' => "No usable values in $source.",
        ],
      ];
    }

    // Add Text (plain) non-delimited fields.
    $plain_text_non_delimited_fields_to_add = [
      'field_scale' => 'scale',
    ];

    foreach ($plain_text_non_delimited_fields_to_add as $field => $source) {
      $process[$field] = [
        [
          'plugin' => 'skip_on_empty',
          'source' => $source,
          'method' => 'process',
        ],
      ];
    }

    // Add tertiary delimiters.
    $tetiary_delimiter_fields_to_add = [
      ['field_origin_information', 'field_place', 'place', '^'],
      ['field_origin_information', 'field_publisher', 'publisher', '^'],
      ['field_origin_information', 'field_edition', 'edition', '^'],
      ['field_origin_information', 'field_issuance', 'issuance', '^'],
      ['field_origin_information', 'field_frequency', 'frequency', '^'],
    ];
    $expected_child_fields = [
      'field_event_type', 'field_place', 'field_date_created',
      'field_date_issued', 'field_date_captured', 'field_date_valid', 'field_date_modified',
      'field_other_date', 'field_copyright_date', 'field_publisher', 'field_edition',
      'field_issuance', 'field_frequency',
    ];

    foreach ($tetiary_delimiter_fields_to_add as $field) {
      [
        $parent_field,
        $child_field,
        $source_key,
        $delimiter,
      ] = $field;

      // Ensure that the keys in 'values' are a subset of $allowed_child_fields.
      $values_keys = array_keys($process[$parent_field][2]['values']);
      $is_subset = !array_diff($values_keys, $expected_child_fields);
      \assert(
        $is_subset,
        'Keys in $process['
        . $parent_field . '][2][\'values\'] are not a subset of allowed child fields: '
        . \json_encode($values_keys, JSON_THROW_ON_ERROR)
      );

      // Continue with overwrite.
      $process[$parent_field][2]['values'][$child_field] = [
        [
          'plugin' => 'log',
        ],
        [
          'plugin' => 'skip_on_empty',
          'source' => "parent_value/$source_key",
          'method' => 'process',
        ],
        [
          'plugin' => 'dgi_migrate.process.explode',
          'delimiter' => $delimiter,
        ],
        [
          'plugin' => 'skip_on_empty',
          'method' => 'row',
          'message' => 'Empty ' . $source_key . '.',
        ],
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
        'message' => "No usable values in $field[0].",
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
