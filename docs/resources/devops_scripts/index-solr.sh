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