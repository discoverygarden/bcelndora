#!/bin/bash

FEDORA_DATA="${FEDORA_DATA:-/usr/local/fedora/data}";

if [[ -z "${NAMESPACES}" ]]; then
    echo "Error: NAMESPACES needs to be defined, and should be a comma separated list of namespaces."
    exit 1
fi

if [[ ! -d "${FEDORA_DATA}/objectStore" ]]; then
    echo "Error: The objectStore directory does not exist at $FEDORA_DATA/objectStore".
    exit 1;
fi

IFS=',' read -r -a namespaces <<< "$NAMESPACES"

for NAMESPACE in "${namespaces[@]}"; do
    mkdir -p "$FEDORA_DATA/$NAMESPACE"

    cd "${FEDORA_DATA}/objectStore" || exit 1

    find . -name "info%3Afedora%2F${NAMESPACE}%3A*" > "$FEDORA_DATA/$NAMESPACE-filelist"

    cd $FEDORA_DATA

    while read -r i; do
        rsync -R "objectStore/$i" "$NAMESPACE/"
    done < "$FEDORA_DATA/$NAMESPACE-filelist"
done
