#/bin/bash
#set -x

SCRIPTS_DIR="$(dirname -- "${BASH_SOURCE[0]}")"

namespace=${1?"A namespace is required"}

charts_file=$namespace/charts.yaml
if [ ! -f $charts_file ]; then
  echo Charts file $charts_file does not exist
  exit 1
fi

helm repo update dgi

for installation in $(yq < $charts_file  '.charts | keys[]'); do
  chart=$(yq < $charts_file ".charts[\"$installation\"].chart")
  if ! $SCRIPTS_DIR/update-helm.sh $installation $chart $namespace; then
    echo Failed to update $installation in $namespace
    read -p "Continue with updates (y/n)?" choice
    case "$choice" in 
      n|N ) exit 1;;
      * ) ;;
    esac
  fi 
done

