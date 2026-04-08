#!/usr/bin/env bash
# Run seed script on EC2
# Usage: bash deploy/seed-remote.sh
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
SSH_OPTS=(-i "$EC2_KEY" -o StrictHostKeyChecking=no)
REMOTE="${config[EC2_USER]}@${config[EC2_HOST]}"

echo "Running seed on EC2..."
ssh "${SSH_OPTS[@]}" "$REMOTE" "docker exec sb-cloud-api python -m cloud.app.seed"
echo "Seed complete."
