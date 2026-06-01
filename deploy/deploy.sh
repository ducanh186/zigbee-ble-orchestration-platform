#!/usr/bin/env bash
# ============================================================
# Auto-Deploy to EC2 from Linux
#
# Usage:
#   cp deploy/.env.deploy.example deploy/.env.deploy
#   # edit deploy/.env.deploy
#   bash deploy/deploy.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ----------------------------------------------------------
# Load config
# ----------------------------------------------------------
ENV_FILE="$SCRIPT_DIR/.env.deploy"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found."
    echo "  cp deploy/.env.deploy.example deploy/.env.deploy"
    echo "  # then fill in your EC2 details"
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
REMOTE_DIR="${config[REMOTE_DIR]}"
REMOTE="$EC2_USER@$EC2_HOST"
SSH_OPTS=(-i "$EC2_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

for var in EC2_HOST EC2_USER EC2_KEY REMOTE_DIR; do
    if [[ -z "${config[$var]:-}" ]]; then
        echo "ERROR: $var is not set in .env.deploy"
        exit 1
    fi
done

echo ""
echo "=== Deploying to $EC2_HOST ($REMOTE_DIR) ==="

# ----------------------------------------------------------
# Step 1: Pack project files
# ----------------------------------------------------------
echo ""
echo "--- [1/6] Packing project files ---"

TEMP_TAR="$(mktemp /tmp/iot-platform-deploy.XXXXXX.tar.gz)"

tar -czf "$TEMP_TAR" -C "$PROJECT_DIR" \
    --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.env' \
    --exclude='.env.deploy' \
    --exclude='cloud.db' \
    --exclude='releases' \
    --exclude='ota-files' \
    --exclude='node_modules' \
    --exclude='.claude' \
    --exclude='mqtt/passwords' \
    --exclude='mqtt/data' \
    .

echo "Packed project: $(du -k "$TEMP_TAR" | cut -f1) KB"

# ----------------------------------------------------------
# Step 2: Upload to EC2
# ----------------------------------------------------------
echo ""
echo "--- [2/6] Uploading to EC2 ---"

ssh "${SSH_OPTS[@]}" "$REMOTE" "mkdir -p $REMOTE_DIR"
scp "${SSH_OPTS[@]}" "$TEMP_TAR" "$REMOTE:$REMOTE_DIR/deploy-payload.tar.gz"

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<REMOTE_EOF
set -e
cd $REMOTE_DIR
tar -xzf deploy-payload.tar.gz
rm -f deploy-payload.tar.gz
echo 'Files extracted.'
REMOTE_EOF

rm -f "$TEMP_TAR"
echo "Files uploaded and extracted."

# ----------------------------------------------------------
# Step 3: Prepare directory structure
# ----------------------------------------------------------
echo ""
echo "--- [3/6] Preparing remote directories ---"

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<REMOTE_EOF
set -e
cd $REMOTE_DIR
mkdir -p deploy/mosquitto/config
mkdir -p deploy/mosquitto/passwords
mkdir -p deploy/cloud
cp -f mqtt/config/acl.conf deploy/mosquitto/config/
# Copy mosquitto.conf but remove include_dir (EC2 broker has no conf.d/ bridge config)
sed '/^include_dir/d' mqtt/config/mosquitto.conf > deploy/mosquitto/config/mosquitto.conf
echo 'Directories prepared.'
REMOTE_EOF

# ----------------------------------------------------------
# Step 4: Generate MQTT passwords (4 users)
# ----------------------------------------------------------
echo ""
echo "--- [4/6] Generating MQTT passwords ---"

GW_PASS="${config[MQTT_GATEWAY_PASS]:-gateway123}"
CLI_PASS="${config[MQTT_CLIENT_PASS]:-client123}"
MON_PASS="${config[MQTT_MONITOR_PASS]:-monitor123}"
BRIDGE_PASS="${config[MQTT_BRIDGE_PASS]:-bridge123}"

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<REMOTE_EOF
set -e
cd $REMOTE_DIR
PASSDIR=\$(pwd)/deploy/mosquitto/passwords
docker run --rm -v "\$PASSDIR:/passwords" eclipse-mosquitto:2.0 sh -c "
  touch /passwords/passwd
  mosquitto_passwd -b /passwords/passwd gateway '$GW_PASS'
  mosquitto_passwd -b /passwords/passwd client  '$CLI_PASS'
  mosquitto_passwd -b /passwords/passwd monitor '$MON_PASS'
  mosquitto_passwd -b /passwords/passwd bridge  '$BRIDGE_PASS'
"
echo 'MQTT passwords generated (4 users: gateway, client, monitor, bridge).'
REMOTE_EOF

# ----------------------------------------------------------
# Step 5: Write cloud .env
# ----------------------------------------------------------
echo ""
echo "--- [5/6] Writing cloud .env on EC2 ---"

PG_USER="${config[POSTGRES_USER]:-sb_user}"
PG_PASS="${config[POSTGRES_PASSWORD]:-sb_pass}"
PG_DB="${config[POSTGRES_DB]:-sb_cloud}"
SB_DB_URL="${config[SB_DATABASE_URL]:-postgresql+asyncpg://$PG_USER:$PG_PASS@postgres:5432/$PG_DB}"
SB_MQTT_HOST="${config[SB_MQTT_HOST]:-mosquitto}"
SB_MQTT_USER="${config[SB_MQTT_USERNAME]:-client}"
SB_MQTT_PASS="${config[SB_MQTT_PASSWORD]:-client123}"
SB_TENANT="${config[SB_TENANT_ID]:-hust}"
SB_SITE="${config[SB_SITE_ID]:-lab01}"
SB_GW="${config[SB_GATEWAY_ID]:-gw-ubuntu-01}"
SB_AUTH_SECRET="${config[SB_AUTH_TOKEN_SECRET]:-}"

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<REMOTE_EOF
set -e
AUTH_SECRET='$SB_AUTH_SECRET'
if [ -z "\$AUTH_SECRET" ]; then
  AUTH_SECRET=\$(grep -s '^SB_AUTH_TOKEN_SECRET=' "$REMOTE_DIR/deploy/cloud/.env" | tail -n1 | cut -d= -f2- || true)
fi
if [ -z "\$AUTH_SECRET" ] || [ "\$AUTH_SECRET" = "dev-only-change-me" ]; then
  if command -v python3 >/dev/null 2>&1; then
    AUTH_SECRET=\$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
  else
    AUTH_SECRET=\$(openssl rand -hex 48)
  fi
fi
cat > $REMOTE_DIR/deploy/cloud/.env << 'ENVEOF'
SB_DATABASE_URL=$SB_DB_URL
SB_MQTT_HOST=$SB_MQTT_HOST
SB_MQTT_PORT=1883
SB_MQTT_USERNAME=$SB_MQTT_USER
SB_MQTT_PASSWORD=$SB_MQTT_PASS
SB_TENANT_ID=$SB_TENANT
SB_SITE_ID=$SB_SITE
SB_GATEWAY_ID=$SB_GW
SB_API_HOST=0.0.0.0
SB_API_PORT=8000
ENVEOF
printf 'SB_AUTH_TOKEN_SECRET=%s\n' "\$AUTH_SECRET" >> $REMOTE_DIR/deploy/cloud/.env
echo 'cloud/.env written.'
REMOTE_EOF

# ----------------------------------------------------------
# Step 6: Prepare HTTPS certificate
# ----------------------------------------------------------
echo ""
echo "--- [6/7] Preparing HTTPS certificate ---"

HTTPS_HOST="${config[HTTPS_HOST]:-$EC2_HOST}"

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<REMOTE_EOF
set -e
cd $REMOTE_DIR
bash deploy/setup-https.sh '$HTTPS_HOST' '$REMOTE_DIR'
REMOTE_EOF

# ----------------------------------------------------------
# Step 7: Docker compose up
# ----------------------------------------------------------
echo ""
echo "--- [7/7] Building and starting containers ---"

ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s <<REMOTE_EOF
set -e
cd $REMOTE_DIR/deploy

# Copy cloud source into deploy context for Docker build
rm -rf cloud/app cloud/webdev cloud/requirements.txt cloud/Dockerfile cloud/__init__.py cloud/__main__.py 2>/dev/null || true
cp -r ../cloud/app         cloud/
cp -r ../cloud/webdev      cloud/
cp    ../cloud/requirements.txt cloud/
cp    ../cloud/Dockerfile  cloud/
cp    ../cloud/__init__.py cloud/
cp    ../cloud/__main__.py cloud/

# Export PostgreSQL credentials for docker-compose interpolation
export POSTGRES_USER='$PG_USER'
export POSTGRES_PASSWORD='$PG_PASS'
export POSTGRES_DB='$PG_DB'

# Detect compose command (plugin vs standalone)
if docker compose version &>/dev/null; then
    DC="docker compose"
elif docker-compose version &>/dev/null; then
    DC="docker-compose"
else
    echo "ERROR: Neither 'docker compose' nor 'docker-compose' found."
    exit 1
fi

# Stop and remove any existing containers (handles name conflicts from previous deploys)
for ctr in sb-mosquitto sb-postgres sb-cloud-api; do
    docker rm -f "\$ctr" 2>/dev/null || true
done

# Build and start
\$DC -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
\$DC -f docker-compose.prod.yml up --build -d

echo ''
echo 'Waiting for services to start...'
sleep 10

\$DC -f docker-compose.prod.yml ps

echo ''
if curl -sf http://localhost:8000/health; then
    echo ''
    echo 'API is healthy!'
else
    echo 'WARNING: API not responding yet. Check logs with:'
    echo "  \$DC -f docker-compose.prod.yml logs cloud-api"
fi
REMOTE_EOF

echo ""
echo "========================================="
echo "  Deploy complete!"
echo "  API HTTPS: https://$HTTPS_HOST"
echo "  API Swagger: http://$EC2_HOST:8000/docs"
echo "  MQTT Broker: $EC2_HOST:1883"
echo "========================================="
