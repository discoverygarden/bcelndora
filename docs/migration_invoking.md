# Running a migration

## Splitting the objects into namespaces.

1. SSH to the `dc` server or any other server that has the Fedora data mounted.
2. Navigate to the Fedora data directory.
   `cd /usr/local/fedora/data`
3. Open a screen as it is a long running process.
4. Invoke the namespaces splitting script.
   `sudo NAMESPACES=foo,bar ./namespace_split.sh`
5. Detach from the screen.

## Ensure akubra_adapter is configured.

1. `echo $FEDORA_OBJECT_PATH`.
2. Ensure that this matches to the split out directory as noted above.
3. If it does not, edit the helm chart value for `FEDORA_OBJECT_PATH` and redeploy.

## Invoking a migration.

1. Navigate to the migration logging directory for ease of use.
   `cd $LOG_DIR`
2. Open a screen.
3. Invoke the migration script.
   `bash /opt/www/drupal/web/modules/contrib/dgi_migrate/scripts/migration.sh $LOG_DIR`
4. Detach from the screen.
5. Verify logs, output and data when complete.
