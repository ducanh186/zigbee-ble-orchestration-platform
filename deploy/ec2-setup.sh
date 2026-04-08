#!/usr/bin/env bash
# ============================================================
# EC2 First-Time Setup (run from Linux)
# Installs Docker, Docker Compose on the EC2 instance.
#
# Usage:
#   bash deploy/ec2-setup.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.deploy"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found."
    exit 1
fi

declare -A config
while IFS= read -r line; do
    line="$(echo "$line" | xargs)"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    value="${value%%#*}"  # strip inline comments
    config["$(echo "$key" | xargs)"]="$(echo "$value" | xargs)"
done < "$ENV_FILE"

EC2_HOST="${config[EC2_HOST]}"
EC2_USER="${config[EC2_USER]}"
EC2_KEY="${config[EC2_KEY]/#\~/$HOME}"
REMOTE="$EC2_USER@$EC2_HOST"
SSH_OPTS=(-i "$EC2_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

echo "=== Setting up EC2 at $EC2_HOST ==="

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<'SETUP_EOF'
set -euo pipefail

echo "=== [1/3] Updating system ==="
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

echo "=== [2/3] Installing Docker ==="
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "Docker installed. Re-login needed for group."
else
    echo "Docker already installed."
fi

echo "=== [3/3] Checking Docker Compose ==="
if docker compose version &>/dev/null; then
    echo "Docker Compose plugin found: $(docker compose version)"
elif docker-compose version &>/dev/null; then
    echo "Docker Compose standalone found: $(docker-compose version)"
else
    echo "Installing Docker Compose plugin..."
    sudo apt-get install -y -qq docker-compose-plugin || {
        echo "WARNING: Could not install docker-compose-plugin. Install manually."
    }
fi

echo ""
echo "Make sure AWS Security Group allows inbound:"
echo "  - 22   (SSH)"
echo "  - 1883 (MQTT)"
echo "  - 8000 (API)"
echo "  - 9001 (MQTT WebSocket)"
echo ""
echo "=== EC2 Setup Complete ==="
echo "Log out and back in, then run deploy.sh"
SETUP_EOF

echo ""
echo "EC2 setup done! Now run: bash deploy/deploy.sh"
