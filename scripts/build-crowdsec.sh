#!/usr/bin/env bash
set -Eeuo pipefail

INPUT_FILE="vpn-blocklist.txt"
OUTPUT_DIR="crowdsec"
CSV_FILE="${OUTPUT_DIR}/decisions.csv"
IMPORT_SCRIPT="${OUTPUT_DIR}/docker_crowdsec_ban_import.sh"
DECISION_REASON="VPN Blocklist"
DECISION_DURATION="24h"

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: ${INPUT_FILE} not found." >&2
  exit 1
fi

if ! grep -qi "# End" "${INPUT_FILE}"; then
  echo "Error: ${INPUT_FILE} is missing the '# End' validation line." >&2
  exit 1
fi

printf "duration,type,reason,scope,value\n" > "$CSV_FILE"

awk -v reason="$DECISION_REASON" -v dur="$DECISION_DURATION" '
  !/^[[:space:]]*(#|$)/ {
    sub(/\r$/, "")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if ($0 != "") {
      print dur ",ban," reason ",range," $0
    }
  }
' "$INPUT_FILE" >> "$CSV_FILE"

cat << 'EOF' > "$IMPORT_SCRIPT"
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
EOF

chmod +x "$IMPORT_SCRIPT"
rm -f "${OUTPUT_DIR}/crowdsec_ban_list.sh" "${OUTPUT_DIR}/docker_crowdsec_ban_list.sh"

echo "CrowdSec decisions generated into $CSV_FILE and $IMPORT_SCRIPT"
