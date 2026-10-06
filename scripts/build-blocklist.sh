#!/usr/bin/env bash
set -Eeuo pipefail

ASN_JSON="asn.json"
ASN_LIST_DIR="asn_list"
INDIVIDUAL_DIR="individual_blocklists"
OUTPUT_FILE="vpn-blocklist.txt"

mkdir -p "$ASN_LIST_DIR"
rm -rf "$INDIVIDUAL_DIR"
mkdir -p "$INDIVIDUAL_DIR"

printf "# Known VPN Provider Endpoints & Commercial Data Center ASN Blocks\n# Auto-generated — do not edit manually\n\n" > "$OUTPUT_FILE"

mapfile -t asn_rows < <(jq -r '.[] | [.asn, .name, (.description // "")] | @tsv' "$ASN_JSON")

curl_config=$(mktemp)
for row in "${asn_rows[@]}"; do
  IFS=$'\t' read -r asn name desc <<< "$row"
  echo "url = \"https://cdn.jsdelivr.net/gh/ipverse/as-ip-blocks/as/${asn}/aggregated.json\"" >> "$curl_config"
  echo "output = \"$ASN_LIST_DIR/${asn}.json\"" >> "$curl_config"
done

curl --parallel --parallel-immediate --parallel-max 16 --silent --fail --location --retry 3 --connect-timeout 5 --max-time 15 --config "$curl_config" || true
rm -f "$curl_config"

for row in "${asn_rows[@]}"; do
  IFS=$'\t' read -r asn name desc <<< "$row"
  target_file="$ASN_LIST_DIR/${asn}.json"

  if [ ! -s "$target_file" ]; then
    echo "Warning: Missing or empty data for AS$asn ($name)" >&2
    continue
  fi

  safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//')
  indiv_file="$INDIVIDUAL_DIR/${safe_name}.txt"

  if [ ! -f "$indiv_file" ]; then
    printf "# %s VPN Blocklist\n# Auto-generated — do not edit manually\n\n" "$name" > "$indiv_file"
  fi

  printf "# %s - AS%s\n" "$name" "$asn" >> "$OUTPUT_FILE"
  printf "# AS%s\n" "$asn" >> "$indiv_file"
  if [ -n "$desc" ]; then
    printf "# %s\n" "$desc" >> "$OUTPUT_FILE"
    printf "# %s\n" "$desc" >> "$indiv_file"
  fi

  prefixes=$(jq -r '.prefixes.ipv4[]?, .prefixes.ipv6[]?' "$target_file" 2>/dev/null | awk '!seen[$0]++ && ($0 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}\/([0-9]|[1-2][0-9]|3[0-2])$/ || $0 ~ /^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}\/([0-9]|[1-9][0-9]|1[0-2][0-8])$/)' || true)

  if [ -n "$prefixes" ]; then
    echo "$prefixes" | tee -a "$OUTPUT_FILE" >> "$indiv_file"
  fi
  printf "\n" >> "$OUTPUT_FILE"
  printf "\n" >> "$indiv_file"
done

printf "# End\n" >> "$OUTPUT_FILE"

for f in "$INDIVIDUAL_DIR"/*.txt; do
  printf "# End\n" >> "$f"
done

echo "Blocklist successfully built into $OUTPUT_FILE"
