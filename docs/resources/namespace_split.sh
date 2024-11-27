#!/bin/bash

FEDORA_DATA="${FEDORA_DATA:-/usr/local/fedora/data}"

if [[ -z "${NAMESPACES}" ]]; then
    echo "Error: NAMESPACES needs to be defined, and should be a comma separated list of namespaces."
    exit 1
fi

EXPORT_DIR=${EXPORT_DIR:-$FEDORA_DATA/$NAMESPACES}

if [[ ! -d "${FEDORA_DATA}/objectStore" ]]; then
    echo "Error: The objectStore directory does not exist at $FEDORA_DATA/objectStore"
    exit 1
fi

IFS=',' read -r -a namespaces <<< "$NAMESPACES"

mkdir -p "$EXPORT_DIR"

cd "${FEDORA_DATA}/objectStore" || exit 1

for NAMESPACE in "${namespaces[@]}"; do
    find . -name "info%3Afedora%2F${NAMESPACE}%3A*" >> "$EXPORT_DIR/filelist"
done

cd $FEDORA_DATA

while read -r i; do
    rsync -R "objectStore/$i" "$EXPORT_DIR/"
done < "$EXPORT_DIR/filelist"
