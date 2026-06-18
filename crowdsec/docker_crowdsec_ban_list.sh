#!/bin/bash
# Automatically generated CrowdSec ban list script (Docker variant).
# Generated on: 18 June 2026

echo "Clearing previous decisions for 'VPN Blocklist'..."
docker exec crowdsec cscli decisions delete --reason "VPN Blocklist"

echo "Importing 7170 ban decisions..."
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
docker cp "${SCRIPT_DIR}/decisions.csv" crowdsec:/tmp/decisions.csv
docker exec crowdsec cscli decisions import -i /tmp/decisions.csv
docker exec crowdsec rm /tmp/decisions.csv
echo "Successfully applied 7170 ban decisions to CrowdSec."
