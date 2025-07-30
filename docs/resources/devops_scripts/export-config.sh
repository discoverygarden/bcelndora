#!/bin/bash

ns=${1?"A namespace is required"}

cronjob_name="bceln-drupal--config-export-cron"
job_name="${ns}-config-export-$(date +%s)"

echo "Creating a manual Job from CronJob '$cronjob_name' in namespace '$ns'..."
kubectl create job --from=cronjob/$cronjob_name $job_name -n $ns

echo "Waiting for Job '$job_name' to complete..."
kubectl wait --for=condition=complete --timeout=600s job/$job_name -n $ns

job_status=$(kubectl get job $job_name -n $ns -o jsonpath='{.status.succeeded}')

if [[ "$job_status" == "1" ]]; then
  pod_name=$(kubectl get pods -n $ns --selector=job-name=$job_name -o jsonpath='{.items[0].metadata.name}')
  echo "Job succeeded. Tailing logs:"
  kubectl logs -n $ns $pod_name
  exit 0
else
  echo "Job failed or did not complete successfully."
  kubectl describe job $job_name -n $ns
  exit 1
fi