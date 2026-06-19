#!/bin/bash
set -euo pipefail

is_valid_cidr() {
    local input="$1"
    local addr prefix

    if [[ "$input" != */* ]]; then
        return 1
    fi

    addr="${input%/*}"
    prefix="${input##*/}"

    [[ "$prefix" =~ ^[0-9]+$ ]] || return 1

    if [[ "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        (( prefix > 32 )) && return 1
        IFS='.' read -r -a octets <<< "$addr"
        for octet in "${octets[@]}"; do
            (( octet > 255 )) && return 1
        done
        return 0
    fi

    if [[ "$addr" == *:* ]]; then
        (( prefix > 128 )) && return 1
        if [[ "$addr" == *::* ]]; then
            local left="${addr%%::*}"
            local right="${addr#*::}"
            local left_count=0 right_count=0
            [[ -n "$left" ]] && IFS=':' read -r -a left_parts <<< "$left" && left_count=${#left_parts[@]}
            [[ -n "$right" ]] && IFS=':' read -r -a right_parts <<< "$right" && right_count=${#right_parts[@]}
            (( left_count + right_count > 7 )) && return 1
            local all_groups=("${left_parts[@]:-}" "${right_parts[@]:-}")
        else
            IFS=':' read -r -a all_groups <<< "$addr"
            [[ ${#all_groups[@]} -ne 8 ]] && return 1
        fi
        for group in "${all_groups[@]}"; do
            [[ -z "$group" ]] && continue
            [[ ${#group} -gt 4 ]] && return 1
            [[ "$group" =~ ^[0-9a-fA-F]+$ ]] || return 1
        done
        return 0
    fi

    return 1
}

sync_vpn_blocklist() {
    local blocklist_file="vpn-blocklist.txt"
    local remote_url="https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt"
    local temp_used=false
    local lockfile="/tmp/vpn-blocklist-sync.lock"

    exec 9>"$lockfile"
    if ! flock -n 9; then
        echo "Error: Another instance is already running."
        return 1
    fi

    if [[ ! -f "$blocklist_file" ]]; then
        blocklist_file=$(mktemp)
        temp_used=true
        local http_code
        http_code=$(curl -sSL -w '%{http_code}' "$remote_url" -o "$blocklist_file")
        if [[ "$http_code" -ne 200 ]]; then
            echo "Error: Failed to retrieve remote blocklist (HTTP $http_code)."
            rm -f "$blocklist_file"
            return 1
        fi
    fi

    local last_non_empty_line
    last_non_empty_line=$(grep -v '^$' "$blocklist_file" | tail -n 1 | sed 's/[[:space:]]*$//')

    if [[ "$last_non_empty_line" != "# End" ]]; then
        echo "Error: Structural validation failed. Missing trailing '# End' line signature."
        [[ "$temp_used" = true ]] && rm -f "$blocklist_file"
        return 1
    fi

    local validated_ranges=()

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        [[ "$raw_line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${raw_line//[[:space:]]/}" ]] && continue

        local clean_line
        clean_line=$(echo "$raw_line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$clean_line" ]] && continue

        if is_valid_cidr "$clean_line"; then
            validated_ranges+=("$clean_line")
        else
            echo "Warning: Excluding malformed network range: $clean_line"
        fi
    done < "$blocklist_file"

    [[ "$temp_used" = true ]] && rm -f "$blocklist_file"

    if [[ ${#validated_ranges[@]} -eq 0 ]]; then
        echo "Error: No valid network ranges found."
        return 1
    fi

    echo "Importing ${#validated_ranges[@]} verified network ranges..."
    if printf '%s\n' "${validated_ranges[@]}" | \
        docker exec -i crowdsec cscli decisions import \
            --input - \
            --format values \
            --scope range \
            --reason "VPN Blocklist" \
            --type ban \
            --duration "24h"; then
        echo "Successfully synchronized ${#validated_ranges[@]} decision records."
    else
        echo "Error: Failed to import decisions into CrowdSec."
        return 1
    fi
}

sync_vpn_blocklist
