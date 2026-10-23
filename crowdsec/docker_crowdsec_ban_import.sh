#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CROWDSEC_CONTAINER:-crowdsec}"
# Space-separated categories to import (e.g. "vpn vpn-infrastructure"). Empty imports the full list.
CATEGORIES="${CATEGORIES:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CSV="${SCRIPT_DIR}/decisions.csv"
BASE_URL="https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main"
REMOTE_URL="${BASE_URL}/crowdsec/decisions.csv"

import_csv() {
  docker exec -i "$CONTAINER_NAME" cscli decisions import --input - --format csv
}

if [ -n "$CATEGORIES" ]; then
  # Download every category first so a typo or outage aborts before anything is imported.
  prefixes=$(for category in $CATEGORIES; do curl -fsSL "${BASE_URL}/lists/${category}.txt"; done)
  {
    printf "duration,type,reason,scope,value\n"
    printf "%s\n" "$prefixes" | awk 'NF && !seen[$0]++ { print "24h,ban,VPN Blocklist,range," $0 }'
  } | import_csv
elif [ -f "$LOCAL_CSV" ]; then
  import_csv < "$LOCAL_CSV"
else
  curl -fsSL "$REMOTE_URL" | import_csv
fi
