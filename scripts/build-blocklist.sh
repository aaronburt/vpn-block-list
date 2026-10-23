#!/usr/bin/env bash
set -Eeuo pipefail

ASN_JSON="asn.json"
ASN_LIST_DIR="asn_list"
INDIVIDUAL_DIR="individual_blocklists"
CATEGORY_DIR="lists"
OUTPUT_FILE="vpn-blocklist.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="$(command -v python3 || command -v python)"
# Fail the build instead of shipping a silently smaller list.
MAX_MISSING_ASNS="${MAX_MISSING_ASNS:-2}"
MAX_SHRINK_PERCENT="${MAX_SHRINK_PERCENT:-20}"

previous_count=0
if [ -s "$OUTPUT_FILE" ]; then
  previous_count=$(grep -c . "$OUTPUT_FILE" || true)
fi

mkdir -p "$ASN_LIST_DIR"
rm -rf "$INDIVIDUAL_DIR" "$CATEGORY_DIR"
mkdir -p "$INDIVIDUAL_DIR" "$CATEGORY_DIR"
> "$OUTPUT_FILE"

mapfile -t asn_rows < <(jq -r '.[] | [.asn, .name, (.category // "uncategorized"), (.description // "")] | @tsv' "$ASN_JSON")

curl_config=$(mktemp)
for row in "${asn_rows[@]}"; do
  IFS=$'\t' read -r asn name category desc <<< "$row"
  echo "url = \"https://cdn.jsdelivr.net/gh/ipverse/as-ip-blocks/as/${asn}/aggregated.json\"" >> "$curl_config"
  echo "output = \"$ASN_LIST_DIR/${asn}.json\"" >> "$curl_config"
done

curl --parallel --parallel-immediate --parallel-max 16 --silent --fail --location --retry 3 --connect-timeout 5 --max-time 15 --config "$curl_config" || true
rm -f "$curl_config"

missing=0
for row in "${asn_rows[@]}"; do
  IFS=$'\t' read -r asn name category desc <<< "$row"
  target_file="$ASN_LIST_DIR/${asn}.json"

  if [ ! -s "$target_file" ]; then
    echo "Warning: Missing or empty data for AS$asn ($name)" >&2
    missing=$((missing + 1))
    continue
  fi

  safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//')
  indiv_file="$INDIVIDUAL_DIR/${safe_name}.txt"
  safe_category=$(echo "$category" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//')
  category_file="$CATEGORY_DIR/${safe_category:-uncategorized}.txt"

  # Validation happens in scan-overlaps.py, which uses Python's ipaddress module.
  prefixes=$(jq -r '.prefixes.ipv4[]?, .prefixes.ipv6[]?' "$target_file" 2>/dev/null | awk 'NF && !seen[$0]++' || true)

  if [ -n "$prefixes" ]; then
    echo "$prefixes" >> "$indiv_file"
    echo "$prefixes" >> "$category_file"
    echo "$prefixes" >> "$OUTPUT_FILE"
  fi
done

if [ "$missing" -gt "$MAX_MISSING_ASNS" ]; then
  echo "Error: $missing ASNs had no data (limit $MAX_MISSING_ASNS). Refusing to publish." >&2
  exit 1
fi

"$PYTHON_BIN" "${SCRIPT_DIR}/scan-overlaps.py" --merge --split "$INDIVIDUAL_DIR"/*.txt "$CATEGORY_DIR"/*.txt "$OUTPUT_FILE"

new_count=$(grep -c . "$OUTPUT_FILE" || true)
if [ "$previous_count" -gt 0 ] && [ $((new_count * 100)) -lt $((previous_count * (100 - MAX_SHRINK_PERCENT))) ]; then
  echo "Error: blocklist shrank from $previous_count to $new_count prefixes (more than ${MAX_SHRINK_PERCENT}%). Refusing to publish." >&2
  exit 1
fi

echo "Blocklist successfully built into $OUTPUT_FILE"
