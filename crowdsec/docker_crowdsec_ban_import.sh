#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CROWDSEC_CONTAINER:-crowdsec}"
# Space-separated categories to import (e.g. "vpn vpn-infrastructure"). Empty imports the full list.
CATEGORIES="${CATEGORIES:-}"
# Optional address family filter: "ipv4" or "ipv6". Empty imports both.
FAMILY="${FAMILY:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CSV="${SCRIPT_DIR}/decisions.csv"
BASE_URL="https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main"
REMOTE_URL="${BASE_URL}/crowdsec/decisions.csv"

import_csv() {
  docker exec -i "$CONTAINER_NAME" cscli decisions import --input - --format csv
}

case "$FAMILY" in
  "") suffix="" ;;
  ipv4|ipv6) suffix="-${FAMILY}" ;;
  *) echo "Error: FAMILY must be ipv4 or ipv6" >&2; exit 1 ;;
esac

if [ -n "$CATEGORIES" ] || [ -n "$FAMILY" ]; then
  if [ -n "$CATEGORIES" ]; then
    urls=$(for category in $CATEGORIES; do echo "${BASE_URL}/lists/${category}${suffix}.txt"; done)
  else
    urls="${BASE_URL}/vpn-blocklist${suffix}.txt"
  fi
  # Download every list first so a typo or outage aborts before anything is imported.
  prefixes=$(for url in $urls; do curl -fsSL "$url"; done)
  {
    printf "duration,type,reason,scope,value\n"
    printf "%s\n" "$prefixes" | awk 'NF && !seen[$0]++ { print "24h,ban,VPN Blocklist,range," $0 }'
  } | import_csv
elif [ -f "$LOCAL_CSV" ]; then
  import_csv < "$LOCAL_CSV"
else
  curl -fsSL "$REMOTE_URL" | import_csv
fi
