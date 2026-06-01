# Z3Gateway-Native Gateway Core — Architecture Plan

## Summary

- Repo là **gateway core** cho kiến trúc **Z3Gateway-native only**: host-radio dùng **EZSP/ASH** của Z3Gateway.
- **Z3Gateway C là single process** trên Ubuntu host, chạy trực tiếp:
  - MQTT client (subscribe + publish)
  - Zigbee EZSP/ASH handling
  - Command lifecycle management
  - Device registry
  - Local automation / rule engine
- Áp dụng MQTT contract chuẩn với namespace cố định:
  `sb/v1/{tenant_id}/{site_id}/{gateway_id}/...`
- **Không có IPC socket**, không có MQTT bridge process riêng, không có NDJSON wire format giữa các process.

## Production Architecture (Frozen)

```text
Flutter App ──HTTP──▶ Cloud API (FastAPI :8000) ◄──▶ Mosquitto (:1883) ◄──MQTT──▶ Z3Gateway C ◄──EZSP/ASH──▶ EFR32 NCP ◄──Zigbee──▶ End Devices
                           │ PostgreSQL                                     │
                           ▼                                                ├─ MQTT client
                        sb_cloud DB                                         ├─ command queue
                                                                            ├─ device registry
                                                                            ├─ rule engine
                                                                            └─ local automation
```

### Boundary mới

| Boundary | Protocol | Ownership |
|---|---|---|
| Cloud ↔ MQTT broker | MQTT over TCP | Mosquitto broker |
| MQTT broker ↔ Z3Gateway C | MQTT over TCP | Z3Gateway C (Paho C client) |
| Z3Gateway C ↔ NCP radio | EZSP/ASH over serial/UART | Silabs EmberZNet stack |
| NCP ↔ Zigbee end-devices | Zigbee 802.15.4 over-the-air | Silabs Zigbee stack |

## Implementation Structure

### Repo structure

```
gateway/          Z3Gateway C source — single process, MQTT + Zigbee
  Z3Gateway/
    Z3GatewayHost/
      app/        Application modules (C):
        app_mqtt.c/h         MQTT client integration
        sb_command.c/h       Command lifecycle management
        cmd_handler.c/h      CLI debug handler (legacy @CMD)
        device_registry.c/h  Device ID → nodeId/endpoint mapping
        device_dispatch.c/h  device_type → action routing
        light_ctrl.c/h       Light on/off/level actions
        switch_logic.c/h     Switch event handling
        rule_engine.c/h      Local automation rules
        telemetry_rx.c       Attribute report handling
        device_monitor.c/h   Device reachability tracking
        app_state.c/h        Gateway state management
        app_utils.c/h        Utility functions
        app_log.c/h          Logging
        net_mgr.c/h          Network management
        app_config.h         Build-time configuration
cloud/            Cloud backend — FastAPI REST API + MQTT subscriber (Python)
mqtt/             Mosquitto broker configuration + Docker Compose
deploy/           EC2 deployment scripts + docker-compose
docs/             Architecture contracts, sprint plan, implementation plans
end_devices/      End device firmware source (Simplicity Studio projects)
artifact/         Pre-built firmware binaries (.s37)
```

### Z3Gateway C internal modules

| Module | Responsibility |
|---|---|
| `app_mqtt` | MQTT connect, subscribe, publish, LWT, envelope build/parse |
| `sb_command` | Command queue, pending table, timeout tracking, lifecycle publish |
| `cmd_handler` | Legacy `@CMD` CLI debug (stdio only, not production path) |
| `device_registry` | `device_id → (nodeId, endpoint, device_type)` mapping |
| `device_dispatch` | Route incoming MQTT command/desired to correct device handler |
| `light_ctrl` | `light_on()`, `light_off()`, `light_set_level()` via Ember AF |
| `switch_logic` | Handle switch toggle event → publish event + trigger local rules |
| `rule_engine` | Evaluate local automation rules (switch→light, motion→light) |
| `telemetry_rx` | Handle `emberAfReportAttributesCallback` → build + publish reported |
| `device_monitor` | Track device reachability, last-seen timestamps |
| `app_state` | Gateway online/health status, publish gateway/* topics |

## Public Contracts (Frozen)

### MQTT topic tree cố định

```text
sb/v1/{tenant}/{site}/{gateway}/gateway/online
sb/v1/{tenant}/{site}/{gateway}/gateway/health
sb/v1/{tenant}/{site}/{gateway}/gateway/log
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/registry
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/reported
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/telemetry
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/event
sb/v1/{tenant}/{site}/{gateway}/commands/{command_id}/request
sb/v1/{tenant}/{site}/{gateway}/commands/{command_id}/reply
sb/v1/{tenant}/{site}/{gateway}/ota/campaigns/{campaign_id}/manifest
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/cancel
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/progress
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/event
```

### MQTT envelope bắt buộc

Required: `schema`, `msg_id`, `ts`, `tenant_id`, `site_id`, `gateway_id`, `source`, `payload`
Optional: `trace_id`, `correlation_id`

### Command lifecycle cố định

```text
accepted → queued → sent → executed | failed | timeout
```

Mỗi transition publish 1 message lên `commands/{command_id}/reply`.
Toàn bộ lifecycle do Z3Gateway C quản lý và publish trực tiếp.

### Identity model cố định

- `device_id` = logical stable ID (primary key)
- `eui64` = hardware stable identity trong payload
- `nwk_addr` = runtime/debug only

### OTA behavior cố định

- OTA hiện là contract/prerequisite, không phải capability đã hoàn tất end-to-end
  trong repo hiện tại.
- Cloud chỉ điều phối metadata: campaign manifest, target desired, cancel intent.
- Z3Gateway C tải `.ota` từ `artifact.url`, verify `sha256`/`size_bytes`, lưu vào `SB_OTA_DIR`
- Z3Gateway C offer OTA file qua native Zigbee OTA
- Z3Gateway C không publish binary qua MQTT
- Progress/event MQTT chỉ phản ánh workflow staging/offer/result/cancel/rollback
- Các tên `ota.start`, `ota.cancel`, `ota.progress`, `ota.complete` là operation
  vocabulary trong API/log/test; MQTT vẫn route bằng topic `manifest`, `desired`,
  `cancel`, `progress`, `event`.
- Gateway phải có runtime OTA manager trước khi Cloud campaign được xem là OTA
  thật; nếu chưa có, Cloud chỉ tạo được campaign metadata.

## Internal Data Flow

### Cloud-driven command path

```text
Cloud/API  →  MQTT commands/{command_id}/request
           →  Z3Gateway C nhận trực tiếp
           →  parse command
           →  dispatch theo device_type
           →  send Zigbee command via Ember AF
           →  publish commands/{command_id}/reply
           →  publish device reported nếu state đổi
```

### Device-driven uplink path

```text
Zigbee device state/event
  →  Z3Gateway C nhận trực tiếp (EZSP callback)
  →  normalize payload
  →  publish MQTT reported / event
```

### Gateway-driven local automation path

```text
Switch event / motion event
  →  Z3Gateway C rule engine
  →  light control action
  →  publish switch/motion event
  →  publish light reported sau khi state đổi
```

### Queue / pending model

- Internal command queue trong Z3Gateway C
- Pending command table với timeout tracking
- Retry / debounce / anti-loop guard
- **Không có IPC** — tất cả queue nội bộ trong cùng process

## Configuration Defaults

| Variable | Default | Description |
|---|---|---|
| `SB_TENANT_ID` | `hust` | Tenant ID |
| `SB_SITE_ID` | `lab01` | Site ID |
| `SB_GATEWAY_ID` | `gw-ubuntu-01` | Gateway ID |
| `SB_MQTT_HOST` | `localhost` | MQTT broker host |
| `SB_MQTT_PORT` | `1883` | MQTT broker port |
| `SB_OTA_DIR` | `./ota-files` | OTA artifact storage |
| `SB_COMMAND_TIMEOUT_MS` | `5000` | Command timeout |

## Test Plan

- Unit tests:
  - MQTT topic builder/parser cho toàn bộ `sb/v1`
  - Envelope validation, required/optional fields
  - Command lifecycle state machine
  - OTA manifest validation và artifact metadata checks
- Integration tests:
  - Z3Gateway C connects to Mosquitto, subscribes, publishes correctly
  - MQTT `command request` → Z3Gateway C processes → publishes lifecycle replies
  - MQTT `desired` → Z3Gateway C dispatches → publishes reported
  - MQTT connect/disconnect → `gateway/online` retained + LWT đúng
- Manual smoke:
  1. Chạy Mosquitto từ docker compose
  2. Chạy Z3Gateway C
  3. Publish sample `command request`, `desired` via `mosquitto_pub`
  4. Verify topic shape, payload envelope, retained behavior
- Không test custom UART, không test serial EFR32, không test EZSP parser trong repo này.

## Assumptions

- Runtime target là **Ubuntu/Linux only**; Windows chỉ là môi trường soạn code.
- Z3Gateway C là **single process** — không có bridge process, không có adapter process riêng.
- Boundary của Z3Gateway C:
  - **Bên ngoài**: MQTT broker (pub/sub)
  - **Bên dưới**: NCP radio (EZSP/ASH, owned by Silabs stack)
- Legacy `@CMD` trên stdio chỉ dùng cho debug CLI local, không phải production path.

## Historical Note

> **IPC architecture (superseded):** phiên bản trước của plan này định nghĩa:
> - `gateway` = "MQTT ↔ IPC bridge" (Python process)
> - Unix domain socket `/tmp/sb-gateway.sock` với NDJSON wire format
> - 12 IPC kinds giữa bridge và adapter
> - Fake IPC peer cho testing
>
> Kiến trúc đó đã được thay thế bởi direct MQTT integration trong Z3Gateway C.
> Xem git history nếu cần tham khảo phiên bản IPC.
