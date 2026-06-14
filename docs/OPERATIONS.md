# Operations

This guide covers local run, production deployment, MQTT TLS, networking, and common troubleshooting. It avoids secrets by design. Use examples as shapes, not as production credentials.

## Local Cloud Run

```powershell
cd cloud
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn cloud.app.main:app --reload --host 0.0.0.0 --port 8000
```

Useful environment variables:

| Variable | Purpose |
|---|---|
| `SB_DATABASE_URL` | SQLAlchemy async PostgreSQL URL. |
| `SB_MQTT_HOST`, `SB_MQTT_PORT` | MQTT broker address. |
| `SB_MQTT_USERNAME`, `SB_MQTT_PASSWORD` | Local-development MQTT credentials. Not used in production certificate-identity mode. |
| `SB_MQTT_CERT_IDENTITY_ENABLED` | Skips password authentication and requires TLS plus mTLS certificate paths. |
| `SB_MQTT_TLS_ENABLED` | Enables MQTT TLS for Cloud. |
| `SB_MQTT_MTLS_ENABLED` | Requires Cloud client certificate and key. |
| `SB_MQTT_CA_CERT_PATH` | Broker CA certificate path. |
| `SB_MQTT_CLIENT_CERT_PATH`, `SB_MQTT_CLIENT_KEY_PATH` | Cloud MQTT client certificate and key. |

Cloud starts even if MQTT connection fails, but live command and device flows will not work until MQTT is reachable.

## Gateway Run

The standard run mode connects the Z3Gateway host directly to the **EC2 production broker** (`98.83.4.87:8883`) over TLS + mTLS, so cloud-issued commands — including schedule automations — reach the gateway:

```bash
bash scripts/start-gateway-cloud.sh
```

This exports the cloud MQTT + mTLS env (CA + client cert/key under `mqtt/certs`, signed by the production CA; ACL user `gateway`), stops any running gateway, frees `/dev/ttyACM0`, and launches against `98.83.4.87:8883` under the `hust/lab01/gw-ubuntu-01` topic prefix. Confirm `/tmp/z3gw.log` shows `MQTT: connected` to `98.83.4.87:8883` and `MQTT: subscribed …/commands/+/request`.

`scripts/start-gateway.sh` (localhost:1883) is retained only for offline local-dev when the cloud broker is unavailable; it is not the standard path. Because the dashboard and cloud also default to EC2, keeping the gateway on EC2 means all three share one broker.

## Local Mobile Run

```powershell
cd mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

For a real remote API, use HTTPS and pass an auth token:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://api.example.com `
  --dart-define=API_AUTH_TOKEN=<token>
```

Release builds should not use remote plaintext HTTP. Debug and profile builds can be less strict for local development, but do not treat that as production behavior.

## Production Deploy

1. Copy `deploy/.env.deploy.example` to `deploy/.env.deploy`.
2. Copy `deploy/mqtt-gateways.example.csv` to `deploy/mqtt-gateways.csv`.
3. Add one inventory row and Gateway-generated CSR for every production Gateway.
4. Fill EC2, database, Cloud namespace, and initial login values.
5. Keep private keys, the real inventory, CSRs, generated ACLs, certificates, and `.env.deploy` out of Git.
6. Run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
```

The deploy script validates every inventory row and CSR before changing production PKI. It signs Gateway CSRs, generates the broker, `cloud-control`, and `monitor` certificates, writes an exact ACL atomically, writes Cloud environment values, and starts the production Docker Compose stack. Existing legacy password material is left in place for rollback, but it is not regenerated or mounted.

## Production Services

The production compose files run:

- Nginx in front of Cloud.
- FastAPI Cloud on port 8000 inside the stack.
- PostgreSQL 16.
- Mosquitto on TLS port 8883.
- Volumes for PostgreSQL and Mosquitto data, plus narrow read-only certificate mounts.

`deploy/docker-compose.prod-secure.yml` is stricter about required environment variables. Prefer it when moving beyond demo use.

## MQTT TLS And mTLS

Production Mosquitto uses:

- TLS server certificate and key.
- CA file.
- `require_certificate true`.
- `use_identity_as_username true`.
- A generated ACL with exact tenant/site/gateway prefixes.

The certificate common name is the MQTT principal. `cloud-control` has exact read/write rules for every inventory namespace. Each Gateway principal can access only its own namespace. `monitor` can read only `$SYS/#`. A valid but unknown certificate common name receives no topic permissions.

## Gateway Certificate Readiness

Gateway C code is not changed by this hardening branch. Production cutover is blocked until Gateway owners complete these requirements:

The implementation handoff for the Gateway team is
[`MQTT_GATEWAY_CERT_IDENTITY_HANDOFF.md`](handoffs/MQTT_GATEWAY_CERT_IDENTITY_HANDOFF.md).

- Generate a private key locally with mode `0600`; never send that key to Cloud or the deployment host.
- Generate a CSR whose common name exactly equals the inventory `principal_id`.
- Install the returned Gateway certificate and CA certificate.
- Add `SB_MQTT_CERT_IDENTITY_ENABLED=true` and `SB_MQTT_PRINCIPAL_ID=<principal_id>`.
- Stop requiring `SB_MQTT_USERNAME` and `SB_MQTT_PASSWORD` when certificate identity is enabled.
- Replace the fixed `z3gw-host` client id with a unique client id derived from `principal_id`.
- Continue requiring TLS, mTLS, CA, certificate, key, tenant, site, and gateway values in production.
- Preserve all existing topic suffixes and message payloads.

Example key and CSR creation on a Gateway:

```bash
install -d -m 0700 /etc/sb-gateway/mqtt
openssl genrsa -out /etc/sb-gateway/mqtt/gateway.key 2048
chmod 0600 /etc/sb-gateway/mqtt/gateway.key
openssl req -new \
  -key /etc/sb-gateway/mqtt/gateway.key \
  -out /etc/sb-gateway/mqtt/gateway.csr \
  -subj "/CN=gateway-hust-lab01-01"
```

Before cutover, verify the returned certificate:

```bash
openssl verify -CAfile ca.crt gateway.crt
openssl x509 -in gateway.crt -noout -subject -issuer -dates
```

Readiness means all inventory CSRs validate, every certificate CN matches its principal, every Gateway has its local key/certificate/CA installed, and the Gateway build no longer depends on MQTT passwords in certificate mode.

## MQTT Cutover And Smoke Tests

Use a coordinated short-downtime cutover:

1. Back up the previous Mosquitto config, ACL, compose file, password file, and Gateway environment.
2. Generate and distribute all signed Gateway certificates before stopping services.
3. Stop Gateway clients and the production stack.
4. Deploy the generated ACL, certificate-only compose configuration, and Cloud certificate-identity environment.
5. Start Mosquitto and Cloud, then start each updated Gateway.
6. Run positive and negative topic checks before reopening normal operations.

The smoke test must prove:

- Each Gateway can publish and subscribe inside its own namespace.
- Cross-tenant, cross-site, and cross-gateway access is denied.
- `cloud-control` can access every registered namespace.
- `monitor` can read `$SYS/#` but cannot access application topics.
- A client without a valid certificate cannot connect.

Useful client command shape:

```bash
mosquitto_sub -h <broker> -p 8883 \
  --cafile ca.crt --cert gateway.crt --key gateway.key \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request' -d
```

Repeat with another Gateway namespace and confirm the broker returns an authorization failure. Also connect once without `--cert` and `--key`; the TLS connection must be rejected.

To roll back, stop the new stack, restore the backed-up compose/config/ACL and password file, restore the previous Gateway environment, and restart the previous services. The hardening deploy does not delete legacy password material.

## Networking Checklist

- Public HTTPS should terminate at Nginx.
- Cloud health should answer at `/health`.
- MQTT should expose TLS, not plaintext, for production clients.
- Security groups should limit SSH, HTTPS, and MQTT access to expected sources.
- PostgreSQL should stay inside the private Docker/network boundary.

## Troubleshooting

### Cloud API Works But Device Commands Timeout

Check the boundary in this order:

1. Mobile receives `201 Created` for the command.
2. Cloud writes the command row.
3. Cloud publishes the MQTT request.
4. Gateway is connected to the broker.
5. Gateway receives the command topic.
6. Zigbee device receives the local command.
7. Gateway publishes command reply.

If Cloud later marks the command as `timeout` and the broker has no gateway client, debug Gateway MQTT first.

### MQTT TLS Fails

Check:

- `SB_MQTT_TLS_ENABLED=true`.
- `SB_MQTT_CERT_IDENTITY_ENABLED=true` in production.
- CA path exists inside the container.
- mTLS cert and key paths exist when `SB_MQTT_MTLS_ENABLED=true`.
- Certificate common names match `cloud-control`, `monitor`, or an inventory principal.
- Mosquitto has the CA, server certificate, server key, monitor certificate/key, and generated ACL mounted.
- Gateway and Cloud clocks are sane enough for certificate validation.

### Mobile Cannot Reach Cloud

Check:

- `API_BASE_URL` points to the correct host and scheme.
- Release builds use HTTPS.
- `API_AUTH_TOKEN` is present when the remote API requires it.
- Nginx forwards to Cloud.
- `/health` answers from the same network.

### Provisioning Does Not Join

Check:

- Factory device exists and is active.
- QR payload carries the expected EUI64. It does not carry the install code.
- Cloud resolves the factory install code and sends it to Gateway in `gateway.prepare_join`.
- No active non-terminal session already exists for the same device.
- Gateway received `gateway.prepare_join`.
- Local Zigbee permit-join window opened.
- Gateway publishes provisioning result back to Cloud.

### Automations Do Not Run

Check:

- Cloud accepted and stored the rule.
- Rule did not exceed MVP caps.
- Cloud published retained desired automation state.
- Gateway reported the automation as synced.
- Device event topics are arriving at Gateway and Cloud.
