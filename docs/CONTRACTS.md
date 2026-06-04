# Contracts

This file captures the contracts that other teams and agents should not rename casually. A contract is a public shape: a REST route, MQTT topic, payload field, command name, database-visible status, or device capability name.

## REST API

The Cloud API is mounted from `cloud/app/main.py`. `/health` is public. Other API routes depend on the auth and access-control functions in `cloud/app/auth.py` and `cloud/app/access_control.py`.

| Area | Routes | Notes |
|---|---|---|
| Auth | `/api/auth/login`, `/api/auth/me`, `/api/auth/change-password`, `/api/auth/logout` | Bearer tokens identify users. Seeded users may be forced to change passwords. |
| Devices | `/api/devices/`, `/api/devices/{id}`, `/api/devices/{id}/state` | Device list and reads are filtered by user visibility. |
| Commands | `/api/devices/{id}/command`, `/api/commands/{id}` | Commands are scoped to the user's home before publishing to MQTT. |
| Gateways | `/api/gateways/{id}/commissioning/open`, `/api/gateways/{id}/commissioning/close`, `/api/devices/{id}/rediscover` | Gateway operations publish gateway or device commands. |
| Provisioning | `/api/provisioning/labels`, `/api/provisioning/sessions` | Labels are admin-only. Sessions are visible to the owning home scope. |
| Automations | `/api/automations` and `/api/automations/{id}` | Rules are stored in Cloud and synced to Gateway through MQTT. |
| Automation events | `/api/automation-events` | Reads automation runtime events from Cloud storage. |

## MQTT Namespace

All production topics are under:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

`tenant_id`, `site_id`, and `gateway_id` are not decoration. They define the routing and authorization namespace. Broker ACLs and client certificates should keep each identity inside its own allowed prefix.

## MQTT Topic Families

| Topic shape | Direction | Purpose |
|---|---|---|
| `devices/{device_type}/{device_id}/reported` | Gateway to Cloud | Current device state. |
| `devices/{device_type}/{device_id}/telemetry` | Gateway to Cloud | Telemetry samples. |
| `devices/{device_type}/{device_id}/event` | Gateway to Cloud | Device events. |
| `devices/{device_type}/{device_id}/registry` | Gateway to Cloud | Device discovery or registry updates. |
| `devices/{device_type}/{device_id}/desired` | Cloud to Gateway | Desired device state. |
| `commands/{command_id}/request` | Cloud to Gateway | Command request envelope. |
| `commands/{command_id}/reply` | Gateway to Cloud | Command result envelope. |
| `gateway/online`, `gateway/health`, `gateway/event`, `gateway/log` | Gateway to Cloud | Gateway liveness and diagnostics. |
| `ota/campaigns/{campaign_id}/manifest` | Cloud to Gateway | OTA campaign manifest. |
| `ota/devices/{device_id}/desired` | Cloud to Gateway | Device OTA desired state. |
| `ota/devices/{device_id}/progress`, `ota/devices/{device_id}/event` | Gateway to Cloud | OTA progress and events. |
| `automations/{automation_id}/desired` | Cloud to Gateway | Retained desired automation rule. |
| `automations/{automation_id}/reported` | Gateway to Cloud | Gateway sync state for the rule. |
| `automations/{automation_id}/event` | Gateway to Cloud | Runtime automation event. |

## Command Contract

Cloud creates a command row before publishing MQTT. Command payloads should keep:

- `command_id`: unique command id.
- `op`: operation name such as `gateway.prepare_join` or translated device operation.
- `target`: structured target data.
- `timeout_ms`: command timeout window.

Gateway replies update command status. Do not rename command statuses without updating Cloud, Mobile, tests, and MQTT handling together.

## Provisioning Contract

Provisioning uses a factory-device record plus a session:

- `eui64`: device identity.
- `install_code`: install code from factory label or QR payload.
- `device_type`: supported device type.
- `room_id`: target room after join.
- `gateway.prepare_join`: MQTT command that asks the gateway to open joining.

Session states are terminal when they are `joined`, `failed`, `expired`, or `cancelled`. Non-terminal sessions should not be duplicated for the same device.

## OTA Contract

OTA uses campaign manifests, device desired state, progress, and events. The important rule is separation: Cloud publishes desired OTA work; Gateway and devices report what actually happened. Do not make Mobile infer OTA completion from desired state alone.

## Automation Contract

Automation rules are stored in Cloud and synced to Gateway. Current validation is intentionally narrow:

- Light actions use commands such as `on`, `off`, and `toggle`.
- Switch triggers do not carry arbitrary state.
- Motion triggers use an occupancy state.
- MVP caps are enforced for maximum automations per gateway and maximum actions per automation.

The Cloud-published value is canonical. Avoid compatibility aliases unless the issue or acceptance test explicitly requires one.

## Device Capabilities

Capabilities should describe what a device can do, not what a screen happens to show. Keep these names stable across Cloud, Mobile, Gateway, and firmware:

- Light: on/off and toggle behavior.
- Switch: button or interaction events.
- Motion or occupancy sensor: occupancy event/state.
- Gateway: commissioning, rediscovery, health, logs, provisioning, and OTA coordination.

When adding a new capability, update Cloud schemas, Mobile repositories/UI, Gateway translation, firmware behavior, and tests in the same scoped change.
