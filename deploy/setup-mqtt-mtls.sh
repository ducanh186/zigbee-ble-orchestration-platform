#!/usr/bin/env bash
set -euo pipefail

REMOTE_DIR="${1:-$(pwd)}"
SERVER_HOST="${2:-mosquitto}"
CERT_DIR="${3:-$REMOTE_DIR/mqtt/certs}"
CLIENT_DIR="$CERT_DIR/clients"

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required to generate MQTT mTLS certificates."
  exit 1
fi

mkdir -p "$CLIENT_DIR"

CA_KEY="$CERT_DIR/ca.key"
CA_CRT="$CERT_DIR/ca.crt"
SERVER_KEY="$CERT_DIR/server.key"
SERVER_CRT="$CERT_DIR/server.crt"
SERVER_CSR="$CERT_DIR/server.csr"

if [ ! -s "$CA_KEY" ] || [ ! -s "$CA_CRT" ]; then
  openssl genrsa -out "$CA_KEY" 4096 >/dev/null 2>&1
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 \
    -subj "/CN=zigbee-smart-building-mqtt-ca" \
    -out "$CA_CRT" >/dev/null 2>&1
  echo "Generated MQTT CA certificate."
else
  echo "MQTT CA certificate already exists."
fi

server_ext="$(mktemp)"
trap 'rm -f "$server_ext" "$CERT_DIR"/*.csr "$CLIENT_DIR"/*.csr' EXIT

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

if [ ! -s "$SERVER_KEY" ] || [ ! -s "$SERVER_CRT" ]; then
  openssl genrsa -out "$SERVER_KEY" 2048 >/dev/null 2>&1
  openssl req -new -key "$SERVER_KEY" -subj "/CN=mosquitto" \
    -out "$SERVER_CSR" >/dev/null 2>&1
  openssl x509 -req -in "$SERVER_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$SERVER_CRT" -days 825 -sha256 \
    -extfile "$server_ext" -extensions v3_req >/dev/null 2>&1
  echo "Generated MQTT server certificate."
else
  echo "MQTT server certificate already exists."
fi

generate_client_cert() {
  local name="$1"
  local key="$CLIENT_DIR/$name.key"
  local csr="$CLIENT_DIR/$name.csr"
  local crt="$CLIENT_DIR/$name.crt"
  local ext
  ext="$(mktemp)"
  {
    echo "[v3_req]"
    echo "basicConstraints = CA:FALSE"
    echo "keyUsage = digitalSignature"
    echo "extendedKeyUsage = clientAuth"
  } > "$ext"

  if [ ! -s "$key" ] || [ ! -s "$crt" ]; then
    openssl genrsa -out "$key" 2048 >/dev/null 2>&1
    openssl req -new -key "$key" -subj "/CN=$name" \
      -out "$csr" >/dev/null 2>&1
    openssl x509 -req -in "$csr" -CA "$CA_CRT" -CAkey "$CA_KEY" \
      -CAcreateserial -out "$crt" -days 825 -sha256 \
      -extfile "$ext" -extensions v3_req >/dev/null 2>&1
    echo "Generated MQTT client certificate: $name"
  else
    echo "MQTT client certificate already exists: $name"
  fi
  rm -f "$ext" "$csr"
}

generate_client_cert cloud
generate_client_cert gateway
generate_client_cert monitor

chmod 755 "$CERT_DIR" "$CLIENT_DIR"
chmod 644 "$CERT_DIR"/*.crt "$CERT_DIR"/*.key "$CLIENT_DIR"/*.crt "$CLIENT_DIR"/*.key
rm -f "$CERT_DIR"/*.csr "$CLIENT_DIR"/*.csr

echo "MQTT mTLS certificates ready in $CERT_DIR."
