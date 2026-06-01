#!/usr/bin/env bash
# Prepare HTTPS for the EC2 deployment.
#
# Usage:
#   bash deploy/setup-https.sh <https-host-or-ip> <remote-project-dir>
#
# For a public IP address, this uses Let's Encrypt IP address certificates:
#   certbot certonly --standalone --preferred-profile shortlived --ip-address <ip>
#
# Certbot currently obtains IP certificates but does not install them into nginx,
# so this script renders deploy/nginx/prod.conf and mounts /etc/letsencrypt into
# the nginx container via docker-compose.prod.yml.
set -euo pipefail

HTTPS_HOST="${1:?https host or IP is required}"
REMOTE_DIR="${2:?remote project directory is required}"
DEPLOY_DIR="$REMOTE_DIR/deploy"
LE_DIR="$DEPLOY_DIR/nginx/letsencrypt"
NGINX_CONF="$DEPLOY_DIR/nginx/prod.conf"

cd "$DEPLOY_DIR"
mkdir -p "$LE_DIR"

is_ip_address() {
  local value="$1"
  [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$value" == *:* ]]
}

render_nginx_config() {
  if grep -q '<HTTPS_HOST>' "$NGINX_CONF"; then
    sed "s|<HTTPS_HOST>|$HTTPS_HOST|g" "$NGINX_CONF" > "$NGINX_CONF.rendered"
    mv "$NGINX_CONF.rendered" "$NGINX_CONF"
  fi
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

prepare_certificate
render_nginx_config
install_renew_timer

echo "HTTPS prepared for $HTTPS_HOST."
