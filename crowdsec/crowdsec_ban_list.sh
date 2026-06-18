#!/bin/bash
# Automatically generated CrowdSec ban list script.
# Generated on: 18 June 2026

echo "Clearing previous decisions for 'VPN Blocklist'..."
cscli decisions delete --reason "VPN Blocklist"

echo "Importing 7170 ban decisions..."
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cscli decisions import -i "${SCRIPT_DIR}/decisions.csv"
echo "Successfully applied 7170 ban decisions to CrowdSec."
