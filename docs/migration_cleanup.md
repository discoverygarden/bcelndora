# Post Migration Tasks

## Introduction
Once a migration is complete, there are a few tasks that need to be completed to
ensure the system is ready for production use.

## Derivative verification and queue monitoring

### ActiveMQ monitoring
To monitor the queue you can use the following command where `kubectl` is
installed.
```bash
kubectl exec --stdin --tty deployments/activemq -- bin/activemq query -QQueue=islandora* --view Name,QueueSize
```
This will show the remaining items on all of the Islandora derivative queues.

Example output:
```bash
kubectl exec --stdin --tty deployments/activemq -- bin/activemq query -QQueue=islandora* --view Name,QueueSize
...
Name = islandora-connector-hypercube
QueueSize = 123

Name = islandora-connector-houdini
QueueSize = 123

Name = islandora-connector-homarus
QueueSize = 123
```

### Queue emptying
If a migration has been rolled back or ran multiple times it may be worthwhile
to empty the derivative queues as they will hold stale references to things that
are no longer relevant.

Where `kubectl` is installed
```bash
kubectl exec --stdin --tty deployments/activemq -- bin/activemq purge $QUEUE_NAME
```

Where `$QUEUE_NAME` is replaced by the queue looking to be purged, this is
likely going to be one of `islandora-connector-hypercube`,
`islandora-connector-houdini` or `islandora-connector-homarus`.

### Derivative regeneration
It's possible that derivatives may fail to generate. There is a
[helper-module][standard-derivative-examiner] that provides Drush tooling to
re-queue only things that do not exist. 

If the module is not enabled:
```bash
drush en dgi_standard_derivative_examiner
```

With `GNU Parallel` present on the container run the following:
```bash
drush sql:query "select nid from node where type = 'islandora_object';" | parallel --pipe --max-args 100 -j2 drush --uri=$DRUSH_OPTIONS_URI dgi-standard-derivative-examiner:derive --user=1
```

This will iterate through all nodes and re-queue missing derivatives.

> [!NOTE]
> The command reads from stdin and in the above example it will go through all
> objects in the repository to verify the derivatives. This can be filtered
> down and limited by making the input or SQL query more specific.


## Post Migration Tasks

> [!TIP]
> The majority of the following commands can be run concurrently. Given the
> potential long nature of these commands they should be invoked in a `screen`.

1. Disable the migration config split.
Once this is disabled `content_sync`, path aliases, immediate Solr indexing and
OAI-PMH harvesting will be enabled.

```
drush --user=1 config-split:deactivate migration
```

2. Generate missing path aliases

Enable the `dgi_migrate_regenerate_pathauto_aliases` module and kick off the
generation.
```bash
drush --user=1 en dgi_migrate_regenerate_pathauto_aliases
drush --uri=$DRUSH_OPTIONS_URI dmrpa:empa --user=1
```

Once it's complete disable the module.
```bash
drush --user=1 pm:uninstall dgi_migrate_regenerate_pathauto_aliases
```

3. Re-index Solr

```bash
drush --user=1 --uri=$DRUSH_OPTIONS_URI search-api:index default_solr_index
```
> [!CAUTION]
> The size of the batch sets may need to be reduced depending on the type of
> content being indexed. This can be adjusted by passing the `--batch-size`
> parameter to the command (defaults to 50).

4. Rebuild the OAI-PMH cache
```bash
drush --uri=$DRUSH_OPTIONS_URI idr:roai
```

To monitor the progress of the rebuild the queue can be queried to see the
remaining amount of items.
```bash
select count(*) from queue where name ='rest_oai_pmh_views_cache_cron';
```

5. Export content via `content_sync` (if required)
The `migration` config_split disables the tracking of content changes. 

First rebuild the snapshot table.
```bash
drush --user=1 --uri=$DRUSH_OPTIONS_URI cs:s
```

Export all the content.
```bash
drush --uri=$DRUSH_OPTIONS_URI content-sync:export --user=1 sync --files=none --entity-types=node
```

[standard-derivative-examiner]: https://github.com/discoverygarden/dgi_standard_derivative_examiner
