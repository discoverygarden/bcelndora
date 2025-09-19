# Migrating content into an existing site with existing content

This represents my understanding of the instructions provided in ticket #21481. Please correct any misconceptions.

## Setup

1. In the `dc` server, navigate to `cd /usr/local/fedora/data`
2. Run the `namespace_split.sh` script using the new namespaces you want to migrate.
    - This will create a new directory.
3. Set permissions on the new directory and test them, per the `migration_invoking` documentation.
4. In `/opt/helm_values/[site]/drupal/values.yaml`, change the value of `FEDORA_OBJECT_PATH` to the new directory you want to import. This will avoid any conflicts with existing files.
5. Run the `update-all.sh` script without hooks (`-s`) to update the fedora path for the site.
6. Enable `Big Set Overrides` on the site.
7. Truncate the existing migration database. This will avoid any conflicts with existing data.
    - Shell into the node's Drupal deployment: `kubectl -n [namespace] exec --stdin --tty deployment/drupal -- /bin/bash`
    - Enter the database: `drush sql-cli`
    - Truncate the map tables:
        ```
        truncate migrate_map_dgis_foxml_files; 
truncate migrate_map_dgis_stub_terms_generic; 
truncate migrate_map_bceln_person_tn_file; 
truncate migrate_map_bceln_person_tn_media; 
truncate migrate_map_bceln_mads_to_term_person; 
truncate migrate_map_bceln_stub_terms_institution; 
truncate migrate_map_bceln_stub_terms_culture; 
truncate migrate_map_dgis_stub_nodes; 
truncate migrate_map_dgis_stub_terms_person; 
truncate migrate_map_dgis_stub_terms_corporate_body; 
truncate migrate_map_dgis_stub_terms_affiliate; 
truncate migrate_map_dgis_nodes; 
truncate migrate_map_store_source_foxml; 
truncate migrate_map_dgis_orig_file; 
truncate migrate_map_dgis_orig_media; 
truncate migrate_map_dgis_collection_representatives; 
truncate migrate_map_dgis_tn_file; 
truncate migrate_map_dgis_tn_media; 
        ```
    - Truncate the message tables:
        ```
        truncate migrate_message_dgis_foxml_files; 
truncate migrate_message_dgis_stub_terms_generic; 
truncate migrate_message_bceln_person_tn_file; 
truncate migrate_message_bceln_person_tn_media; 
truncate migrate_message_bceln_mads_to_term_person; 
truncate migrate_message_bceln_stub_terms_institution; 
truncate migrate_message_bceln_stub_terms_culture; 
truncate migrate_message_dgis_stub_nodes; 
truncate migrate_message_dgis_stub_terms_person; 
truncate migrate_message_dgis_stub_terms_corporate_body; 
truncate migrate_message_dgis_stub_terms_affiliate; 
truncate migrate_message_dgis_nodes; 
truncate migrate_message_store_source_foxml; 
truncate migrate_message_dgis_orig_file; 
truncate migrate_message_dgis_orig_media; 
truncate migrate_message_dgis_collection_representatives; 
truncate migrate_message_dgis_tn_file; 
truncate migrate_message_dgis_tn_media;
        ```

## Set up the migration in the node

1. Announce a content and config freeze before beginning.
2. Shell into the container: `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
3. Import the migration split:
    - `drush config-split:status-override migration active`
    - `drush config-split:import migration`
       - **QUESTION: Does this import affect the existing split??**
    - `drush -r app sset entity_hierarchy_disable_writes 1`
4. Navigate to the log directory: `cd $LOG_DIR`

## Run the migration

This should not impact any configuration nor existing objects; in theory, this will only create new objects.

Follow the [Invoking steps on our documentation](https://github.com/discoverygarden/bcelndora/blob/main/docs/migration_invoking.md#invoking-a-migration).

## Cleanup

Follow the normal steps at [migration-cleanup.md](https://github.com/discoverygarden/bcelndora/blob/main/docs/migration_cleanup.md).
