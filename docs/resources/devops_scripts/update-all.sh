#/bin/bash
#set -x

SCRIPTS_DIR="$(dirname -- "${BASH_SOURCE[0]}")"

namespace=${1?"A namespace is required"}

echo Checking if extra manifests need updates.
if ! kubectl diff -n $namespace -f $namespace/extras.yaml; then
  echo Updates to the extra kubernetes manifests are avilable or kubectl diff failed to run.
  read -p "Apply Updates (y/n)?" choice
  case "$choice" in
    y|Y ) kubectl apply -n $namespace -f $namespace/extras.yaml;;
    n|N ) ;;
    * ) echo "invalid"; exit 1;;
  esac
fi

charts_file=$namespace/charts.yaml
if [ ! -f $charts_file ]; then
  echo Charts file $charts_file does not exist
  exit 1
fi

helm repo update dgi

for installation in $(yq < $charts_file  '.charts | keys[]'); do
  chart=$(yq < $charts_file ".charts[\"$installation\"].chart")
  $SCRIPTS_DIR/update-helm.sh $installation $chart $namespace
  update_status=$?
  if [ "$update_status" -ne 0 ]; then
    echo Failed to update $installation in $namespace
    read -p "Continue with updates (y/n)?" choice
    case "$choice" in 
      n|N ) exit 1;;
      * ) ;;
    esac
  fi 
done

