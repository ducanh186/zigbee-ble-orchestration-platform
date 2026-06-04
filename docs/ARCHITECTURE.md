# Architecture

This platform has five runtime parts: Cloud, Mobile, MQTT, Gateway, and Zigbee devices. PostgreSQL stores the durable state. The design is intentionally split this way so each layer has one clear job.

## System Boundaries

| Layer | Main job | Source paths |
|---|---|---|
| Cloud | REST API, authentication, access checks, database writes, MQTT bridge. | `cloud/app/` |
| Mobile | User-facing control, provisioning, OTA, automation, and API calls. | `mobile_app/` |
| MQTT | Live message transport between Cloud and Gateway. | `mqtt/`, `cloud/app/mqtt_client.py`, `gateway/Z3GatewayHost/app/app_mqtt.c` |
| Gateway | Converts MQTT commands into local Zigbee actions and reports state back. | `gateway/` |
| Devices | Zigbee firmware for lights, switches, sensors, and NCP support. | `end_devices/` |
| Database | Homes, rooms, users, devices, states, events, commands, automations, factory devices, and provisioning sessions. | `cloud/app/models.py`, `database/` |

## Data Flow

### Device Report Flow

1. A Zigbee device changes state or emits an event.
2. The Gateway receives it from the local Zigbee stack.
3. The Gateway publishes an MQTT message under `sb/v1/{tenant}/{site}/{gateway}/devices/...`.
4. Cloud subscribes to reported, telemetry, event, registry, command reply, gateway health, automation, and OTA topics.
5. Cloud upserts device records and writes `device_states`, `events`, or command status rows.
6. Mobile reads the latest state through the REST API.

### Command Flow

1. Mobile sends a command to Cloud, usually through `/api/devices/{device_id}/command`.
2. Cloud checks the authenticated user and the device scope.
3. Cloud creates a `commands` row with status such as `accepted`, `sent`, `completed`, `failed`, or `timeout`.
4. Cloud publishes a command request to MQTT.
5. Gateway performs the Zigbee action and publishes a command reply.
6. Cloud updates the command row and Mobile can poll `/api/commands/{command_id}`.

### Provisioning Flow

1. An admin creates a factory-device label from `/api/provisioning/labels`.
2. A parent or admin starts a provisioning session from `/api/provisioning/sessions`.
3. Cloud validates the gateway, room, active factory device, QR payload, and duplicate active sessions.
4. Cloud creates a `gateway.prepare_join` command and publishes it to MQTT.
5. Gateway opens local joining for the requested window.
6. Cloud tracks the provisioning session until it joins, fails, expires, or is cancelled.

### Automation Flow

1. Mobile creates or edits an automation rule.
2. Cloud validates supported trigger and action shapes, then stores the row.
3. Cloud publishes retained desired automation state to MQTT.
4. Gateway reports sync status and runtime automation events.
5. Cloud stores automation events for Mobile to read.

### OTA Flow

OTA metadata and device progress use Cloud REST endpoints and MQTT topics. Cloud publishes desired OTA work and campaign manifests. Gateway or devices report progress and events back through the `ota/devices/...` topic family.

## Database Model

The ORM in `cloud/app/models.py` is the current source of truth. The main tables are:

- `homes`, `rooms`, and `users` for account and access scope.
- `devices`, `device_states`, and `events` for live device inventory and history.
- `commands` for Cloud-to-Gateway command tracking.
- `automations` and `automation_events` for rule sync and execution history.
- `factory_devices` and `provisioning_sessions` for QR/install-code provisioning.

Older SQL files are useful as snapshots, but check the ORM first when behavior matters.

## Design Trade-Offs

The split between REST and MQTT keeps Mobile simple: it talks only to Cloud, not directly to the broker or gateway. The cost is that Cloud must be strict about auth, object scope, command timeouts, and MQTT topic boundaries.

MQTT gives the gateway a lightweight live channel, but topic namespace mistakes can become security bugs. The production ACL must bind each credential to the right tenant, site, and gateway prefix.

PostgreSQL gives Cloud a reliable audit trail for commands and device state. The trade-off is that MQTT callbacks need careful session handling so live messages do not corrupt database state.
