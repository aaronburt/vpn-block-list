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

echo "Generated ${DECISIONS_FILE} with ${count} CIDR ranges."

cat << EOF > "${OUTPUT_SCRIPT}"
#!/bin/bash
# Automatically generated CrowdSec ban list script.
# Generated on: $(date +"%d %B %Y")

echo "Clearing previous decisions for '${DECISION_REASON}'..."
cscli decisions delete --reason "${DECISION_REASON}"

echo "Importing ${count} ban decisions..."
SCRIPT_DIR=\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cscli decisions import -i "\${SCRIPT_DIR}/decisions.csv"
echo "Successfully applied ${count} ban decisions to CrowdSec."
EOF

chmod +x "${OUTPUT_SCRIPT}"
echo "Generated ${OUTPUT_SCRIPT}."

cat << EOF > "${DOCKER_SCRIPT}"
#!/bin/bash
# Automatically generated CrowdSec ban list script (Docker variant).
# Generated on: $(date +"%d %B %Y")

echo "Clearing previous decisions for '${DECISION_REASON}'..."
docker exec crowdsec cscli decisions delete --reason "${DECISION_REASON}"

echo "Importing ${count} ban decisions..."
SCRIPT_DIR=\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" &> /dev/null && pwd)
docker cp "\${SCRIPT_DIR}/decisions.csv" crowdsec:/tmp/decisions.csv
docker exec crowdsec cscli decisions import -i /tmp/decisions.csv
docker exec crowdsec rm /tmp/decisions.csv
echo "Successfully applied ${count} ban decisions to CrowdSec."
EOF

chmod +x "${DOCKER_SCRIPT}"
echo "Generated ${DOCKER_SCRIPT}."
