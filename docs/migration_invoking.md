# Staging and running a migration

## Preflight checks
### Splitting the objects into namespaces

1. SSH to the `dc` server or any other server that has the Fedora data mounted.
2. Navigate to the Fedora data directory.
   `cd /usr/local/fedora/data`
3. Open a `screen` as it is a long running process.
4. Invoke the namespaces splitting script.
   `sudo NAMESPACES=foo,bar ./namespace_split.sh`
5. Detach from the screen.

### Ensure akubra_adapter is configured

1. `echo $FEDORA_OBJECT_PATH`
2. Ensure that this matches to the split out directory as noted above.
3. If it does not, edit the [Drupal helm chart][helm-chart]'s `values.yml` for
`FEDORA_OBJECT_PATH` and redeploy.

### Ensure Fedora data is readable
1. `drush php:eval "var_dump(is_readable('foxml://object/a:pid'))"`
This will return `TRUE` if the data exists and is readable. Choose an object
that exists in the data set to compare.

### Ensure the migration config split is enabled and imported

1. `drush config-split:status-override migration active`
2. `drush config-split:import migration`

### Disable entity_hierarchy rewriting
1. `drush -r app sset entity_hierarchy_disable_writes 1`

## Invoking a migration

1. Navigate to the migration logging directory for ease of use.
   `cd $LOG_DIR`
> [!NOTE] 
> The `$LOG_DIR` variable is in an environment variable that is built into the
> [Drupal container][log-dir] image.
2. Open a `screen`.
3. Invoke the migration script.
   `bash /opt/www/drupal/web/modules/contrib/dgi_migrate/scripts/migration.sh $LOG_DIR`
4. Detach from the screen.
5. Verify migration status.
`drush ms --group=foxml_to_dgis`
> [!NOTE] 
> A breakdown of the columns and their meanings can be found within the
[status and error checking][status-and-error] portion of the 
> [migration overview][migration-overview] document.
6. If required go through the [log messages][logging] to dig into any issues
further.


[log-dir]: https://github.com/discoverygarden/bceln-drupal/blob/20226a504bd97853d737d08d39ee3236304a6709/Dockerfile#L57
[status-and-error]: migration_overview.md#status-and-error-checking
[migration-overview]: migration_overview.md
[helm-chart]: devops.md#drupal
[logging]: migration_overview.md#logging