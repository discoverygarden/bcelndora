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

if ! [ -d $ns ]; then
  echo The site $ns does not exist
  exit 1
fi

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
  git branch $branch $tag
fi
git switch $branch > /dev/null

rm -rf config config.tar.gz

echo Exporting configs from $ns
pod_name=$(kubectl get pods -n $ns -l component=drupal -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ns exec $pod_name -- drush cex --yes
kubectl -n $ns cp $pod_name:config config

split_dir="config/splits/sites/$ns"

if [ ! -d "$split_dir" ]; then
  echo "Split directory $split_dir does not exist. Nothing to commit."
  exit 0
fi

if [ -z "$(git status --porcelain "$split_dir")" ]; then
  echo "No changes to commit in $split_dir"
  exit 0
fi

git add "$split_dir"/*

if git diff --cached --quiet -- "$split_dir"; then
  echo "No staged changes in $split_dir to commit."
  exit 0
fi

git commit -m "Auto commit $(date) for $ns split"
git push --set-upstream origin $branch

gh pr create --title="$ns reconcile" --body="" --label="patch"
