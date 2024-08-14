<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\Component\Utility\NestedArray;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;
use Symfony\Component\Yaml\Yaml;

/**
 * Alter for dgis_nodes migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_nodes_alter",
 *   label = @Translation("DGIS Nodes Migration Alteration"),
 *   description = @Translation("Alters the DGIS Nodes migration."),
 *   migration_id = "dgis_nodes"
 * )
 */
class DgisNodesAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $process =& $migration['process'];

    // XXX: Not using dgi_migrate_foxml_standard_mods_xslt.process to avoid the
    // overhead of its HTTP fetch of the XSLT.
    $xslt_path = __DIR__ . '/../../../../mods_to_migrate_mods/bceln_mods_to_migration.xsl';
    $process['_mods_xpath'] = Yaml::parse(<<<EOI
- plugin: dgi_migrate.subindex
  index: 'MODS'
  source: '@_node_foxml_parsed'
  missing_behavior: skip_process
- plugin: dgi_migrate.method
  method: getUri
- plugin: callback
  callable: file_get_contents
- plugin: dgi_saxon_helper_migrate.process
  path: $xslt_path
- plugin: dgi_migrate.process.xml.domstring
- plugin: dgi_migrate.process.xml.xpath
  namespaces:
    mods: 'http://www.loc.gov/mods/v3'
    xsi: 'http://www.w3.org/2001/XMLSchema-instance'
    xlink: 'http://www.w3.org/1999/xlink'
EOI
    );

    $found = FALSE;
    NestedArray::getValue(
      $migration,
      [
        'source',
        'dsf_misc',
        'base_mods_node',
      ],
      $found
    );

    if (!$found) {
      $logger->warning('Failed to find the "base_mods_node" to alter the "dgis_nodes" migration; aborting.');
      return;
    }

    $process['_i8_model_uri'][0]['map']['islandora:sp_remoteMediaCModel'] = 'http://purl.org/coar/resource_type/c_12ce';

    $process['_resource_type'][0]['query'] = 'mods:typeOfResource[1]';
    $process['_resource_type'][4]['values']['_vid'][0]['default_value'] = 'library_of_congress_resource_typ';
    $process['_unspecified_resource_type'][2]['values']['_vid'][0]['default_value'] = 'library_of_congress_resource_typ';

    $process['field_peer_review_status'] = $process['field_ark'];
    $process['field_peer_review_status'][0]['query'] = 'mods:note[@displayLabel="Peer Reviewed"]';

    $process['field_description'][0]['query'] = 'mods:abstract[not(@displayLabel)]';

    $process['field_local_contexts'] = $process['field_ismn'];
    $process['field_local_contexts'][0]['query'] = 'mods:identifier[@type="Local Contexts Project ID"]';

    $process['field_access_id'] = $process['field_ismn'];
    $process['field_access_id'][0]['query'] = 'mods:identifier[@type="access"]';

    $process['field_identifier_uri'] = $process['field_publication_url'];
    $process['field_identifier_uri'][0]['query'] = 'mods:identifier[@type="uri"]';

    $process['field_issn'] = $process['field_ismn'];
    $process['field_issn'][0]['query'] = 'mods:identifier[@type="issn"]';

    $process['field_keywords'] = $process['field_form'];
    $process['field_keywords'][0]['query'] = 'mods:note[@displayLabel="keywords"]';

    $values = &$process['field_linked_agent'][1]['values'];
    unset($values['target_id']);

    $values['_culture_lookup'] = $values['_affiliation_lookup'];
    $values['_culture_lookup'][0]['query'] = 'normalize-space(mods:namePart[@type="culture"][normalize-space()])';
    $values['_culture_lookup'][2]['migration'] = 'bcelndora_stub_terms_culture';
    $values['_culture_lookup'][2]['stub_id'] = 'bcelndora_stub_terms_culture';

    $values['_culture'] = $values['_affiliation'];
    $values['_culture'][0]['source'] = '_culture_lookup';

    $values['_alt_name'] = $values['_family_name'];
    $values['_alt_name'][0]['query'] = 'normalize-space(mods:alternativeName[normalize-space()])';

    $values['_description'] = $values['_family_name'];
    $values['_description'][0]['query'] = 'normalize-space(mods:description[normalize-space()][1])';

    $values['_other_id'] = $values['_family_name'];
    $values['_other_id'][0]['query'] = 'normalize-space(mods:nameIdentifier[not(@type)][normalize-space()][1])';

    $values['_orcid'] = $values['_family_name'];
    $values['_orcid'][0]['query'] = 'normalize-space(mods:nameIdentifier[@type="orcid"][normalize-space()][1])';

    $values['target_id'] = [
      [
        'plugin' => 'get',
        'source' => [
          '@_authority',
          '@_value_uri',
          '@_untyped_names',
          '@_given_name',
          '@_family_name',
          '@_date_name',
          '@_display_form',
          '@_affiliation',
          '@_culture',
          '@_alt_name',
          '@_description',
          '@_other_id',
          '@_orcid',
        ],
        [
          'plugin' => 'flatten',
        ],
        [
          'plugin' => 'dgi_migrate.process.log',
          'template' => 'Linked Agent: :value',
        ],
        [
          'plugin' => 'migration_lookup',
          'migration' => 'dgis_stub_terms_person',
          'stub_id' => 'dgis_stub_terms_person',
        ],
        [
          'plugin' => 'skip_on_empty',
          'method' => 'row',
        ],
      ],
    ];

    $process['field_subject_name_person'] = $process['field_linked_agent'];
    $process['field_subject_name_person'][0]['query'] = 'mods:subject/mods:name[@type="personal"]';

    $process['field_hierarchical_geographic_su'][3]['values']['field_state']['0']['query'] =
      'mods:subject/mods:hierarchicalGeographic/mods:state | mods:subject/mods:hierarchicalGeographic/mods:province';

    $process['field_scale'] = $process['field_ark'];
    $process['field_scale'][0]['query'] = 'mods:subject/mods:cartographics/mods:scale';

    $process['field_use_and_reproduction'][0]['query'] = 'mods:accessCondition[@type="use and reproduction"][not(@displayLabel)]';

    $process['field_record_information'][3]['values']['_field_record_creation_date_single'][0]['query'] =
      'mods:recordInfo/mods:recordCreationDate[not(@point)] or mods:originInfo/mods:dateCreated[not(@point)]';
    $process['field_record_information'][3]['values']['_field_record_creation_date_start'][0]['query'] =
      'mods:recordInfo/mods:recordCreationDate[@point="start"] or mods:originInfo/mods:dateCreated[@point="start"]';
    $process['field_record_information'][3]['values']['_field_record_creation_date_end'][0]['query'] =
      'mods:recordInfo/mods:recordCreationDate[@point="end"] or mods:originInfo/mods:dateCreated[@point="end"]';
    $process['field_record_information'][3]['values']['field_record_information_note'][] = [
      'plugin' => 'single_value',
    ];
    $process['field_record_information'][3]['values']['field_record_information_note'][] = [
      'plugin' => 'callback',
      'callable' => 'array_filter',
    ];
    $process['field_record_information'][3]['values']['field_record_information_note'][] = [
      'plugin' => 'null_coalesce',
    ];
    $process['field_related_item_paragraph'][3]['values']['field_related_item_genre'][] = [
      'plugin' => 'single_value',
    ];
    $process['field_related_item_paragraph'][3]['values']['field_related_item_genre'][] = [
      'plugin' => 'callback',
      'callable' => 'array_filter',
    ];
    $process['field_related_item_paragraph'][3]['values']['field_related_item_genre'][] = [
      'plugin' => 'null_coalesce',
    ];

    $process['field_remote_media_url'] = $process['field_ismn'];
    $process['field_remote_media_url'][0]['query'] = 'mods:identifier[@displayLabel="remote media URL"]';

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
      ['field_origin_information', 3, 'values', '_field_date_created_single'],
      ['field_origin_information', 3, 'values', '_field_date_created_start'],
      ['field_origin_information', 3, 'values', '_field_date_created_end'],
      ['field_origin_information', 3, 'values', '_field_date_created_assembled'],
      ['field_origin_information', 3, 'values', 'field_date_created'],
      ['field_extent_total_pages'],
      ['field_conflict_of_interest'],
      ['field_funder'],
      ['field_grant_id'],
      ['field_sponsorship_information'],
      ['field_sub_location'],
      ['field_form'],
      ['field_note_location'],
      ['field_enumeration_and_chronology'],
      ['field_copyright_holder'],
      ['field_part'],
    ];

    foreach ($to_remove as $path) {
      NestedArray::unsetValue($process, $path);
    }

    if (!isset($migration['migration_dependencies']['required'])) {
      $migration['migration_dependencies']['required'] = [];
    }
    $migration['migration_dependencies']['required'][] = 'bcelndora_stub_terms_culture';

    $logger->info('Migration altered for dgis_nodes.');
  }

}