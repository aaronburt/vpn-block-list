#!/usr/bin/env bash
set -Eeuo pipefail

INPUT_FILE="vpn-blocklist.txt"
OUTPUT_DIR="crowdsec"
DECISIONS_FILE="${OUTPUT_DIR}/decisions.csv"
OUTPUT_SCRIPT="${OUTPUT_DIR}/crowdsec_ban_list.sh"
DOCKER_SCRIPT="${OUTPUT_DIR}/docker_crowdsec_ban_list.sh"
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

echo "duration,reason,type,range" > "${DECISIONS_FILE}"

count=0
while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | tr -d '\r' | xargs)

    if [[ -n "$line" && ! "$line" =~ ^# ]]; then
        echo "${DECISION_DURATION},${DECISION_REASON},ban,${line}" >> "${DECISIONS_FILE}"
        count=$((count + 1))
    fi
done < "${INPUT_FILE}"

REPO_CSV_URL="https://raw.githubusercontent.com/aaronburt/vpn-block-list/refs/heads/main/crowdsec/decisions.csv"

cat << EOF > "${OUTPUT_SCRIPT}"
#!/bin/bash
# Automatically generated CrowdSec ban list script.
# Generated on: $(date +"%d %B %Y")

CSV_URL="${REPO_CSV_URL}"
TMP_CSV="/tmp/decisions.csv"

echo "Downloading decisions CSV..."
if ! curl -sSL -o "\${TMP_CSV}" "\${CSV_URL}"; then
    echo "Error: Failed to download decisions CSV." >&2
    exit 1
fi

echo "Clearing previous imported decisions..."
cscli decisions delete --origin cscli-import

echo "Importing ${count} ban decisions..."
cscli decisions import -i "\${TMP_CSV}"

rm -f "\${TMP_CSV}"
echo "Successfully applied ${count} ban decisions to CrowdSec."
EOF

chmod +x "${OUTPUT_SCRIPT}"
echo "Generated ${OUTPUT_SCRIPT}."

cat << EOF > "${DOCKER_SCRIPT}"
#!/bin/bash
# Automatically generated CrowdSec ban list script (Docker variant).
# Generated on: $(date +"%d %B %Y")

CSV_URL="${REPO_CSV_URL}"
TMP_CSV="/tmp/decisions.csv"

echo "Downloading decisions CSV..."
if ! curl -sSL -o "\${TMP_CSV}" "\${CSV_URL}"; then
    echo "Error: Failed to download decisions CSV." >&2
    exit 1
fi

echo "Clearing previous imported decisions..."
docker exec crowdsec cscli decisions delete --origin cscli-import

echo "Importing ${count} ban decisions..."
docker cp "\${TMP_CSV}" crowdsec:/tmp/decisions.csv
docker exec crowdsec cscli decisions import -i /tmp/decisions.csv
docker exec crowdsec rm /tmp/decisions.csv

rm -f "\${TMP_CSV}"
echo "Successfully applied ${count} ban decisions to CrowdSec."
EOF

chmod +x "${DOCKER_SCRIPT}"
echo "Generated ${DOCKER_SCRIPT}."
