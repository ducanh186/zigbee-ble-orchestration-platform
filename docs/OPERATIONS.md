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
| `SB_MQTT_USERNAME`, `SB_MQTT_PASSWORD` | MQTT credentials for Cloud. |
| `SB_MQTT_TLS_ENABLED` | Enables MQTT TLS for Cloud. |
| `SB_MQTT_MTLS_ENABLED` | Requires Cloud client certificate and key. |
| `SB_MQTT_CA_CERT_PATH` | Broker CA certificate path. |
| `SB_MQTT_CLIENT_CERT_PATH`, `SB_MQTT_CLIENT_KEY_PATH` | Cloud MQTT client certificate and key. |

Cloud starts even if MQTT connection fails, but live command and device flows will not work until MQTT is reachable.

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
2. Fill EC2 host, SSH user, remote directory, database values, MQTT passwords, MQTT TLS values, and initial login passwords.
3. Keep private keys and `.env.deploy` out of Git.
4. Run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
```

The deploy script packages the repo, excludes local build/cache/secrets, copies the archive to EC2, prepares MQTT password files, prepares MQTT mTLS certificates, writes Cloud environment values, and starts the production Docker Compose stack.

## Production Services

The production compose files run:

- Nginx in front of Cloud.
- FastAPI Cloud on port 8000 inside the stack.
- PostgreSQL 16.
- Mosquitto on TLS port 8883.
- Volumes for PostgreSQL and Mosquitto data/certs/passwords.

`deploy/docker-compose.prod-secure.yml` is stricter about required environment variables. Prefer it when moving beyond demo use.

## MQTT TLS And mTLS

Production Mosquitto uses:

- TLS server certificate and key.
- CA file.
- `require_certificate true`.
- Password file.
- ACL file.

Cloud and Gateway should use TLS and client certificates in production. Certificate authentication proves identity, but it does not replace topic authorization. ACLs still need narrow topic prefixes.

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
- CA path exists inside the container.
- mTLS cert and key paths exist when `SB_MQTT_MTLS_ENABLED=true`.
- Mosquitto has the CA, server certificate, server key, password file, and ACL mounted.
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
