# Deploying sites and nodes

## Introduction

The stack is managed using the following tools:
 -  Ansible
 -  Helm
 -  Kubectl
 -  aws cli 

This document will explain how to add new nodes, and install/upgrade sites.

## Installing/Updating sites

Each site is contained within a Kubernetes namespace, and each service is
installed via a helm chart. To simplify management, shell scripts have been
created and are stored in the `/opt/helm_values/scripts` directory on the dc
server. The helm configuration for each site is stored in a directory in
`/opt/helm_values` with sub-directories for each service.

The file tree below show the files which will be used to manage sites:
```
/opt/helm_values
├── dc
│   ├── activemq
│   │   └── affinity.yaml -> ../shared/affinity.yaml
│   ├── alpaca
│   │   └── affinity.yaml -> ../shared/affinity.yaml
│   ├── cantaloupe
│   │   ├── affinity.yaml -> ../shared/affinity.yaml
│   │   └── ingress.yaml -> ../shared/ingress.yaml
│   ├── charts.yaml
│   ├── clamav
│   │   └── affinity.yaml -> ../shared/affinity.yaml
│   ├── crayfish
│   │   └── affinity.yaml -> ../shared/affinity.yaml
│   ├── drupal
│   │   ├── affinity.yaml -> ../shared/affinity.yaml
│   │   ├── base.yaml
│   │   ├── ingress.yaml -> ../shared/ingress.yaml
│   │   ├── saml.yaml
│   │   └── values.yaml
│   ├── extras.yaml
│   ├── memcache
│   │   └── affinity.yaml -> ../shared/affinity.yaml
│   ├── postgres
│   │   └── affinity.yaml -> ../shared/affinity.yaml
│   ├── secrets
│   │   └── values.yaml
│   ├── shared
│   │   ├── affinity.yaml
│   │   └── ingress.yaml
│   └── solr
│       └── affinity.yaml -> ../shared/affinity.yaml
└── scripts
    ├── export-config.sh
    ├── fix-perms.sh
    ├── update-all.sh
    └── update-helm.sh
```

### Scripts

#### `update-helm.sh`

This script when provided with a service/helm installation name, helm chart
reference, and a site/namespace, will upgrade or install it. For example,
running `./scripts/update-helm.sh cantaloupe dgi/cantaloupe dc` will install
the cantaloupe chart in the dc namespace. If the script detects any changes, it
will display them to the user with a prompt to apply them.

#### `update-all.sh`

This script will run `update-helm.sh` against all of a site's services. The
script creates a list of services to run against from the `$ns/charts.yaml`
file. The file contains an object called `charts` where the keys are the
service/installation name and the values contains a helm chart reference.

It will also create kubernetes resources found in the file `$ns/extras.yaml`.
Any additional resources required by the site can be defined there.

For example, running `update-all.sh dc` will install all the services for the
dc site declared in the file `dc/charts.yaml`

```yaml
charts:
  secrets:
    chart: dgi/aws-secrets
  activemq:
    chart: dgi/activemq
  alpaca:
    chart: dgi/alpaca
  cantaloupe:
    chart: dgi/cantaloupe
  clamav:
    chart: dgi/clamav
  memcache:
    chart: dgi/memcache
  postgres:
    chart: dgi/postgres
  drupal:
    chart: dgi/drupal
```
The set of charts installed should not have to change across sites.

### `export-config.sh`

This script will export the config for the provided site and store it in a
tarball.

For example, running `export-config.sh dc` will export the config to
`dc/config` and compress it to `dc/config.tar.gz`

### `fix-perms.sh`

This is a helper to provide write access to the `microk8s` group so that all
Kubernetes admins can edit the files. This script needs to be run with root
priveleges.

### Configuration

The helm charts take in yaml files to customize what is deployed. Each site has
a directory containing subdirectories for each service where the yaml files are
stored. The `update-all.sh` and `update-helm.sh` scripts will automatically
reference all the files in a service's directory.

Some of the files are symlinks to avoid repeating configuration that is used by
multiple services. These files are stored in `$ns/shared`

Below will contain explanations of the required configurations.

#### extras.yaml

`$siteName/extras.yaml` is not a helm configuration file but extra resources
that will be created for the site. Currently it only contains the sites
namespace. The name of the namespace and the `dgicloud.com/drupal.site` label
must be updated to match the site name.

Ex:
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    dgicloud.com/drupal.site: oc
  name: oc
```

#### Shared

The configurations in this directory are used by multiple services by being
symlinked.

`affinity.yaml` is required by all services that contain compute
resources(everything other than secrets). It is used to select the correct node
for a site to run on.

```yaml
---
nodeSelector:
  # Set to the hostname of the node the site should run on
  kubernetes.io/hostname: beln-arca-dc.dc.sfu.ca
```

`ingress.yaml` is used by the services which require ingress. Currently only
cantaloupe and drupal. It needs to be updated with the public hostname of the
site.

```yaml
ingress:
  # Set the hostname for the site
  - host: dc-i2.arcabc.ca
    tls:
      issuer: letsencrypt-prod
```

#### Drupal

The drupal directory contains multiple values files. `affinity.yaml` and
`ingress.yaml` are symlinks to the shared configs. 

`base.yaml` contains configuration that should not need to change across sites
but is specific to the cluster. 

```yaml
smtp:
  host: mailhost.sfu.ca
  port: "25"
rwxStorageClass: nfs-csi
fedoraVolume:
  nfs:
    path: /colo/arca_be_data/fedoraData
    readOnly: true
    server: bbysvm-tier1.its.sfu.ca
```

`values.yaml` contains configuration that will be updated for each site.

The two main values that will need to be updated are the `FEDORA_OBJECT_PATH`
value which should point at mounted path of the objectStore for the site. And
the `image.tag` which will set which version of the drupal image is deployed.

```yaml
additionalEnvVars:
  - name: http_proxy
    value: http://bby-vcontrol-proxy.its.sfu.ca:8080
  - name: https_proxy
    value: http://bby-vcontrol-proxy.its.sfu.ca:8080
  - name: no_proxy
    value: cluster.local,arca-stage.its.sfu.ca
  - name: LOG_DIR
    value: /opt/ingest_data/migration
  - name: DRUSH
    value: drush
  # Must be updated per site
  - name: FEDORA_OBJECT_PATH
    value: /data/fedora-data/dc/objectStore
image:
  pullSecret: regcred
  repository: 231224489621.dkr.ecr.us-east-1.amazonaws.com/drupal-bceln
  tag: 1.51.2
```

`saml.yaml` contains the configuration for SimpleSAMLphp and needs to be
configured per site to use saml login. Due to the required AWS permissions the
values for the dgi sso will need to be provided by dgi.

#### Secrets

The secrets chart needs to be configured with the secrets prefix that was used
when running `gen-secrets.sh`

```yaml
# Needs to be set for each site and match what used in the secrets creation script
secretPrefix: prod/bceln
secretStore:
  create: false
  name: aws-secrets
  type: ClusterSecretStore
```

### Installation

#### Secret generation

The site requires secrets to be generated and stored in AWS. To generate the
secrets, use
[`gen-secrets.sh`](https://github.com/discoverygarden/helm-charts/blob/main/charts/aws-secrets/gen-secrets.sh)
in the dgi helm-charts repo.

To run the script on your workstation, you need to have access to the
containerprod account with the permissions to create secrets.

Run the script with the secret prefix to generate the secrets. 

Ex: `./gen-secrets.sh bceln/siteName`

#### Configuration and installation

On the dc server cd to `/opt/helm_values` and copy an existing site's directory
as a starting point. Then update the sites configuration based on the
[configuration](#configuration) section of this document.

To install the site run `./scripts/update-all.sh siteName`.

Ex: For a site named foo
```bash
cd /opt/helm_values
cp -r dc foo
# make required configuration changes
vim foo/shared/affinity.yaml 

./scripts/update-all.sh foo
```

### Upgrading

Running `update-helm.sh` and `update-all.sh` will deploy the latest release to
a service. However, some more care is required when updating drupal.

Before updating, drupal configuration should be exported and merged back in.
The proccess involves checking out the currently deployed tag locally and
replacing the drupal configs with what is running in production, then creating
a pull request.

Example:
```bash
ssh beln-arca-dc.dc.sfu.ca
cd /opt/helm_values
# export the configs
./scripts/export-config.sh dc
# get the currently deployed tag
./scripts/get-tag.sh dc
exit

# cd to where the repo exists locally
cd bceln-drupal
# checkout the tag that is currently deployed into a prod reconcile branch
git checkout -b dc-reconcile vTagFromGetTag
# Delete existing config to get a clean diff
rm -rf config

# Get exported configs from the server and extract them locally.
scp beln-arca-dc.dc.sfu.ca:/opt/helm_values/dc/config.tar.gz .
tar -xf config.tar.gz
rm config.tar.gz

# Commit and push
git add config
git commit -m 'DC reconcile'
git push --set-upstream origin dc-reconcile

# Create the pull request, can also be done from the GitHub website
gh pr create --title="DC reconcile" --body="" --label="patch"
```

Once the pull request has been merged and the new image built, the drupal
installtion can be updated.

When updating drupal, a backup of the database will be taken and config will be
imported.

## Deploying nodes

We use ansible to deploy microk8s to new nodes. The [playbook's
repository](https://github.com/discoverygarden/docker-dgi-proto/tree/main/server-setup)
contains the full documentation on how to create a cluster from scratch. Since
the cluster has already been created this document will explain how to add
additional nodes to the cluster.

## Local requirements Before running the following requirements must be
installed.

 - [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
 - [python boto 3](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/quickstart.html#installation)
 - botocore `pip install botocore`
 - [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Your workstation must also be configured to access the containerprod account
with read access the required secrets.

For bceln add the following profile to your aws config.
```
[profile bceln-deploy]
sso_start_url = https://discoverygarden.awsapps.com/start#/
sso_region = us-east-1
sso_account_id = 231224489621
sso_role_name = bceln-deploy
region = us-east-1
```

## Adding the Node with Ansible

First, make sure you have added your ssh keys to the bastion and new node, and
that you ssh you are only prompted for an mfa code.

Clone https://github.com/discoverygarden/docker-dgi-proto and cd into
`server-setup`

To add the node to the cluster in ansible add the hostname under `[bceln_prod]`
in `inventory/prod`.

To test the connection and that it has been added to the correct group run the
following command with the new node's hostname instead of dc's, and input you
password, and mfa code when prompted. You should 

```bash
ansible -i inventory/prod -m ping --become --ask-become-pass 'bceln_prod:&beln-arca-dc.dc.sfu.ca'
BECOME password: 
(user@bastion) Enter your SFU MFA code: 111111
beln-arca-dc.dc.sfu.ca | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

If running ansible from a mac run `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` before running the playbook.

To provision the node with Ansible run replacing the hostname with that of the
new node:

```bash
ansible-playbook microk8s.yml -i inventory/prod --diff --ask-become-pass -l new.node.hostname
```

Once microk8s has been provisioned add the node the cluster by running:
1. `microk8s add-node` on the dc node.
1. Run the generated `microk8s join` command on the new node.
1. To verify that the node has been added run `Kubectl get nodes` from the dc
   node.
