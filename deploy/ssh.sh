#!/usr/bin/env bash
# Quick SSH into EC2
# Usage: bash deploy/ssh.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.deploy"

[[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found."; exit 1; }

declare -A config
while IFS= read -r line; do
    line="$(echo "$line" | xargs)"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"; value="${line#*=}"
    value="${value%%#*}"  # strip inline comments
    config["$(echo "$key" | xargs)"]="$(echo "$value" | xargs)"
done < "$ENV_FILE"

EC2_KEY="${config[EC2_KEY]/#\~/$HOME}"

ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "${config[EC2_USER]}@${config[EC2_HOST]}"
