# Staging and running a migration

## Kubernetes Access

1. Connect to the VPN.
2. SSH to the node.

### Drupal Container Configuration
1. List all available namespaces via: `kubectl get namespaces`.
2. Switch to the desired site via: `kubectl config set-context --current
--namespace={site}`.
3. Get a shell (if required) via:
   `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
4. Verify the site is correct via:
   `echo $DRUSH_OPTIONS_URI`

5. In the following documentation the following servers are referenced:

#### dc server
Refers to the server that has `kubectl` and access to the cluster. It can be
connected to as needed by [SSHing][kubernetes-access] to it.

#### Drupal container
Refers to the container that is running the Drupal instance and represents the
site being migrated. It can be connected to as needed by
[configuring][drupal-container-config] `kubectl` to point to it while on the
[dc server][dc-server] and getting a shell.

## Preflight checks

### Splitting the objects into namespaces

1. From the [dc server][dc-server] navigate to the Fedora data directory.<br />
   `cd /usr/local/fedora/data`
2. Open a `screen` as it is a long running process.
3. Invoke the namespaces splitting script.<br />
   `sudo NAMESPACES=foo,bar ./namespace_split.sh`
    - Note: Directory names are limited to a certain number of characters. If splitting a long list of namespaces, you may need to do this in multiple stages, creating different directories.
5. Detach from the screen.
6. When split is complete, a new directory will be created named after the namespaces specified.
    - `ls -lah /usr/local/fedora/data` to see the new directory and its permissions.
7. Change permissions on the new directory:
    - `sudo chown -R 1006:1006 {new_directory}`
    - `sudo chmod -R 755 {new_directory}`
8. To merge multiple directories into one, use `rsync`. Where your final directory is `DESTINATION_C`: 
    - `rsync -aP --no-perms  /ORIGINAL_A/* /DESTINATION_C/`
    - `rsync -aP --no-perms  /ORIGINAL_B/* /DESTINATION_C/`

### Ensure akubra_adapter is configured

1. From the [dc server][dc-server] point the
[`kubectl` context][drupal-container-config] at the site being migrated.
2. Verify the directory is correct for Fedora objects.<br />
   `kubectl exec deployments/drupal -- /bin/bash -c 'echo $FEDORA_OBJECT_PATH'`
3. Ensure that this matches to the split out directory as noted [above][split].
4. If it does not, edit the [Drupal helm chart][helm-chart]'s `values.yml` on
   the [dc server][dc-server] for the correct `FEDORA_OBJECT_PATH` and redeploy.

### Ensure Fedora data is readable

1. From the [dc server][dc-server] point the
   [`kubectl` context][drupal-container-config] at the site being migrated:
    `kubectl config set-context --current --namespace={site}`
2. Ensure the data is readable: 
   `kubectl exec deployments/drupal -- /bin/bash -c "sudo -Eu www-data drush php:eval \"var_dump(is_readable('foxml://object/{a:pid}'))\""`
   where `a:pid` is an object that exists in the dataset (e.g. `twu:180`).
   This will return `TRUE` if the data exists and is readable; `FALSE` otherwise.

### Ensure the migration config split is enabled and imported

1. Shell into the Drupal container: `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
2. Ensure the migration config split is active.<br />
   `drush config-split:status-override migration active`
3. Import the config split to ensure it takes effect.<br />
   `drush config-split:import migration`

### Disable entity_hierarchy rewriting
1. Shell into the Drupal container: `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
2. Disable `entity_hierarchy` from writing during the migration.<br />
   `drush -r app sset entity_hierarchy_disable_writes 1`

## Invoking a migration

1. Shell into the Drupal container: `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
2. Create the logging directory: `mkdir /opt/ingest_data/migration`
3. Make the logging directory writeable:
   `chmod 775 /opt/ingest_data/migration`
5. Navigate to the migration logging directory for ease of use.<br />
   `cd $LOG_DIR`
> [!NOTE]
> The `$LOG_DIR` variable is in an environment variable that is built into the
> [Drupal container][log-dir] image.
3. Open a `screen`.
4. Invoke the migration script.<br />
   `bash /opt/www/drupal/web/modules/contrib/dgi_migrate/scripts/migration.sh $LOG_DIR`
5. Detach from the screen.
6. Verify migration status.<br />
   `drush ms --group=foxml_to_dgis`
> [!NOTE]
> A breakdown of the columns and their meanings can be found within the
[status and error checking][status-and-error] portion of the
> [migration overview][migration-overview] document.
7. [Verify][verify] the migration.

### Migration verification
1. Shell into the Drupal container: `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
2. Check the status of the migration to see how many messages or unprocessed
objects exist.<br />
   `drush ms --group=foxml_to_dgis`
> [!TIP]
> A breakdown of the columns and their meanings can be found within
> [status and error checking][status-and-error].
3. For each migration check the number of unprocessed and failed objects.<br />
   `drush sql-query "SELECT sourceid1 from migrate_map_{migration name} where destid1 IS NULL and source_row_status IN ('2', '3');"`
Where `{migration name}` is the name of the migration to be checked, for example
`dgis_nodes`.
4. Check each migration's messages for errors.<br />
   `drush mmsg {migration name}`
> [!CAUTION]
> The migrate messages are cleared every time a migration is re-run or rolled
> back. A copy of the messages is preserved in `JSON` format in the
> [log directory][log-directory] that can be used alternatively.
5. Identify the Fedora object PIDs of the objects that failed to migrate.
```
drush sql-query "SELECT sourceid1, destid1 FROM migrate_map_dgis_foxml_files WHERE destid1 IN (SELECT sourceid1 FROM migrate_map_{migration_name} WHERE destid1 IS NULL AND source_row_status IN ('2', '3'));"
```
6. [Find the locations][foxml-wrapper] of the datastreams and objects on disk
(if required).

## Updating metadata and re-running a migration
1. Make any changes required on the Fedora objects that failed to migrate.
2. Re-run the [namespace split][split] script to ensure the Fedora objects are
updated with their newly referenced changes.
3. Shell into the Drupal container: `kubectl exec --stdin --tty deployments/drupal  -- /bin/bash`
4. Rollback the objects in the migration that were `failed` or `ignored`.<br />
```
bash /opt/www/drupal/web/modules/contrib/dgi_migrate/scripts/rollback.sh $LOG_DIR --statuses=ignored,failed
```
5. [Re-run](#invoking-a-migration) the migration.

> [!TIP]
> More targeted rollback scenarios or handling unexpected exceptions are
> detailed within [resuming a migration][resuming].

[kubernetes-access]: #kubernetes-access
[drupal-container-config]: #drupal-container-configuration
[dc-server]: #dc-server
[drupal-server]: #drupal-container
[split]: #splitting-the-objects-into-namespaces
[log-dir]: https://github.com/discoverygarden/bceln-drupal/blob/20226a504bd97853d737d08d39ee3236304a6709/Dockerfile#L57
[status-and-error]: migration_overview.md#status-and-error-checking
[migration-overview]: migration_overview.md
[helm-chart]: devops.md#drupal
[logging]: migration_overview.md#logging
[verify]: #migration-verification
[status-and-error]: migration_overview.md#status-and-error-checking
[log-directory]: migration_overview.md#logging
[foxml-wrapper]: migration_overview.md#resolving-foxml-paths
[migration-errors]: migration_overview.md#expected-parsing-failures
[resuming]: migration_overview.md#resuming-a-migration
