#!/usr/bin/env bash
# View logs from EC2 containers
# Usage: bash deploy/logs.sh [cloud-api|mosquitto|postgres]
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
REMOTE_DIR="${config[REMOTE_DIR]}"
SERVICE="${1:-}"

ssh "${SSH_OPTS[@]}" "$REMOTE" "cd $REMOTE_DIR/deploy && if docker compose version &>/dev/null; then docker compose -f docker-compose.prod.yml logs -f --tail=100 $SERVICE; else docker-compose -f docker-compose.prod.yml logs -f --tail=100 $SERVICE; fi"
