#!/usr/bin/env bash
set -Eeuo pipefail

ASN_JSON="asn.json"
ASN_LIST_DIR="asn_list"
INDIVIDUAL_DIR="individual_blocklists"
OUTPUT_FILE="vpn-blocklist.txt"

mkdir -p "$ASN_LIST_DIR"
rm -rf "$INDIVIDUAL_DIR"
mkdir -p "$INDIVIDUAL_DIR"

echo "# Known VPN Provider Endpoints & Commercial Data Center ASN Blocks" > "$OUTPUT_FILE"
echo "# Auto-generated — do not edit manually" >> "$OUTPUT_FILE"
echo "# Last updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

jq -c '.[]' "$ASN_JSON" | while read -r row; do
  asn=$(echo "$row" | jq -r '.asn')
  name=$(echo "$row" | jq -r '.name')
  description=$(echo "$row" | jq -r '.description')

  echo "Processing AS$asn ($name)..."
  
  target_file="$ASN_LIST_DIR/${asn}.json"
  url="https://cdn.jsdelivr.net/gh/ipverse/as-ip-blocks/as/${asn}/aggregated.json"
  
  safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//')
  indiv_file="$INDIVIDUAL_DIR/${safe_name}.txt"
  
  if curl -s -f -L -o "$target_file" "$url"; then
    
    if [ ! -f "$indiv_file" ]; then
        echo "# $name VPN Blocklist" > "$indiv_file"
        echo "# Auto-generated — do not edit manually" >> "$indiv_file"
        echo "# Last updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$indiv_file"
        echo "" >> "$indiv_file"
    fi
    
    echo "# $name - AS$asn" >> "$OUTPUT_FILE"
    echo "# AS$asn" >> "$indiv_file"
    if [ -n "$description" ]; then
      echo "# $description" >> "$OUTPUT_FILE"
      echo "# $description" >> "$indiv_file"
    fi

    jq -r '.prefixes.ipv4[]?, .prefixes.ipv6[]?' "$target_file" | tee -a "$OUTPUT_FILE" >> "$indiv_file" || true
    echo "" >> "$OUTPUT_FILE"
    echo "" >> "$indiv_file"
  else
    echo "Warning: Failed to fetch AS$asn from $url" >&2
  fi
done

echo "# End" >> "$OUTPUT_FILE"

for f in "$INDIVIDUAL_DIR"/*.txt; do
  echo "# End" >> "$f"
done

echo "Blocklist successfully built into $OUTPUT_FILE"
