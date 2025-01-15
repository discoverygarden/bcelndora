#!/bin/bash

ns=${1?"A namespace is required"}

check_github() {
  local resp=$(ssh git@github.com -T 2>&1 )
  if ! [[ "$resp" =~ "You've successfully authenticated" ]]; then
    echo Failed to authenticate with GitHub.
    echo $resp
    return 1
  fi
}

check_github || exit 1

cd $ns

if ! [ -d bceln-drupal ]; then
  git clone git@github.com:discoverygarden/bceln-drupal.git
fi
cd bceln-drupal
git fetch --all

image=$(kubectl get -n $ns deployments.apps drupal -o jsonpath='{.spec.template.spec.containers[0].image}')
tag="v${image##*:}"

branch="prod-$ns-$tag"

echo Pushing configs to the branch $branch

if ! git rev-parse --verify "refs/heads/$branch" &>/dev/null; then
  git branch $branch
fi
git switch $branch > /dev/null

rm -rf config config.tar.gz

echo Exporting configs from $ns
pod_name=$(kubectl get pods -n $ns -l component=drupal -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ns exec $pod_name -- drush cex --yes
kubectl -n $ns cp $pod_name:config config

if [ -z "$(git status --porcelain config)" ]; then
  echo No changes to commit
  exit 
fi

git add config
git commit -m "Auto commit $(data)"
git push --set-upstream origin $branch
