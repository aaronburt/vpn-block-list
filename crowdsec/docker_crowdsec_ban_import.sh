#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CROWDSEC_CONTAINER:-crowdsec}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CSV="${SCRIPT_DIR}/decisions.csv"
REMOTE_URL="https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/decisions.csv"

if [ -f "$LOCAL_CSV" ]; then
  docker exec -i "$CONTAINER_NAME" cscli decisions import --input - --format csv < "$LOCAL_CSV"
else
  curl -sSL "$REMOTE_URL" | docker exec -i "$CONTAINER_NAME" cscli decisions import --input - --format csv
fi
