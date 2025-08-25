#/bin/bash
#set -x

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

installation=$1
chart=$2
namespace=$3

value_files=($namespace/$installation/*)

echo '##################################################'
echo Checking for updates to $installation in $namespace
err_file=$(mktemp)
helm diff -C2 --detailed-exitcode upgrade --install $installation $chart -n $namespace "${value_files[@]/#/--values=}"  2> $err_file
exit_code=$?

if [ "$exit_code" -eq "0" ]; then
  echo -e "${GREEN}no changes${ENDCOLOR}"
  rm $err_file
  exit
elif [ "$exit_code" -ne "2" ]; then
  echo -e "${RED}failed to check chart $installation${ENDCOLOR}"
  cat $err_file
  rm $err_file
  exit 1
fi 
rm $err_file

echo Updates to $installation in $namespace are available.
read -p "Apply Updates (y/n/s(no-hooks))?" choice
case "$choice" in 
  y|Y )
    helm upgrade --install --timeout=1h $installation $chart -n $namespace "${value_files[@]/#/--values=}"
    upgrade_status=$?
    ;;
  s|S )
    helm upgrade --install --no-hooks --timeout=1h $installation $chart -n $namespace "${value_files[@]/#/--values=}"
    upgrade_status=$?
    ;;
  n|N ) exit 0;;
  * ) 
    echo "invalid"
    exit 1
    ;;
esac

if [[ -n "${upgrade_status+x}" ]]; then
  if [ "$upgrade_status" -eq 0 ]; then
    echo -e "${GREEN}Helm upgrade succeeded.${ENDCOLOR}"
  else
    echo -e "${RED}Helm upgrade failed with exit code $upgrade_status.${ENDCOLOR}"
    echo "Check job logs for more details."
    exit $upgrade_status
  fi
fi
