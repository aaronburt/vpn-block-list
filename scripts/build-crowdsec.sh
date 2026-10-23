#!/usr/bin/env bash
set -Eeuo pipefail

INPUT_FILE="vpn-blocklist.txt"
OUTPUT_DIR="crowdsec"
CSV_FILE="${OUTPUT_DIR}/decisions.csv"
DECISION_REASON="VPN Blocklist"
DECISION_DURATION="24h"

mkdir -p "$OUTPUT_DIR"

if [ ! -s "$INPUT_FILE" ]; then
  echo "Error: ${INPUT_FILE} not found or empty." >&2
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

echo "CrowdSec decisions generated into $CSV_FILE"
