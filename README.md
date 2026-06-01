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
- motion occupancy display when Cloud has occupancy state or event data
- automation rule creation from the app
- Cloud automation rule storage, validation, and retained desired-state publish
- event history through Cloud
- EC2 deployment scripts for the backend stack

Automation is intentionally simple in this version. The app creates and displays
rules. Cloud stores them and publishes desired rule messages. Gateway command
dispatch is implemented, but live app-created automation execution still needs
SCRUM-51 hardware/EC2 evidence before it should be claimed as fully end-to-end.

## Current Verification Status

Last local audit: 2026-05-21 on branch
`docs/51-scrum51-evidence-scrum8-ready`.

- Cloud automation tests: `python -m pytest cloud/tests/ -q` -> 80 passed.
- Mobile tests: `flutter test` in `mobile_app/` -> 56 passed.
- SCRUM-51 still needs live evidence for final-report confidence: API evidence
  against EC2, MQTT trace, gateway log slice, cloud DB rows, and mobile
  screenshots/video tied to the same run.
- Current gateway code subscribes to `commands/+/request`; no
  `desired/automation/{id}` subscription was found in `gateway/Z3GatewayHost/app/`.
  Treat Cloud->Gateway dynamic automation sync as not proven live until that path
  is implemented and captured.
- OTA/SCRUM-8 is a planned contract: Cloud should orchestrate metadata only,
  Z3Gateway C should download and verify firmware from an artifact URL, and
  firmware binaries must not be sent as MQTT payloads.

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

## Key Documentation

| Document | Use it for |
| --- | --- |
| [docs/AUTOMATION_CONTRACT.md](docs/AUTOMATION_CONTRACT.md) | Automation rule contract and SCRUM-51 implementation audit note |
| [docs/AUTOMATION_USER_GUIDE.md](docs/AUTOMATION_USER_GUIDE.md) | How to use the Automation feature in the app |
| [docs/MQTT_CONTRACT.md](docs/MQTT_CONTRACT.md) | MQTT topic tree, envelopes, QoS, retain rules, and command lifecycle |
| [docs/DEVICE_CAPABILITY_MATRIX.md](docs/DEVICE_CAPABILITY_MATRIX.md) | Supported MVP device types and capabilities |
| [docs/ADAPTER_ACTION_MAP.md](docs/ADAPTER_ACTION_MAP.md) | Mapping between MQTT payloads and Z3Gateway C behavior |
| [docs/CLOUD_IMPLEMENTATION_PLAN.md](docs/CLOUD_IMPLEMENTATION_PLAN.md) | Cloud API and database implementation notes |
| [docs/OTA_CAMPAIGN_CONTRACT.md](docs/OTA_CAMPAIGN_CONTRACT.md) | OTA staging and delivery contract |
| [docs/SCRUM_51_EVIDENCE_AND_SCRUM_8_READY_AUDIT.md](docs/SCRUM_51_EVIDENCE_AND_SCRUM_8_READY_AUDIT.md) | SCRUM-51 evidence gap audit and SCRUM-8 definition of ready |
| [docs/README.md](docs/README.md) | Documentation index |

## Branch and PR Rules

Use this branch format:

```text
prefix/<jira-ticket-id>-<short-description>
```

Examples:

```text
feature/SCRUM-43-mobile-automation-rule-management
docs/SCRUM-43-automation-app-docs
```

All work should merge into `main` through a pull request. Do not commit directly
to `main`.
