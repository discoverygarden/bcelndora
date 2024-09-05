<?php

namespace Drupal\bcelndora\Plugin\dgi_migrate_alter\foxml;

use Drupal\dgi_migrate_alter\Plugin\MigrationAlterBase;
use Drupal\dgi_migrate_alter\Plugin\MigrationAlterInterface;

/**
 * Alter for dgis_stub_terms_corporate_body migration.
 *
 * @MigrationAlter(
 *   id = "bcelndora_dgis_stub_terms_affiliate_alter",
 *   label = @Translation("DGIS Stub Terms Affiliate Migration Alteration"),
 *   description = @Translation("Alters the DGIS Stub Terms Affiliate migration."),
 *   migration_id = "dgis_stub_terms_affiliate"
 * )
 */
class DgisStubTermsAffiliateAlter extends MigrationAlterBase implements MigrationAlterInterface {

  /**
   * {@inheritdoc}
   */
  public function alter(array &$migration) {
    $logger = \Drupal::logger('bcelndora');

    $process =& $migration['process'];

    $process['tid'][0]['source'][] = '@_blank';

    $logger->info('Migration altered for dgis_stub_terms_affiliate.');
  }

}
