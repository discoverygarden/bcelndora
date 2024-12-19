#!/bin/bash

ns=${1?"A namespace is required"}
cd $ns

rm -rf config config.tar.gz

pod_name=$(kubectl get pods -n $ns -l component=drupal -o jsonpath='{.items[0].metadata.name}')

kubectl exec $pod_name -- drush cex --yes
kubectl cp $pod_name:config config
tar -czf config.tar.gz config
