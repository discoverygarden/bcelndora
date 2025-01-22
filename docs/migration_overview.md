# FOXML Migration Overview for BCELN

## Introduction
DGI Migrate is a set of migrations, plugins and tooling used for executing
migrations within Drupal utilizing [Drupal Migrate][drupal-migrate]. The scope
of this document will lean heavily towards FOXML migrations in particular and
the BCELN project.

## Drupal Migrate Overview
Drupal Migrate is a core module that defines an ETL process to ingest content
into Drupal.

Migrations are broken down into source (extract), process (transform) and
destination (load) phases.

Migration definitions are defined within YAML and heavily utilize the Drupal
Plugin API. This allows contributing modules to define their own custom
processes as needed.

Migrations are tracked in the database within `map` tables which allows for
iterative runs of migrations as well as rolling back of previously created
entities.

### Map tables
The `map` table is the backbone of the migration process. It contains references
to the `source` and `destination` identifiers as well as the status and hashes.

An example is shown below of the `map` table for the `dgis_foxml_files`
migration:
```sql
db=# select * from migrate_map_dgis_foxml_files LIMIT 3;
source_ids_hash	d94a7c5a909751a6effae7ce80f8fe6a40cd57010990ea2a6c8f34fa84af5db6
sourceid1	foxml://object/fedora-system:ContentModel-3.0
destid1	5
source_row_status	0
rollback_action	0
last_imported	1729616853
hash	66c7097f700b28c2b2d173642db99f48ab515c9d93ff12c18f01c1416c18d226

source_ids_hash	f07dcd19c5f214b2b09fab40e0f0689100d1399ce143f72f103176540e8a1453
sourceid1	foxml://object/islandora:manuscriptCModel
destid1	6
source_row_status	0
rollback_action	0
last_imported	1729616853
hash	5a93dfffd3c04042b98916a08221d8d4f75ef84e84dc2d34b5df6b53b3a7b124

source_ids_hash	a7b9816f0900ce9390dcf7834acd0d59af1a61f6b1a5cf983951c36d3199e64c
sourceid1	foxml://object/ir:thesisCModel
destid1	7
source_row_status	0
rollback_action	0
last_imported	1729616853
hash	7b9e1e398066f13ffc3ac0b83922b95efc0ef1405e017838991efb4f4117b285
```

In the above you can see that the original `sourceid1` corresponds to a
particular PID from the old system and the `destid1` corresponds to the new
`file` entity that was created in Drupal. This is important when
[troubleshooting](#troubleshooting) as it allows for the identification of
problematic source files when looking at error messages.

The `source_row_status` is also used to convey whether an individual row within
the migration has been processed or not. The statuses are integers that are
defined by the [MigrateIdMap interface][map-interface]. These statuses can also
be used to filter out entities that succeeded in being migrated or not.

### FOXML migration
The [`foxml` module][foxml-module] provides a way to iteratively parse a [Fedora
Object XML (FOXML)][foxml-reference] file and bypasses holding the entire file
in memory. The module also registers a `foxml://` stream wrapper such that
content can be referenced simply by PHP. 

The module utilizes the plugin framework and provides a base implementation to
parse [`archival` format][archival-foxml] (base64 encoded) FOXML.

The module also provides a Migration `source` plugin that allows the FOXML to be
processed within a migration context. This allows for referencing the source
data as XML which is a boon for developers and metadata technicians who have
familiarity with XPaths and XSLTs.

#### Akubra Adapter
The [`akubra_adapter` module][akubra-adapter] provides a plugin for the `foxml`
module that allows the [akubra filesystem][akubra-fs] structure to be
referenced directly within Drupal. This is beneficial as there is no need to
export all the data from FCREPO in the `archival` format. The old repository
data can instead be mounted read-only which greatly saves on transfer time and
disk space.

> [!NOTE]
> The module must be [configured][akubra-readme] to point at the directories
> where the `objectStore` and `datastreamStore` live.

### BCELN's Migration
The migration in this project is built-on top of the
[standard FOXML migration][dgi-standard-foxml] that dgi has developed with
further customizations added to conform with the content type changes introduced
in the [project][bcelndora-migration].

The project as a whole consists of several migrations that are interdependent
with the majority of the processing time and complexity being in the
[node][node-migration] migration.

The first migration to be run is `dgis_foxml_files` which uses the FOXML files
on disc as its source. All other subsequent migrations are dependent on this
initial migration as they reference the `file` entities that are created within
Drupal.

> [!IMPORTANT]
> This distinction is important for investigative purposes as highlighted
> in the [troubleshooting](#troubleshooting) section.

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

## Staging data for ingestion
The `akubra` filesystem is the source for the migration which the `foxml` source
plugin uses the objects themselves, the `objectStore`, as its basis for
everything to be migrated.

### BCELN considerations
FCREPO held all namespaces within a singular repository. This is not to be the
case upon the migration and certain namespaces will be split apart into
individual sites. To save on data transfer time and costing, the repository wide
`datastreamStore` will be mounted. The `datastreamStore` corresponds to all the
datastreams that are `Managed`, typically binary content, in the old repository
and represents the vast majority of disc space.

#### Limiting by namespace
For each individual site being run the `objectStore` needs to be filtered by the
targeted namespace(s) for each site. A separate folder should be created for
each within the same location as the Fedora data as this is available as a mount
across all sites.

An [example script](resources/namespace_split.sh) has been included within the
module of how this can be achieved.

### File permissions
> [!CAUTION]
> It is important to ensure that the source data is referenced in a read-only
> context. If the `dgis_foxml_files` migration is rolled back, Migrate will
> attempt to delete the original file as part of the process.

When syncing data if the `www-data` is not the owner or in the group for the
directory the following command can be run:
```chmod -R o=rX $PATH_TO_DATA```.
> [!CAUTION]
> Permissions will need to be adjusted on a server where the data is NOT mounted
> read only. More than likely this will be the original FCREPO server.

In the event the file has the wrong permissions it will be skipped within the
`dgis_foxml_files` migration to prevent the file from being deleted. This can be
rectified and the migration re-run later targeting the `skipped` status.

## Running migrations
In an effort to be DRY, [existing documentation][dgi-migrate-readme] can be
referenced directly for `dgi_migrate`. A more systematic approach to running the
migration can be found [included here](migration_invoking.md).

### Environment configuration
The migration runner uses a `.env` file to define the environment variables that
are used. When running a migration the [sample file](resources/env.sample) can be
copied into the directory that is to be run from and renamed to `.env` to set
or override environment variables as required.

> [!TIP]
> Normally the `$LOG_DIR`, `$MIGRATION_GROUP` and `$URI` are modified. The
> included sample file narrows that to only needing to change the `$LOG_DIR` per
> site being run for this project.
>
> Global overrides have been set in the [Dockerfile][docker-file] for BCELN that
> bypasses the need for a `.env` file to be present.

> [!CAUTION]
> The `$LOG_DIR` should be present on a persistent volume to ensure that
> logs are not lost if the pod is restarted.

### Invoking the migration
Invoking the migration should be done within a terminal multiplexer, such as
`screen`. The migration can be invoked by following the
[import documentation][import-docs].

#### Single threaded
While the migration can be run single threaded, it is recommended for the size
of this project to run the migration multithreaded and subsequent details will
assume that the migration is run multithreaded.

#### Multithreaded
In a multithreaded context, ActiveMQ is used as a backend to queue jobs for
workers to consume jobs for each migration defined within the migration group.

#### Logging
The migration creates logging files within the defined `$LOG_DIR` directory.
This is split out into a general import log, a run log and a directory that
pertains to each worker.

Once the migration is complete, the messages of each migration will be retrieved
and outputted into JSON files which are then accessible for easier parsing. 

See the below for an example directory structure after a migration run:
```bash
01-import.log  01-messages 01-multiprocess-logs 01-run.log
```

The `run` log contains the status of the migration and initial pre-flight of the
while the `import` log contains the actual output of the migration run.

The `01-messages` directory contains `JSON` of each individual migration's
messages that are retrieved once the migration runner is completed.

> [!TIP]
> An equivalent Drush command can be run to retrieve the messages per migration as
> well: `drush mmsg {the name of the migration}`.

The `01-multiprocess-logs` directory contains output for each worker that was
invoked per migration during the run.

### Rolling back a migration
If it has been deemed necessary to rollback a migration it can be rolled back
by following the [rollback documentation][rollback-docs].

## Troubleshooting

### Status and Error Checking
To check the current state of the migrations the following Drush command can be
used: `drush migrate:status --group=foxml_to_dgis`.

```
 -------------------------- -------------------- -------- ------- ---------- ------------- --------------- --------------- 
  Group                      Migration ID         Status   Total   Imported   Unprocessed   Message Count   Last Imported  
 -------------------------- -------------------- -------- ------- ---------- ------------- --------------- --------------- 
  FOXML with MODS to DGI     bceln_stub_terms_i   Idle     0       0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   nstitution                                                                     08:52:16       
  FOXML with MODS to DGI     bceln_stub_terms_c   Idle     0       0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   ulture                                                                         08:52:16       
  FOXML with MODS to DGI     dgis_foxml_files     Idle     N/A     40         N/A           0               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:16       
  FOXML with MODS to DGI     dgis_stub_terms_ge   Idle     0       16         -16           0               2024-10-23     
  Standard (foxml_to_dgis)   neric                                                                          08:52:16       
  FOXML with MODS to DGI     bceln_person_tn_fi   Idle     40      0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   le                                                                             08:52:16       
  FOXML with MODS to DGI     bceln_person_tn_me   Idle     40      0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   dia                                                                            08:52:16       
  FOXML with MODS to DGI     bceln_mads_to_term   Idle     40      0          0             40              2024-10-23     
  Standard (foxml_to_dgis)   _person                                                                        08:52:16       
  FOXML with MODS to DGI     dgis_stub_nodes      Idle     0       11         -11           0               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:16       
  FOXML with MODS to DGI     dgis_stub_terms_pe   Idle     0       0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   rson                                                                           08:52:16       
  FOXML with MODS to DGI     dgis_stub_terms_co   Idle     0       0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   rporate_body                                                                   08:52:16       
  FOXML with MODS to DGI     dgis_stub_terms_af   Idle     0       0          0             0               2024-10-23     
  Standard (foxml_to_dgis)   filiate                                                                        08:52:16       
  FOXML with MODS to DGI     dgis_nodes           Idle     40      11         0             29              2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:20       
  FOXML with MODS to DGI     store_source_foxml   Idle     40      11         0             0               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:20       
  FOXML with MODS to DGI     dgis_orig_file       Idle     40      3          0             8               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:20       
  FOXML with MODS to DGI     dgis_tn_file         Idle     40      4          0             7               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:21       
  FOXML with MODS to DGI     dgis_orig_media      Idle     40      3          0             0               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:21       
  FOXML with MODS to DGI     dgis_collection_re   Idle     40      2          0             38              2024-10-23     
  Standard (foxml_to_dgis)   presentatives                                                                  08:52:21       
  FOXML with MODS to DGI     dgis_tn_media        Idle     40      4          0             0               2024-10-23     
  Standard (foxml_to_dgis)                                                                                  08:52:21       
 -------------------------- -------------------- -------- ------- ---------- ------------- --------------- --------------- 
```

In the above output you can see an example migration that is currently idle.

The column headers are as follows:
| Column | Description |
|--------|-------------|
| Group | The group that the migration belongs to. |
| Migration ID | The ID of the migration. |
| Status | The current status of the migration where the value is one of the states defined by the [interface][map-interface] |
| Total | The total number of entities that are to be processed. |
| Imported | The number of entities that have been successfully created. This number will not be equivalent to the total as during the run there may be entities that are conditionally created or skipped depending on processing. |
| Unprocessed | The number of entities that have not yet been processed. |
| Message Count | The number of messages that have been logged for the migration in its `migrate_message_{migration_name}` table. |

Stub migrations are unique cases where the migration is using `embedded_data` as
its source. In all other scenarios the `Total` should be equivalent across the
board as the `dgis_foxml_files` migration is the source for all the other
migrations.

### Performance considerations
When a migration runs it is important to understand that anything that tacks
itself onto the PHP thread will still be executed. A prime example of this is
`search_api`'s indexing when set to `Index Immediately` tacks itself onto the
shutdown handler of a PHP thread. Even when a migration itself is running in a
batch context this can cause PHP to run out of memory.

To bypass things like the above [`dgi_migrate_big_set_overrides`][big-sets] is
recommended to be enabled for large ingests as it disables the following:
* Content Sync
* Search API Solr indexing
* OAI-PMH Caching
* Pathauto creation

These are the known culprits that can either cause PHP to run out of memory even
within a batch context or increases the time for the migrations to be completed.

> [!IMPORTANT]
> The above are representative of what has been encountered thus far and
> there could be additional modules to be considered depending on what is added
> and enabled to the environment.

The overrides currently exist in a separate [`config_split`][config-split] split
that can be enabled as needed. Once complete it's important to disable the split
and ensure that items are re-indexed in Solr and have had their paths created as
required.

### Resuming a migration
When a migration exits non-gracefully, the migration can be resumed by invoking
the migration with the original command as denoted
[above](#invoking-the-migration). The migration will use the existing `map`
tables to determine where to pick up from where it left off and will not
re-process any previously processed data.

> [!TIP]
> The migration that caused the error will possibly need its status reset
> which can be done by running `drush migrate:reset-status {migration_name}`.

### Re-running a migration
There are a few scenarios that may be encountered that predicate a migration being
re-run.

#### Ignored or failed entities
The migration completed but there were entities that were `ignored` or `failed`.
Development changes to the migration process can be made and those deployed to
the environment. Once this is complete the migration can be invoked again first
by rolling back only things that were ignored and failed by appending
`--statuses=ignored,failed` to the
[migration rollback command](#rolling-back-a-migration).
The [migration command](#invoking-the-migration) can then be re-invoked to
reprocess only those entities.

#### Small set of changes
The migration completed but there were a small set of entities that need to be
reprocessed. The migration rollback command can be invoked passing
[`--idlist`][idlist] and any entity IDs to be reprocessed. Individual migrations
can also be passed in a similar manner by specifying the migration name.

An example of this would be to rollback only certain source IDs within
`dgis_nodes`.
```bash
bash $DRUPAL_ROOT/modules/contrib/dgi_migrate/scripts/rollback.sh $LOG_DIR --idlist={source_ids} dgis_nodes
```
>[!TIP]
> The `idlist` are referencing the `sourceid1` from the `map` table.

#### Widespread changes
The migration completed but issues were identified that require an entire
migration to be run. 

An example would be the `node` migration's metadata
requires an additional field to be mapped or processing changes. In this case
the single `node` migration can have every entity reprocessed by
invoking the Drush command directly and passing the `--update` flag.

Within a multithreaded context this requires adjusting the
[`.env](#environment-configuration)'s to skip the migrations that do not need
to be re-run to save on execution time.

```bash
# ===
# MULTIPROCESS_SKIP_MIGRATIONS: Skip processing the specified migrations.
# ---
MULTIPROCESS_SKIP_MIGRATIONS=(islandora_tags dgis_foxml_files store_source_foxml dgis_orig_file dgis_tn_file bceln_person_tn_file bceln_mads_to_term_person dgis_orig_file dgis_orig_media dgis_collection_representatives dgis_tn_media)
```

This will target only the `dgi_nodes` migration to be ran. The migration runner
can also be invoked with the `--idlist` as [above](#small-set-of-changes) to
further limit things.
```bash
bash $DRUPAL_ROOT/modules/contrib/dgi_migrate/scripts/migration.sh $LOG_DIR --idlist={source_ids} --update
```

### Identifying problematic entities
It's not uncommon for a migration to have entities skipped or fail to import for
various reasons. There are normally two scenarios where this can occur.

#### Expected parsing failures
This can occur when a file being processed has invalid metadata as being
validated by the migration process or any constraints that Drupal enforces
when the entity is created. These will be handled gracefully and will throw
a [`MigrateSkipRowException`][migrate-skip-row] which will leave a message in
the `messages` table for the row that was skipped in a particular migration.

> [!NOTE]
> Given how dependencies are enforced any other migrations that run after
> that are dependent on the failed row will also be skipped.

#### Unexpected PHP exceptions
This is where the migration process encounters an unexpected error that causes
PHP to white screen and exit. At this point the logs from the webserver would
need to be retrieved to begin the troubleshooting process.

The erroneous entity can be identified by looking at the `map` table for the
migration and looking at the `destid1` column. The last value that does not have
a value set can be inferred as being the culprit.

An example query that could be used is:
```sql
SELECT sourceid1 from migrate_map_dgis_nodes where destid1 IS NULL LIMIT 1;
```

Depending on the migration that exited, `sourceid1` may not lead you directly to
the FOXML itself. In the above example, that corresponds to the `file` entity of
the FOXML file that was originally processed. The URI of this file can be found
by ({file_entity} is the `sourceid1` from the above query):
```sql
SELECT sourceid1 from migrate_map_dgis_foxml_files where destid1 = {file_entity};
```

This yields the original file in `foxml://` stream wrapper form. From here the
most efficient way to find the path on disk is to leverage the `foxml` module:
```php
var_dump(\Drupal::service('foxml.parser.object_lowlevel_storage')->dereference('{thepid}'));

var_dump(\Drupal::service('foxml.parser.object_lowlevel_storage')->dereference('cookie:1'));
```
In the above example the FOXML for the object `cookie:1` is being retrieved.

Once the above object is found, open the file and determine what the issue is.
For migrations dealing with datastream parsing (example: `MODS` or `MADS`) only
the latest version of the datastream is used.
> [!TIP]
> To select the version of the datastream find the newest `CREATED` date.
> Typically this will also be the highest numbered version of the datastream.
> Example:
> ```
> <foxml:datastreamVersion ID="MODS.25" LABEL="MODS Record" CREATED="2024-05-15T18:03:45.275Z" MIMETYPE="application/xml" SIZE="4343">
>   <foxml:contentLocation TYPE="INTERNAL_ID" REF="{pid}+MODS+MODS.25"/>
> </foxml:datastreamVersion>
> ```

Copy the `REF` of the `<foxml:contentLocation>` for use in discovery on disc:
```php
var_dump(\Drupal::service('foxml.parser.datastream_lowlevel_storage')->dereference('{REFOFTHEDS}'));

var_dump(\Drupal::service('foxml.parser.datastream_lowlevel_storage')->dereference('cookie:1+OBJ+OBJ.0'));
```
In the above example the latest version of the `OBJ` datastream for the object
`cookie:1` is being retrieved.

### Metadata changes
If there are changes that need to be made to the metadata, the `objectStore`
will need to be copied [once again](#limiting-by-namespace) as the new versions
of the datastreams will not be reflected in the FOXML. This is due to the
original `objectStore` not being not mounted directly while the
`datastreamStore` is.

[drupal-migrate]: https://www.drupal.org/docs/core-modules-and-themes/core-modules/migrate-drupal-module
[map-interface]: https://git.drupalcode.org/project/drupal/-/blob/10.4.x/core/modules/migrate/src/Plugin/MigrateIdMapInterface.php#L19-55
[foxml-module]: https://github.com/discoverygarden/foxml
[foxml-reference]: https://wiki.lyrasis.org/pages/viewpage.action?pageId=66585857
[akubra-adapter]: https://github.com/discoverygarden/akubra_adapter/
[archival-foxml]: https://wiki.lyrasis.org/display/FEDORA38/REST+API#RESTAPI-export
[akubra-fs]: https://wiki.lyrasis.org/display/AKUBRA
[akubra-readme]: https://github.com/discoverygarden/akubra_adapter/blob/main/README.md#configuration
[dgi-standard-foxml]: https://github.com/discoverygarden/dgi_migrate/tree/main/modules/dgi_migrate_foxml_standard_mods
[bcelndora-migration]: https://github.com/discoverygarden/bcelndora
[node-migration]: https://github.com/discoverygarden/dgi_migrate/blob/main/modules/dgi_migrate_foxml_standard_mods/migrations/dgis_nodes.yml
[dgi-migrate-readme]: https://github.com/discoverygarden/dgi_migrate/blob/main/scripts/README.md
[docker-file]: https://github.com/discoverygarden/bceln-drupal/blob/2ee6002f306f25965b3da6082aef7cb05a8fcd75/Dockerfile#L54-L59
[import-docs]: https://github.com/discoverygarden/dgi_migrate/tree/main/scripts#import
[rollback-docs]: https://github.com/discoverygarden/dgi_migrate/tree/main/scripts#rollback
[big-sets]: https://github.com/discoverygarden/dgi_migrate/tree/main/modules/dgi_migrate_big_set_overrides
[config-split]: https://www.drupal.org/docs/contributed-modules/configuration-split
[idlist]: https://github.com/discoverygarden/dgi_migrate/blob/970471f7e827ffb6c7177d3ec637dc4743e4dc1e/src/Drush/Commands/MigrateCommands.php#L204
[migrate-skip-row]: https://git.drupalcode.org/project/drupal/-/blob/10.4.x/core/modules/migrate/src/MigrateSkipRowException.php
