#!/bin/bash
set -euo pipefail

ns=${1?"A namespace is required"}

workflow_template_name="drupal-export-config"

# Check if the Argo WorkflowTemplate exists (post-migration clusters)
wf_exists=$(kubectl get workflowtemplate "$workflow_template_name" -n "$ns" --ignore-not-found -o name 2>/dev/null || echo "")

if [[ -n "$wf_exists" ]]; then
  echo "Submitting Argo WorkflowTemplate '$workflow_template_name' in namespace '$ns'..."
  workflow_name=$(kubectl create -n "$ns" -o jsonpath='{.metadata.name}' -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ${workflow_template_name}-
spec:
  workflowTemplateRef:
    name: ${workflow_template_name}
EOF
)
  echo "Workflow '$workflow_name' created. Waiting for completion..."

  for i in {1..60}; do
    phase=$(kubectl get workflow "$workflow_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [[ "$phase" == "Succeeded" ]]; then
      break
    elif [[ "$phase" == "Failed" || "$phase" == "Error" ]]; then
      echo "Workflow failed (phase: $phase)."
      kubectl logs -n "$ns" -l workflows.argoproj.io/workflow="$workflow_name" --prefix || true
      exit 1
    fi
    sleep 10
  done

  phase=$(kubectl get workflow "$workflow_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$phase" == "Succeeded" ]]; then
    echo "Workflow succeeded. Logs:"
    kubectl logs -n "$ns" -l workflows.argoproj.io/workflow="$workflow_name" --prefix || true
    exit 0
  else
    echo "Workflow did not complete successfully (phase: ${phase:-timeout})."
    kubectl logs -n "$ns" -l workflows.argoproj.io/workflow="$workflow_name" --prefix || true
    exit 1
  fi
fi

# Fall back to CronJob-based approach for clusters not yet migrated
job_name="${ns}-config-export-$(date +%s)"

# Detect the config export CronJob by pattern
cronjob_name=$(kubectl get cronjob -n "$ns" -o name 2>/dev/null | grep "config-export-cron" | head -1 | sed 's|.*/||')

if [[ -z "$cronjob_name" ]]; then
  echo "Neither WorkflowTemplate '$workflow_template_name' nor a config-export CronJob found in namespace '$ns'."
  exit 1
fi

# Check CronJob is not suspended
cronjob_status=$(kubectl get cronjob "$cronjob_name" -n "$ns" -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "notfound")
if [[ "$cronjob_status" == "true" ]]; then
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
    kubectl logs -n "$ns" -l "job-name=$job_name" || true
    exit 1
  fi
  sleep 10
done

# Final check for completion
job_status=$(kubectl get job $job_name -n $ns -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")

if [[ "$job_status" == "1" ]]; then
  pod_name=$(kubectl get pods -n $ns --selector=job-name=$job_name -o jsonpath='{.items[0].metadata.name}')
  echo "Job succeeded. Tailing logs:"
  kubectl logs -n "$ns" "$pod_name"
  kubectl delete job "$job_name" -n "$ns" --wait=false
  exit 0
else
  echo "Job did not complete successfully (timeout or unknown error)."
  kubectl logs -n "$ns" -l "job-name=$job_name" || true
  exit 1
fi