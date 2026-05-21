# Zigbee Smart Building Platform

This repository contains a small smart-building system for Zigbee devices. It
connects a Flutter mobile app, a FastAPI cloud backend, a Mosquitto broker, and
a native Silicon Labs Z3Gateway host application.

The current MVP focuses on real device monitoring, light control, and simple
automation rules such as "when motion is occupied, turn these lights on".

## System Overview

```text
Flutter app
  -> Cloud REST API (FastAPI)
  -> Mosquitto MQTT broker
  -> Z3Gateway C host app
  -> EFR32 NCP
  -> Zigbee end devices
```

The Gateway talks to MQTT directly. The old Python MQTT-to-IPC bridge is no
longer part of the active architecture.

## Main Parts

| Path | What it contains |
| --- | --- |
| `mobile_app/` | Flutter app for monitoring devices, controlling lights, and managing automation rules |
| `cloud/` | FastAPI backend, MQTT client, command tracking, events, and automation API |
| `gateway/` | Native Z3Gateway C host app for MQTT, Zigbee command dispatch, telemetry, and local rule handling |
| `mqtt/` | Mosquitto configuration for local and deployed brokers |
| `database/` | PostgreSQL schema used by the cloud backend |
| `deploy/` | EC2 deployment scripts and production Docker Compose setup |
| `docs/` | Contracts, design notes, implementation plans, and user-facing guides |
| `end_devices/` | Silicon Labs end-device firmware projects |

## Current MVP Features

- device list and device state through the mobile app
- light on/off commands from the app through Cloud and Gateway
- command status tracking
- motion occupancy display
- automation rule creation from the app
- Cloud automation rule storage and API
- event history through Cloud
- EC2 deployment scripts for the backend stack

Automation is intentionally simple in this version. The app creates and displays
rules. Cloud stores them. Gateway execution remains the device-side
responsibility.

## Run Locally

Start the local MQTT broker:

```bash
cd mqtt/docker
docker compose up -d
```

Run the Cloud API:

```bash
pip install -r cloud/requirements.txt
python -m cloud.app.seed
python -m cloud
```

Run Cloud tests:

```bash
pytest cloud/tests -q
```

Run the Flutter app:

```bash
cd mobile_app
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://localhost:8000
```

For an Android emulator talking to a host machine API, use `10.0.2.2` instead
of `localhost`.

## Deploy

Copy and fill the deployment environment file:

```powershell
Copy-Item deploy\.env.deploy.example deploy\.env.deploy
```

Deploy to EC2:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
```

Useful follow-up commands:

```powershell
powershell -File deploy\logs.ps1 cloud-api
powershell -File deploy\seed-remote.ps1
powershell -File deploy\ssh.ps1
```

## Credentials

### Mobile app login (NOT YET FUNCTIONAL)

The Flutter login screen calls `POST /auth/login` on the Cloud API, but **the cloud has no `/auth/*` router yet** (`cloud/app/routers/` ships only `automations`, `commands`, `devices`, `events`, `gateways`, `health`). Any username/password will currently return a 404 from the cloud and the app will display the friendly error `"Dang nhap that bai. ..."` from `friendlyErrorMessage` without crashing.

Tracked as a blocker in `docs/automation-e2e-report-20260517.md` (M1 = BLOCKED). When the auth router lands, the contract documented in `mobile_app/lib/data/repositories/remote_auth_repository.dart` is the expected payload (`access_token`, `user_id`, `expires_at`).

There is **no built-in test user, no hard-coded fallback, and no mock auth bypass**. To exercise the UI past the login gate before the cloud router exists, you currently need to add a mock `AuthRepository` or short-circuit `_AuthGate` in `mobile_app/lib/main.dart` — both are local-only changes and should not be committed.

### Backend service credentials (dev/staging defaults)

These come from `deploy/.env.deploy.example` and are already public in the repo. They are intended for the dev / staging EC2 stack only — change them before any production deployment.

| Service | Username | Password | Notes |
| --- | --- | --- | --- |
| MQTT (gateway role) | `gateway` | `gateway123` | Used by the Z3Gateway C host |
| MQTT (client role) | `client` | `client123` | Used by the Cloud API (`SB_MQTT_USERNAME` / `SB_MQTT_PASSWORD`) |
| MQTT (monitor role) | `monitor` | `monitor123` | Read-only debugging account |
| MQTT (bridge role) | `bridge` | `bridge123` | Reserved for broker bridging |
| PostgreSQL | `sb_user` | `sb_pass` | Database `sb_cloud` on port 5432 |

Override any of these by editing `deploy/.env.deploy` (the file is gitignored and not part of `.env.deploy.example`).

## Key Documentation

| Document | Use it for |
| --- | --- |
| [docs/AUTOMATION_APP_DESIGN_BRIEF.md](docs/AUTOMATION_APP_DESIGN_BRIEF.md) | Automation screen brief for product/design work |
| [docs/AUTOMATION_USER_GUIDE.md](docs/AUTOMATION_USER_GUIDE.md) | How to use the Automation feature in the app |
| [docs/MQTT_CONTRACT.md](docs/MQTT_CONTRACT.md) | MQTT topic tree, envelopes, QoS, retain rules, and command lifecycle |
| [docs/DEVICE_CAPABILITY_MATRIX.md](docs/DEVICE_CAPABILITY_MATRIX.md) | Supported MVP device types and capabilities |
| [docs/ADAPTER_ACTION_MAP.md](docs/ADAPTER_ACTION_MAP.md) | Mapping between MQTT payloads and Z3Gateway C behavior |
| [docs/CLOUD_IMPLEMENTATION_PLAN.md](docs/CLOUD_IMPLEMENTATION_PLAN.md) | Cloud API and database implementation notes |
| [docs/OTA_CAMPAIGN_CONTRACT.md](docs/OTA_CAMPAIGN_CONTRACT.md) | OTA staging and delivery contract |
| [docs/README.md](docs/README.md) | Documentation index |

## Branch and PR Rules

Use this branch format:

```text
prefix/<jira-ticket-id>-<short-description>
```

Examples:

```text
feature/3-mobile-automation-rule-management
docs/43-automation-app-docs
```

All work should merge into `main` through a pull request. Do not commit directly
to `main`.
