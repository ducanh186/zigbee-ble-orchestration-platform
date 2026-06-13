#!/usr/bin/env bash
# Start the Z3Gateway host connected to the EC2 PRODUCTION cloud broker over
# mTLS (8883) instead of the local broker.
#
# This is the persistent counterpart to scripts/start-gateway.sh (which targets
# localhost:1883). It exports the cloud MQTT + mTLS env, stops any running
# gateway, frees /dev/ttyACM0, then delegates to start-gateway.sh so the
# stdin/pidfile/launch logic stays in one place.
#
# Certs: the repo's mqtt/certs are signed by the SAME CA the prod broker trusts
# (verified), and the prod broker uses use_identity_as_username=false, so the
# gateway authenticates by client cert (CA-signed) + username/password
# (ACL user "gateway"). See memory project_gateway_cloud_connect.
#
# Override any value via env, e.g. SB_GATEWAY_ID=... scripts/start-gateway-cloud.sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERTS="$REPO_ROOT/mqtt/certs"
UART="${UART:-/dev/ttyACM0}"
PIDFILE="${PIDFILE:-/tmp/z3gw.pid}"

# --- Cloud broker (EC2 prod) over mTLS ---
export SB_MQTT_HOST="${SB_MQTT_HOST:-98.83.4.87}"
export SB_MQTT_PORT="${SB_MQTT_PORT:-8883}"
export SB_MQTT_USERNAME="${SB_MQTT_USERNAME:-gateway}"
export SB_MQTT_PASSWORD="${SB_MQTT_PASSWORD:-gateway123}"
export SB_MQTT_TLS_ENABLED=1
export SB_MQTT_MTLS_ENABLED=1
export SB_MQTT_CA_CERT_PATH="${SB_MQTT_CA_CERT_PATH:-$CERTS/ca.crt}"
export SB_MQTT_CLIENT_CERT_PATH="${SB_MQTT_CLIENT_CERT_PATH:-$CERTS/clients/gateway.crt}"
export SB_MQTT_CLIENT_KEY_PATH="${SB_MQTT_CLIENT_KEY_PATH:-$CERTS/clients/gateway.key}"

# --- Namespace identity (topic prefix + ACL) ---
export SB_TENANT_ID="${SB_TENANT_ID:-hust}"
export SB_SITE_ID="${SB_SITE_ID:-lab01}"
export SB_GATEWAY_ID="${SB_GATEWAY_ID:-gw-ubuntu-01}"

# Sanity: certs must exist before we try a TLS connect.
for f in "$SB_MQTT_CA_CERT_PATH" "$SB_MQTT_CLIENT_CERT_PATH" "$SB_MQTT_CLIENT_KEY_PATH"; do
  if [ ! -r "$f" ]; then
    echo "ERROR: missing/unreadable cert: $f" >&2
    exit 1
  fi
done

# Stop any running gateway and wait for the UART to be released so start-gateway.sh
# does not bail on "UART held".
kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null || true
n=0
while fuser "$UART" >/dev/null 2>&1; do
  sleep 1
  n=$((n + 1))
  [ "$n" -gt 30 ] && break
done

echo "Starting gateway -> cloud ${SB_MQTT_HOST}:${SB_MQTT_PORT} (mTLS) as ${SB_TENANT_ID}/${SB_SITE_ID}/${SB_GATEWAY_ID}"
exec "$REPO_ROOT/scripts/start-gateway.sh"
