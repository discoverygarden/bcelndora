# Deploying sites and nodes

## Introduction

The stack is managed using the following tools:
 -  Ansible
 -  Helm
 -  Kubectl
 -  aws cli 

This document will explain how to add new nodes, and install/upgrade sites.

## Provisioning the new machine

Requisition the new machine via the dashboard with the specifications below.

### Virtual machine requirements

Basic specs:
- Network: Private
- Purpose: General

#### Migration

- 12 CPU
- 36 GB RAM

#### Day-to-day operation

- 4cpu
- 12GB Ram
- 200gb HD [minimum; depending on storage requirements]

### Connections

Load balancer: arca-bc-lb.its.sfu.ca

NFS share mounts:
- bbysvm-tier1.its.sfu.ca:/colo/arca_be_data/fedoraData
- bbysvm-tier1.ipstorage.sfu.ca:/beln/arca_data

Request that the firewall rules be same as arca-dc, but specify:

Firewall connections open between ALL machines behind the Arca load balancer (in and out):
- TCP 16443,10250,10255,25000,12378,10257,10259,19001
- UDP 4789

External connections over ports: github.com: 22, 80, 443

Same PROXY as arca-dc and the others


## Install dependencies on local machine

- Ansible: `pip install ansible`
- Boto3: `pip install boto3`
- aws cli: [installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- jq: `brew install jq`.
- Set up the `bceln-deploy` profile:
       - At `~/.aws/config`:
           ```
           [profile bceln-deploy]
           sso_start_url = https://discoverygarden.awsapps.com/start#/
           sso_region = us-east-1
           sso_account_id = 231224489621
           sso_role_name = bceln-deploy
           region = us-east-1
           ```

## Add the node with Ansible

1. Make sure your SSH keys are installed on the new server
    - On your local machine, create your alias for the new site at `~/.ssh/config` -- note that for this to work you need both the alias and the actual hostname in the same line.
        - e.g. 
        ```Host arca-oc beln-arca-oc.dc.sfu.ca
             Hostname beln-arca-oc.dc.sfu.ca
               IdentityFile ~/.ssh/id_rsa
               Port 22
             ProxyCommand ssh welcomebeln nc %h %p
             User bweigel
        ```
    - Copy your key to the new server. eg for the `arca-oc` server, `ssh-copy-id -i ~/.ssh/id_rsa.pub arca-oc`
2. **On your local machine**, clone `docker-dgi-proto`:
    - `git clone https://github.com/discoverygarden/docker-dgi-proto.git`
3. Enter the `server-setup` directory:
    - `cd docker-dgi-proto/server-setup`
4. Edit the `inventory/prod` file: `nano inventory/prod`
    - Add the hostname of your new node under the `bceln-prod` header.
    - Commit your changes, push to Github, and create a pull request, flagging Alexander Cairns for review.
5. Set the environment variables (required before running any Ansible commands):
    - `export AWS_PROFILE=bceln-deploy`
    - `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
6. Test the connection:
    - `ansible -i inventory/prod -m ping --become --ask-become-pass 'bceln_prod:&[new host]'` where `[new host]` is something like `beln-arca-twu.dc.sfu.ca`
    - The "BECOME Password" is your user's password on the server.
7. Log into the deploy profile:
    - `aws sso login --profile bceln-deploy`
8. Provision the node with Ansible: 
    - `ansible-playbook microk8s.yml -i inventory/prod --diff --ask-become-pass -l new.node.hostname` where `new.node.hostname` is, for example, `beln-arca-oc.dc.sfu.ca`
9. Shell into the `arca-dc` server, and add the node to the cluster:
    - `microk8s add-node`
    - Copy the `microk8s join` command it generates.
10. Shell into the new server, and paste the `microk8s join` command from the previous step.
    - If there's a timeout error, there is probably a firewall issue between the servers; contact SFU to deal with it.
11. On the `arca-dc` server, confirm the node has been added with `kubectl get nodes`.


## Install the new site

1. Shell into the Douglas College server
    - `ssh beln-arca-dc.dc.sfu.ca`
2. Go to to the `helm_values` directory
    - `cd /opt/helm_values`
3. Copy an existing site's directory tree for your new site.
    - e.g. if you are creating a new site, "oc", copy the "dc" directory tree:
    - `cp -r dc oc`
4. Edit the deployment configuration files:
    - `shared` directory: `cd /opt/helm_values/[newsite]/shared`
        - [QUESTION: "The configurations in this directory are used by multiple services by being symlinked." Does this mean changing it here changes it everywhere? It doesn't look like it does, as the path from `dc` and the path from `oc` show different values.]
        - Edit `affinity.yaml` to set the new site's hostname
            - eg. ```---
                     nodeSelector:
                     # Set to the hostname of the node the site should run on
                     kubernetes.io/hostname: beln-arca-oc.dc.sfu.ca
                  ```
        - Edit `ingress.yaml` with the public hostname of the site (that is, the URL it will be accessed from).
            - If migrating an existing site, you may put both the temporary URL and the final production URL here. 
            - e.g.
              ```
                ingress:
                  # Set the hostname for the site
               - host: oc.arcabc.ca
                 tls:
                     issuer: letsencrypt-prod
              - host: tempname.arcabc.ca
                 tls:
                     issuer: letsencrypt-prod
              ```
    - `drupal` directory: `cd /opt/helm_values/[newsite]/drupal`
        - Edit `values.yaml`:
            - `FEDORA_OBJECT_PATH`: For migration; points at mounted path of the objectStore for the site. Not necessary if not migrating.
            - `image: tag`: Sets the version of the Drupal image that will be deployed
                - Usually it will be the [latest tag in the bceln-drupal repo](https://github.com/discoverygarden/bceln-drupal/tags) without the v.
        - IF MIGRATING: Do not change `base.yaml` as it's common data across the whole system
            - IF NOT MIGRATING: Remove the lines relating to Fedora.
        
        - Edit `saml.yaml`: [or don't?]
            - "contains the configuration for SimpleSAMLphp and needs to be configured per site to use saml login. Due to the required AWS permissions the values for the dgi sso will need to be provided by dgi.
            - Lets us use DGI's sso on the site. Gives us admin access using the same account across sites, and can allow dgi staff to access the site.
            - We must provide DGI with a list of site URLs ahead of time.
            - DGI will provide a `saml.yaml` file for each site.
            - If you want to have sso just for your own account you could create a free tier Jumpcloud account and manage the sso yourself.
    - `secrets` directory: `cd /opt/helm_values/[siteName]/secrets`
        - Edit `values.yaml`:
            - Set `secretPrefix` to your new site's name in the pattern `bceln/siteName`
                - e.g. if you're creating the Okanagan College site, set it to `bceln/oc` 
                    - `siteName` is the name of the directory you are building your new site in. 
    - Set the namespace: `/opt/helm_values/[newsite]/extras.yaml`
        - In the top section:
            ```
            apiVersion: v1
            kind: Namespace
            metadata:
              labels:
                dgicloud.com/drupal.site: [newsite]
              name: [newsite]
            ```
5. Secret generation:
    - On your personal computer (*not on the server*), run the `gen-secrets.sh` script:
        - Make sure `jq` is installed: `brew install jq`
        - Download from Github: `https://github.com/discoverygarden/helm-charts/blob/main/charts/aws-secrets/gen-secrets.sh`
            - Put it in `~/arca-migration/gen-secrets.sh` for simplicity.
        - Get authorized with AWS SSO:
            - aws sso login --profile bceln-deploy
        - Run `AWS_PROFILE=bceln-deploy ./gen-secrets.sh bceln/[siteName]`
            - The `AWS_PROFILE` piece identifies which profile is being used when running the script.
6. Install the site:
    - In `arca-dc`, go back to the `helm_values` directory: `cd /opt/helm_values`
    - Run the install script: `./scripts/update-all.sh siteName` where `siteName` is [the name of the directory you created???]


# Upgrading a site

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

# Troubleshooting

## Check what's running

In the `arca-dc` server: `helm list -n [namespace]`

This command will list all the Helm services running for a given site.

## Set the namespace context

While working in `arca-dc`, if you want to execute commands in the context of a different namespace:

`kubectl config set-context --current --namespace=[namespace]`

This context will remain until you change it again.

To view which context you're in:

`kubectl config get-contexts`

## If a piece of the installation fails

If one part of the `update-all.sh` installation fails, you will need to delete the job and start it again.

`helm uninstall drupal -n [namespace]` (or whichever job failed)

`kubectl delete jobs drupal-install-drupal -n [namespace]` (or whichever job failed)

`kubectl rollout restart deployment memcache -n [namespace]`

Then execute the script again.

## Check which components are working/failing

`kubectl get pods -n [namespace]`

See what's going on with that pod: `kubectl describe pod [podname] -n [namespace]`

## Shell into a pod

You may need to shell into a pod to execute commands, check logs, etc. Most likely you'll be shelling into the Drupal pod, but there are others too. 

First get a list of all deployments: `kubectl get deployments -n [namespace]`

(To get the specific pod names, you can use `kubectl get pods -n [namespace]`)

Copy the deployment name (e.g. `drupal`), and enter it into this command:

`kubectl -n [namespace] exec --stdin --tty deployment/[deployment-name] -- /bin/bash`

eg `kubectl -n [namespace] exec --stdin --tty deployment/drupal -- /bin/bash`

Or, if the deployment does not contain `bash`, use `/bin/sh`. eg. `kubectl -n [namespace] exec --stdin --tty deployment/activemq -- /bin/sh`

## Logs

Logs can be access with `kubectl logs [pod-name|deployment/name|job/name]`. Add `-f` to follow the logs


## Troubleshooting Example: January 7

For troubleshooting the crayfish pod
I ran `k describe pod crayfish-99cf98b7f-7wqpj` which returns lots of information about the pod.  At the bottom it has the events related to the pod
```
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:

  Type     Reason       Age                 From     Message
  ----     ------       ----                ----     -------
  Warning  FailedMount  14s (x17 over 18m)  kubelet  MountVolume.SetUp failed for volume "crayfish-key" : secret "crayfish-key" not found
```

Which says it's missing the the crayfish-key secret.

Running `k get secrets` shows that the secret does not exist.

We are using external secrets to get the secrets from aws so running `k get es` will return the external secrets

```
NAME               STORE         REFRESH INTERVAL   STATUS              READY
crayfish-key       aws-secrets   1m                 SecretSyncedError   False
drupal-db          aws-secrets   1m                 SecretSyncedError   False
drupal-user        aws-secrets   1m                 SecretSyncedError   False
regcred                          1h                 SecretSynced        True
simplesaml-admin   aws-secrets   1m                 SecretSyncedError   False
simplesaml-cert    aws-secrets   1m                 SecretSyncedError   False
solr-auth          aws-secrets   1m                 SecretSyncedError   False
```

Running `k describe es crayfish-key` has in its status

```
Status:
  Conditions:
    Last Transition Time:  2025-01-06T16:01:26Z
    Message:               could not get secret data from provider
    Reason:                SecretSyncedError
    Status:                False
    Type:                  Ready
Events:                    <none>
```

Getting the yaml repsentation of the secret `k get es crayfish-key` shows that the secret in aws secrets manager is called `bceln/oc/crayfish-keys`
I just checked and that secret exists in aws, so I'm guessing that there's a perms issue.







# Technical Details

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
|   ├── extras.yaml
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
