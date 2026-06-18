#!/usr/bin/env bash
set -Eeuo pipefail

INPUT_FILE="vpn-blocklist.txt"
OUTPUT_DIR="crowdsec"
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

cat << EOF > "${OUTPUT_SCRIPT}"
#!/bin/bash
# Automatically generated CrowdSec ban list script.
# Generated on: $(date +"%d %B %Y")

echo "Applying ban decisions..."
EOF

cat << EOF > "${DOCKER_SCRIPT}"
#!/bin/bash
# Automatically generated CrowdSec ban list script (Docker variant).
# Generated on: $(date +"%d %B %Y")

echo "Applying ban decisions..."
EOF

count=0
while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | tr -d '\r' | xargs)

    if [[ -n "$line" && ! "$line" =~ ^# ]]; then
        echo "cscli decisions add --range \"${line}\" --reason \"${DECISION_REASON}\" --type ban --duration \"${DECISION_DURATION}\"" >> "${OUTPUT_SCRIPT}"
        echo "docker exec crowdsec cscli decisions add --range \"${line}\" --reason \"${DECISION_REASON}\" --type ban --duration \"${DECISION_DURATION}\"" >> "${DOCKER_SCRIPT}"
        count=$((count + 1))
    fi
done < "${INPUT_FILE}"

echo "echo \"Successfully applied ${count} ban decisions to CrowdSec.\"" >> "${OUTPUT_SCRIPT}"
echo "echo \"Successfully applied ${count} ban decisions to CrowdSec.\"" >> "${DOCKER_SCRIPT}"

chmod +x "${OUTPUT_SCRIPT}"
chmod +x "${DOCKER_SCRIPT}"

echo "Generated ${OUTPUT_SCRIPT} with ${count} CIDR ranges."
echo "Generated ${DOCKER_SCRIPT} with ${count} CIDR ranges."
