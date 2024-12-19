#/bin/bash

namespace=${1?"A namespace is required"}

kubectl get deployment -n $namespace drupal -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
