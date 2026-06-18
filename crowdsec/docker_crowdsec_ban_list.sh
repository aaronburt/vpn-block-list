#!/bin/bash
# Automatically generated CrowdSec ban list script (Docker variant).
# Generated on: 18 June 2026

CSV_URL="https://raw.githubusercontent.com/aaronburt/vpn-block-list/refs/heads/main/crowdsec/decisions.csv"
TMP_CSV="/tmp/decisions.csv"

echo "Downloading decisions CSV..."
if ! curl -sSL -o "${TMP_CSV}" "${CSV_URL}"; then
    echo "Error: Failed to download decisions CSV." >&2
    exit 1
fi

echo "Clearing previous imported decisions..."
docker exec crowdsec cscli decisions delete --origin cscli-import

echo "Importing 7170 ban decisions..."
docker cp "${TMP_CSV}" crowdsec:/tmp/decisions.csv
docker exec crowdsec cscli decisions import -i /tmp/decisions.csv
docker exec crowdsec rm /tmp/decisions.csv

rm -f "${TMP_CSV}"
echo "Successfully applied 7170 ban decisions to CrowdSec."
