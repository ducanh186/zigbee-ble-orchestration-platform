#!/usr/bin/env bash
# Prepare HTTPS for the EC2 deployment.
#
# Usage:
#   bash deploy/setup-https.sh <https-host-or-ip> <remote-project-dir>
#
# HTTPS_CERT_MODE=letsencrypt keeps the previous Certbot flow.
# HTTPS_CERT_MODE=cloudflare-origin expects a Cloudflare Origin CA cert/key in
# deploy/nginx/certs and disables the obsolete Let's Encrypt renewal timer.
set -euo pipefail

HTTPS_HOST="${1:?https host or IP is required}"
REMOTE_DIR="${2:?remote project directory is required}"
HTTPS_CERT_MODE="${HTTPS_CERT_MODE:-letsencrypt}"
DEPLOY_DIR="$REMOTE_DIR/deploy"
LE_DIR="$DEPLOY_DIR/nginx/letsencrypt"
ORIGIN_CERT_DIR="$DEPLOY_DIR/nginx/certs"
ORIGIN_CERT_PATH="$ORIGIN_CERT_DIR/cloudflare-origin.pem"
ORIGIN_KEY_PATH="$ORIGIN_CERT_DIR/cloudflare-origin.key"
NGINX_CONF="$DEPLOY_DIR/nginx/prod.conf"

cd "$DEPLOY_DIR"
mkdir -p "$LE_DIR" "$ORIGIN_CERT_DIR"

is_ip_address() {
  local value="$1"
  [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$value" == *:* ]]
}

render_nginx_config() {
  local cert_path="$1"
  local key_path="$2"
  sed \
    -e "s|<HTTPS_HOST>|$HTTPS_HOST|g" \
    -e "s|<SSL_CERTIFICATE_PATH>|$cert_path|g" \
    -e "s|<SSL_CERTIFICATE_KEY_PATH>|$key_path|g" \
    "$NGINX_CONF" > "$NGINX_CONF.rendered"
  mv "$NGINX_CONF.rendered" "$NGINX_CONF"
}

request_certificate() {
  local cert_path="$LE_DIR/live/$HTTPS_HOST/fullchain.pem"
  if [[ -s "$cert_path" ]]; then
    echo "HTTPS certificate already exists for $HTTPS_HOST."
    return 0
  fi

  docker rm -f sb-nginx >/dev/null 2>&1 || true

  local identifier_args=()
  if is_ip_address "$HTTPS_HOST"; then
    identifier_args=(--preferred-profile shortlived --ip-address "$HTTPS_HOST")
  else
    identifier_args=(-d "$HTTPS_HOST")
  fi

  docker run --rm \
    -p 80:80 \
    -v "$LE_DIR:/etc/letsencrypt" \
    certbot/certbot:latest \
    certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    "${identifier_args[@]}"
}

generate_self_signed_certificate() {
  local live_dir="$LE_DIR/live/$HTTPS_HOST"
  local fullchain_path="$live_dir/fullchain.pem"
  local privkey_path="$live_dir/privkey.pem"
  local cert_path="$live_dir/cert.pem"
  local openssl_cfg
  openssl_cfg="$(mktemp)"

  mkdir -p "$live_dir"
  {
    echo "[req]"
    echo "distinguished_name = req_distinguished_name"
    echo "x509_extensions = v3_req"
    echo "prompt = no"
    echo "[req_distinguished_name]"
    echo "CN = $HTTPS_HOST"
    echo "[v3_req]"
    echo "basicConstraints = CA:FALSE"
    echo "keyUsage = digitalSignature, keyEncipherment"
    echo "extendedKeyUsage = serverAuth"
    if is_ip_address "$HTTPS_HOST"; then
      echo "subjectAltName = IP:$HTTPS_HOST"
    else
      echo "subjectAltName = DNS:$HTTPS_HOST"
    fi
  } > "$openssl_cfg"

  openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 30 \
    -keyout "$privkey_path" \
    -out "$fullchain_path" \
    -config "$openssl_cfg"
  cp "$fullchain_path" "$cert_path"
  rm -f "$openssl_cfg"
  echo "Generated temporary self-signed HTTPS certificate for $HTTPS_HOST."
}

prepare_certificate() {
  if request_certificate; then
    return 0
  fi

  echo "WARNING: Let's Encrypt certificate request failed; using temporary self-signed HTTPS certificate."
  generate_self_signed_certificate
}

install_renew_timer() {
  local renew_script="/usr/local/bin/iot-platform-renew-ip-cert.sh"

  sudo tee "$renew_script" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

REMOTE_DIR='$REMOTE_DIR'
DEPLOY_DIR="\$REMOTE_DIR/deploy"
LE_DIR="\$DEPLOY_DIR/nginx/letsencrypt"

cd "\$DEPLOY_DIR"

nginx_was_running=0
if docker ps --format '{{.Names}}' | grep -qx 'sb-nginx'; then
  docker stop sb-nginx >/dev/null
  nginx_was_running=1
fi

restart_nginx() {
  if [[ "\$nginx_was_running" == "1" ]]; then
    docker start sb-nginx >/dev/null || true
  fi
}
trap restart_nginx EXIT

docker run --rm \
  -p 80:80 \
  -v "\$LE_DIR:/etc/letsencrypt" \
  certbot/certbot:latest renew --quiet
EOF

  sudo chmod 0755 "$renew_script"

  sudo tee /etc/systemd/system/iot-platform-renew-ip-cert.service >/dev/null <<EOF
[Unit]
Description=Renew IoT Platform Let's Encrypt IP certificate

[Service]
Type=oneshot
ExecStart=$renew_script
EOF

  sudo tee /etc/systemd/system/iot-platform-renew-ip-cert.timer >/dev/null <<'EOF'
[Unit]
Description=Daily renewal check for IoT Platform IP certificate

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now iot-platform-renew-ip-cert.timer >/dev/null
}

remove_renew_timer() {
  sudo systemctl disable --now iot-platform-renew-ip-cert.timer >/dev/null 2>&1 || true
  sudo rm -f \
    /etc/systemd/system/iot-platform-renew-ip-cert.timer \
    /etc/systemd/system/iot-platform-renew-ip-cert.service \
    /usr/local/bin/iot-platform-renew-ip-cert.sh
  sudo systemctl daemon-reload
}

prepare_cloudflare_origin_certificate() {
  if [[ ! -s "$ORIGIN_CERT_PATH" || ! -s "$ORIGIN_KEY_PATH" ]]; then
    echo "ERROR: Cloudflare Origin CA cert/key are required for HTTPS_CERT_MODE=cloudflare-origin." >&2
    echo "Expected:" >&2
    echo "  $ORIGIN_CERT_PATH" >&2
    echo "  $ORIGIN_KEY_PATH" >&2
    exit 1
  fi
  chmod 0644 "$ORIGIN_CERT_PATH"
  chmod 0600 "$ORIGIN_KEY_PATH"
  remove_renew_timer
}

case "$HTTPS_CERT_MODE" in
  letsencrypt)
    prepare_certificate
    render_nginx_config \
      "/etc/letsencrypt/live/$HTTPS_HOST/fullchain.pem" \
      "/etc/letsencrypt/live/$HTTPS_HOST/privkey.pem"
    install_renew_timer
    ;;
  cloudflare-origin)
    prepare_cloudflare_origin_certificate
    render_nginx_config \
      "/etc/nginx/certs/cloudflare-origin.pem" \
      "/etc/nginx/certs/cloudflare-origin.key"
    ;;
  *)
    echo "ERROR: Unsupported HTTPS_CERT_MODE: $HTTPS_CERT_MODE" >&2
    exit 1
    ;;
esac

echo "HTTPS prepared for $HTTPS_HOST using $HTTPS_CERT_MODE."
