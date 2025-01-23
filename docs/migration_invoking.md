# Staging and running a migration

In the following documentation the following servers are referenced:

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
4. Detach from the screen.
5. When split is complete, a new directory will be created named after the namespaces specified.
    - `ls -lah /usr/local/fedora/data` to see the new directory and its permissions.
6. Change permissions on the new directory:
    - `sudo chown -R 1006:1006 {new_directory}`
    - `sudo chmod -R 755 {new_directory}`

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

1. From the [Drupal container][drupal-server] get a shell.
2. Ensure the migration config split is active.<br />
   `drush config-split:status-override migration active`
3. Import the config split to ensure it takes effect.<br />
   `drush config-split:import migration`

### Disable entity_hierarchy rewriting
1. From the [Drupal container][drupal-server] get a shell.
2. Disable `entity_hierarchy` from writing during the migration.<br />
   `drush -r app sset entity_hierarchy_disable_writes 1`

## Invoking a migration

1. From the [Drupal container][drupal-server] get a shell.
2. Navigate to the migration logging directory for ease of use.<br />
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
7. If required go through the [log messages][logging] to dig into any issues
   further.

[kubernetes-access]: migration_overview.md#kubernetes-access
[drupal-container-config]: migration_overview.md#drupal-container-configuration
[dc-server]: #dc-server
[drupal-server]: #drupal-container
[split]: #splitting-the-objects-into-namespaces
[log-dir]: https://github.com/discoverygarden/bceln-drupal/blob/20226a504bd97853d737d08d39ee3236304a6709/Dockerfile#L57
[status-and-error]: migration_overview.md#status-and-error-checking
[migration-overview]: migration_overview.md
[helm-chart]: devops.md#drupal
[logging]: migration_overview.md#logging
