#!/bin/bash
set -euo pipefail

ns=${1?"A namespace is required"}

cronjob_name="drupal-index-solr"
job_name="${ns}-index-solr-$(date +%s)"

# Check if the CronJob exists and is enabled (suspend=false)
cronjob_status=$(kubectl get cronjob "$cronjob_name" -n "$ns" -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "notfound")
if [[ "$cronjob_status" == "notfound" ]]; then
    echo "CronJob '$cronjob_name' does not exist in namespace '$ns'."
    exit 1
elif [[ "$cronjob_status" == "true" ]]; then
    echo "CronJob '$cronjob_name' is currently suspended (disabled) in namespace '$ns'."
    exit 1
fi

echo "Creating a manual Job from CronJob '$cronjob_name' in namespace '$ns'..."
kubectl create job --from=cronjob/$cronjob_name $job_name -n $ns

echo "Job created: $job_name"
echo "To follow logs, run:"
echo "  kubectl logs -n \"$ns\" -l job-name=$job_name -f"
exit 0
