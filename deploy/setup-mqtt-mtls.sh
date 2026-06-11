#!/usr/bin/env bash
set -euo pipefail

REMOTE_DIR="${1:-$(pwd)}"
SERVER_HOST="${2:-mosquitto}"
PKI_DIR="${3:-$REMOTE_DIR/deploy/mosquitto/pki}"
INVENTORY_FILE="${4:-$REMOTE_DIR/deploy/mqtt-gateways.csv}"
ACL_FILE="${5:-$REMOTE_DIR/deploy/mosquitto/generated/acl.prod.conf}"
IDENTITY_TOOL="$REMOTE_DIR/deploy/mqtt_identity.py"
MOSQUITTO_UID="${MOSQUITTO_UID:-}"
MOSQUITTO_GID="${MOSQUITTO_GID:-}"

for command_name in openssl python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: $command_name is required for MQTT certificate setup."
    exit 1
  fi
done

if [ ! -f "$IDENTITY_TOOL" ]; then
  echo "ERROR: MQTT identity tool not found: $IDENTITY_TOOL"
  exit 1
fi
if [ -z "$MOSQUITTO_UID" ] || [ -z "$MOSQUITTO_GID" ]; then
  echo "ERROR: MOSQUITTO_UID and MOSQUITTO_GID must be resolved from the container image."
  exit 1
fi
if ! [[ "$MOSQUITTO_UID" =~ ^[0-9]+$ && "$MOSQUITTO_GID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MOSQUITTO_UID and MOSQUITTO_GID must be numeric."
  exit 1
fi

umask 077
stage_dir="$(mktemp -d)"
inventory_manifest="$stage_dir/inventory.tsv"
trap 'rm -rf "$stage_dir"' EXIT

# Validate every row, CSR signature, and CSR common name before changing PKI.
python3 "$IDENTITY_TOOL" \
  --inventory "$INVENTORY_FILE" \
  --acl-output "$stage_dir/acl.prod.conf" \
  --list > "$inventory_manifest"

ca_dir="$PKI_DIR/ca"
server_dir="$PKI_DIR/server"
client_dir="$PKI_DIR/clients"
gateway_dir="$PKI_DIR/gateways"
mkdir -p "$ca_dir" "$server_dir" "$client_dir" "$gateway_dir"

ca_key="$ca_dir/ca.key"
ca_crt="$ca_dir/ca.crt"
ca_serial="$stage_dir/ca.srl"
regenerate_dependents=false

if [ -s "$ca_key" ] && [ -s "$ca_crt" ]; then
  effective_ca_key="$ca_key"
  effective_ca_crt="$ca_crt"
  if [ -s "$ca_dir/ca.srl" ]; then
    cp "$ca_dir/ca.srl" "$ca_serial"
  fi
else
  effective_ca_key="$stage_dir/ca.key"
  effective_ca_crt="$stage_dir/ca.crt"
  openssl genrsa -out "$effective_ca_key" 4096 >/dev/null 2>&1
  openssl req -x509 -new -nodes -key "$effective_ca_key" -sha256 -days 3650 \
    -subj "/CN=zigbee-smart-building-mqtt-ca" \
    -out "$effective_ca_crt" >/dev/null 2>&1
  regenerate_dependents=true
fi

server_ext="$stage_dir/server.ext"
{
  echo "[v3_req]"
  echo "basicConstraints = CA:FALSE"
  echo "keyUsage = digitalSignature, keyEncipherment"
  echo "extendedKeyUsage = serverAuth"
  echo "subjectAltName = @alt_names"
  echo "[alt_names]"
  echo "DNS.1 = mosquitto"
  echo "DNS.2 = localhost"
  echo "IP.1 = 127.0.0.1"
  if [[ "$SERVER_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "IP.2 = $SERVER_HOST"
  elif [ -n "$SERVER_HOST" ]; then
    echo "DNS.3 = $SERVER_HOST"
  fi
} > "$server_ext"

client_ext="$stage_dir/client.ext"
{
  echo "[v3_req]"
  echo "basicConstraints = CA:FALSE"
  echo "keyUsage = digitalSignature"
  echo "extendedKeyUsage = clientAuth"
} > "$client_ext"

sign_csr() {
  local csr="$1"
  local certificate="$2"
  local extension_file="$3"
  openssl x509 -req -in "$csr" \
    -CA "$effective_ca_crt" \
    -CAkey "$effective_ca_key" \
    -CAserial "$ca_serial" \
    -CAcreateserial \
    -out "$certificate" \
    -days 825 \
    -sha256 \
    -extfile "$extension_file" \
    -extensions v3_req >/dev/null 2>&1
}

stage_server=false
if $regenerate_dependents || [ ! -s "$server_dir/server.key" ] || [ ! -s "$server_dir/server.crt" ]; then
  openssl genrsa -out "$stage_dir/server.key" 2048 >/dev/null 2>&1
  openssl req -new -key "$stage_dir/server.key" -subj "/CN=mosquitto" \
    -out "$stage_dir/server.csr" >/dev/null 2>&1
  sign_csr "$stage_dir/server.csr" "$stage_dir/server.crt" "$server_ext"
  stage_server=true
fi

stage_client_identity() {
  local principal="$1"
  local current_key="$client_dir/$principal.key"
  local current_crt="$client_dir/$principal.crt"
  if ! $regenerate_dependents && [ -s "$current_key" ] && [ -s "$current_crt" ]; then
    return
  fi

  openssl genrsa -out "$stage_dir/$principal.key" 2048 >/dev/null 2>&1
  openssl req -new -key "$stage_dir/$principal.key" -subj "/CN=$principal" \
    -out "$stage_dir/$principal.csr" >/dev/null 2>&1
  sign_csr "$stage_dir/$principal.csr" "$stage_dir/$principal.crt" "$client_ext"
}

stage_client_identity cloud-control
stage_client_identity monitor

while IFS=$'\t' read -r principal_id tenant_id site_id gateway_id csr_path; do
  csr_path="${csr_path%$'\r'}"
  if [ -z "$principal_id" ]; then
    continue
  fi
  sign_csr "$csr_path" "$stage_dir/$principal_id.crt" "$client_ext"
done < "$inventory_manifest"

set_mosquitto_owner() {
  local path="$1"
  if chown "$MOSQUITTO_UID:$MOSQUITTO_GID" "$path" 2>/dev/null; then
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo chown "$MOSQUITTO_UID:$MOSQUITTO_GID" "$path"
    return
  fi
  echo "ERROR: cannot assign Mosquitto ownership to $path"
  exit 1
}

chmod 0600 "$effective_ca_key"
if $stage_server; then
  chmod 0640 "$stage_dir/server.key"
  set_mosquitto_owner "$stage_dir/server.key"
fi
if [ -s "$stage_dir/cloud-control.key" ]; then
  chmod 0600 "$stage_dir/cloud-control.key"
fi
if [ -s "$stage_dir/monitor.key" ]; then
  chmod 0640 "$stage_dir/monitor.key"
  set_mosquitto_owner "$stage_dir/monitor.key"
fi
chmod 0644 "$effective_ca_crt" "$stage_dir/acl.prod.conf"
find "$stage_dir" -maxdepth 1 -type f -name '*.crt' -exec chmod 0644 {} +

if $regenerate_dependents; then
  mv -f "$stage_dir/ca.key" "$ca_key"
  mv -f "$stage_dir/ca.crt" "$ca_crt"
fi
if $stage_server; then
  mv -f "$stage_dir/server.key" "$server_dir/server.key"
  mv -f "$stage_dir/server.crt" "$server_dir/server.crt"
fi
for principal in cloud-control monitor; do
  if [ -s "$stage_dir/$principal.key" ]; then
    mv -f "$stage_dir/$principal.key" "$client_dir/$principal.key"
    mv -f "$stage_dir/$principal.crt" "$client_dir/$principal.crt"
  fi
done
while IFS=$'\t' read -r principal_id tenant_id site_id gateway_id csr_path; do
  csr_path="${csr_path%$'\r'}"
  if [ -n "$principal_id" ]; then
    mv -f "$stage_dir/$principal_id.crt" "$gateway_dir/$principal_id.crt"
  fi
done < "$inventory_manifest"
if [ -s "$ca_serial" ]; then
  mv -f "$ca_serial" "$ca_dir/ca.srl"
fi
mkdir -p "$(dirname "$ACL_FILE")"
mv -f "$stage_dir/acl.prod.conf" "$ACL_FILE"

chmod 0700 "$ca_dir"
chmod 0750 "$server_dir" "$client_dir"
chmod 0755 "$gateway_dir" "$(dirname "$ACL_FILE")"
chmod 0600 "$ca_key" "$client_dir/cloud-control.key"
chmod 0640 "$server_dir/server.key" "$client_dir/monitor.key"
set_mosquitto_owner "$server_dir/server.key"
set_mosquitto_owner "$client_dir/monitor.key"
chmod 0644 "$ca_crt" "$server_dir/server.crt" "$client_dir"/*.crt "$gateway_dir"/*.crt "$ACL_FILE"

echo "MQTT certificate identities and exact ACL are ready."
echo "Gateway certificates: $gateway_dir"
echo "Production ACL: $ACL_FILE"
