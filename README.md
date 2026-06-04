# Zigbee Orchestration Platform

Zigbee Orchestration Platform is a smart-building prototype that connects a FastAPI Cloud backend, a Flutter mobile app, a C gateway runtime, MQTT, PostgreSQL, and Zigbee end devices. The system lets a user view devices, send commands, provision new devices, publish OTA campaigns, and sync automation rules to the gateway.

This repository is still a demo and hardening workspace. Treat production deployment, MQTT certificates, database credentials, and device install codes as real security boundaries.

## Architecture Snapshot

```text
Mobile App
  -> HTTPS / FastAPI Cloud
  -> PostgreSQL
  -> MQTT broker
  -> Gateway runtime
  -> Zigbee NCP and end devices
```

The Cloud app owns the REST API, user access checks, command rows, device state history, provisioning sessions, OTA metadata, and automation records. MQTT carries the live bridge between Cloud and Gateway under the `sb/v1/{tenant}/{site}/{gateway}` namespace. The Gateway subscribes to desired state and command topics, speaks Zigbee locally, and publishes device reports, events, command replies, health, automation status, and OTA progress back to Cloud.

## Quick Start

### Cloud API

```powershell
cd cloud
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn cloud.app.main:app --reload --host 0.0.0.0 --port 8000
```

Set `SB_DATABASE_URL`, `SB_MQTT_HOST`, `SB_MQTT_PORT`, and MQTT credential variables when running against PostgreSQL and Mosquitto. Local defaults exist for development, but production should use explicit secrets.

### Mobile App

```powershell
cd mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

For authenticated remote API use, pass a token and keep release builds on HTTPS:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://example.com `
  --dart-define=API_AUTH_TOKEN=<token>
```

### Production Deploy

Use `deploy/.env.deploy.example` as the template for `deploy/.env.deploy`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
```

Do not commit `.env.deploy`, generated certificates, MQTT password files, or private keys.

## Lean Documentation

- [Architecture](docs/ARCHITECTURE.md): system boundaries and data flow.
- [Contracts](docs/CONTRACTS.md): REST and MQTT contracts for provisioning, OTA, automation, and capabilities.
- [Operations](docs/OPERATIONS.md): local run, production deploy, networking, MQTT TLS, and troubleshooting.
- [Security](docs/SECURITY.md): security model, known risks, hardening checklist, and post-scan actions.
- [Developer Guide](docs/DEVELOPER_GUIDE.md): setup, tests, workflow, and branch/Jira expectations.

## Repository Map

| Path | Purpose |
|---|---|
| `cloud/` | FastAPI backend, routers, SQLAlchemy models, auth, MQTT bridge, tests, and web dev assets. |
| `mobile_app/` | Flutter client for login, device control, provisioning, OTA, and automations. |
| `gateway/` | Gateway host runtime that connects MQTT to the local Zigbee stack. |
| `end_devices/` | Zigbee end-device firmware projects. |
| `mqtt/` | Mosquitto production config, ACLs, and certificate setup inputs. |
| `database/` | SQL schema and migrations. Runtime ORM code is the source of truth when it differs from older SQL snapshots. |
| `deploy/` | EC2/Docker/Nginx/Mosquitto/PostgreSQL deployment scripts and examples. |
| `docs/` | The current lean documentation set. |

## What Not To Touch Accidentally

Private keys, PEM files, generated certificates, local deploy env files, and untracked design/test artifacts are not documentation. Keep files such as `2110.pem` and other local secrets out of commits and out of cleanup sweeps.
