#!/usr/bin/env bash
set -Eeuo pipefail

ASN_JSON="asn.json"
ASN_LIST_DIR="asn_list"
OUTPUT_FILE="vpn-blocklist.txt"

mkdir -p "$ASN_LIST_DIR"

echo "# Known VPN Provider Endpoints & Commercial Data Center ASN Blocks" > "$OUTPUT_FILE"
echo "# Auto-generated — do not edit manually" >> "$OUTPUT_FILE"
echo "# Last updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Iterate over each item in the asn.json file
jq -c '.[]' "$ASN_JSON" | while read -r row; do
  asn=$(echo "$row" | jq -r '.asn')
  name=$(echo "$row" | jq -r '.name')
  description=$(echo "$row" | jq -r '.description')

  echo "Processing AS$asn ($name)..."
  
  target_file="$ASN_LIST_DIR/${asn}.json"
  url="https://cdn.jsdelivr.net/gh/ipverse/as-ip-blocks/as/${asn}/aggregated.json"
  
  # Download the source aggregated file, save locally
  if curl -s -f -L -o "$target_file" "$url"; then
    echo "# $name - AS$asn" >> "$OUTPUT_FILE"
    if [ -n "$description" ]; then
      echo "# $description" >> "$OUTPUT_FILE"
    fi

    # Extract ipv4 and ipv6 prefixes and write to output file
    jq -r '.prefixes.ipv4[]?, .prefixes.ipv6[]?' "$target_file" >> "$OUTPUT_FILE" || true
    echo "" >> "$OUTPUT_FILE"
  else
    echo "Warning: Failed to fetch AS$asn from $url" >&2
  fi
done

echo "Blocklist successfully built into $OUTPUT_FILE"
