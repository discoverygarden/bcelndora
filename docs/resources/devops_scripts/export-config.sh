#!/bin/bash
set -euo pipefail

ns=${1?"A namespace is required"}

cronjob_name="bceln-drupal-config-export-cron"
job_name="${ns}-config-export-$(date +%s)"

# Check if a job with the same name already exists in the namespace
if kubectl get job "$job_name" -n "$ns" &>/dev/null; then
  echo "A job named '$job_name' already exists in namespace '$ns'. Remove existing job before running this script."
  echo "You can remove it with: kubectl delete job $job_name -n $ns"
  echo "Exiting..."
  exit 1
fi

echo "Creating a manual Job from CronJob '$cronjob_name' in namespace '$ns'..."
kubectl create job --from=cronjob/$cronjob_name $job_name -n $ns

echo "Waiting for Job '$job_name' to complete"

# Wait for either completion or failure
for i in {1..60}; do
  job_status=$(kubectl get job $job_name -n $ns -o jsonpath='{.status.conditions[*].type}' 2>/dev/null || echo "")
  if [[ "$job_status" == *"Complete"* ]]; then
    break
  elif [[ "$job_status" == *"Failed"* ]]; then
    echo "Job failed."
    kubectl logs -n "$ns" -l job-name=$job_name || true
    exit 1
  fi
  sleep 10
done

# Final check for completion
job_status=$(kubectl get job $job_name -n $ns -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")

if [[ "$job_status" == "1" ]]; then
  pod_name=$(kubectl get pods -n $ns --selector=job-name=$job_name -o jsonpath='{.items[0].metadata.name}')
  echo "Job succeeded. Tailing logs:"
  kubectl logs -f -n "$ns" "$pod_name"
  kubectl delete job "$job_name" -n "$ns" --wait=false
  exit 0
else
  echo "Job did not complete successfully (timeout or unknown error)."
  kubectl logs -n "$ns" -l job-name=$job_name || true
fi