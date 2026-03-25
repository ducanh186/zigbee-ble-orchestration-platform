# Refactor Repo Sang Z3Gateway-Native Gateway Core

## Summary

- Biến repo thành **gateway core** cho kiến trúc **Z3Gateway-native only**: host-radio dùng **EZSP/ASH** của Z3Gateway, repo **không còn** custom application UART runtime giữa Ubuntu và EFR32.
- Áp dụng MQTT contract chuẩn mới với namespace cố định:
  `sb/v1/{tenant_id}/{site_id}/{gateway_id}/...`
- Dùng **local IPC qua Unix domain socket + NDJSON** làm boundary nội bộ giữa `z3gateway adapter` và `mqtt bridge`.
- Dọn repo theo kiểu **hard delete**: chỉ giữ 2 file `plan.md` và `iot_zigbee_sprint_plan.md` ngoài các thành phần còn thuộc scope mới; bỏ toàn bộ dashboard demo, scripts phụ, legacy docs, legacy custom-UART code.

## Implementation Changes

### 1. Repo cleanup và structure đích

- Giữ scope repo ở 3 phần:
  - `gateway` runtime
  - `mqtt` broker config/dev compose
  - `docs` contract tối thiểu 
- Hard delete các phần không còn thuộc scope:
  - toàn bộ `dashboard/`
  - toàn bộ `scripts/`
  - toàn bộ legacy custom-UART simulator/test hiện tại
  - toàn bộ doc legacy `wfms/`, `iot/`, `home/`, valve-flow-monitoring, coordinator button/CLI internals
  - file hướng dẫn/tooling nội bộ không còn phục vụ runtime mới
- Giữ và viết lại:
  - `gateway` thành bridge mới
  - `mqtt/config/*` và `mqtt/docker/docker-compose.yml`
  - `docs/MQTT_CONTRACT.md`
  - `docs/UART_FRAME_FORMAT.md`
  - thêm `docs/OTA_CAMPAIGN_CONTRACT.md`
  - `gateway/README.md`, `.env.example`, dependency files

### 2. Runtime architecture mới

- `gateway` trở thành **MQTT <-> IPC bridge**, không còn lớp `RealUart`/`FakeUart`.
- IPC transport mặc định:
  - Unix domain socket
  - path mặc định: `/tmp/sb-gateway.sock`
  - override bằng env `SB_IPC_SOCKET_PATH`
- IPC wire format:
  - NDJSON, 1 JSON object / line
  - không prefix `@DATA/@CMD/@ACK`
- IPC message kinds cố định:
  - adapter -> bridge: `registry`, `reported`, `event`, `gateway_health`, `gateway_log`, `command_reply`, `ota_progress`, `ota_event`
  - bridge -> adapter: `desired`, `command_request`, `ota_manifest`, `ota_desired`
- Runtime modules cần có:
  - config/env loading
  - topic builder/parser cho `sb/v1`
  - Pydantic models cho MQTT envelope và IPC record
  - IPC client/server codec NDJSON
  - MQTT publisher/subscriber với retained/LWT/QoS đúng contract
  - command lifecycle tracker
  - OTA artifact staging manager

### 3. Public contracts cần khóa và implement đúng

- MQTT topic tree cố định:
  - `.../gateway/online`
  - `.../gateway/health`
  - `.../gateway/log`
  - `.../devices/{device_id}/registry`
  - `.../devices/{device_id}/reported`
  - `.../devices/{device_id}/desired`
  - `.../devices/{device_id}/event`
  - `.../commands/{command_id}/request`
  - `.../commands/{command_id}/reply`
  - `.../ota/campaigns/{campaign_id}/manifest`
  - `.../ota/devices/{device_id}/desired`
  - `.../ota/devices/{device_id}/progress`
  - `.../ota/devices/{device_id}/event`
- MQTT envelope chung bắt buộc cho mọi publish/subscribe payload:
  - `schema`, `msg_id`, `ts`, `tenant_id`, `site_id`, `gateway_id`, `source`, `payload`
  - optional nhưng support đầy đủ: `trace_id`, `correlation_id`
- Topic semantics:
  - retained: `gateway/online`, `gateway/health`, `devices/*/registry`, `devices/*/reported`, `devices/*/desired`, `ota/campaigns/*/manifest`, `ota/devices/*/desired`, `ota/devices/*/progress`
  - non-retained: `gateway/log`, `devices/*/event`, `commands/*/request`, `commands/*/reply`, `ota/devices/*/event`
  - LWT: `gateway/online = offline`; on connect publish retained `online`
- Command lifecycle cố định:
  - `accepted -> queued -> sent -> executed | failed | timeout`
  - mỗi transition publish 1 message lên `commands/{command_id}/reply`
  - `correlation_id` của toàn bộ lifecycle message = `command_id`
- Identity model cố định:
  - `device_id` = logical stable ID
  - `eui64` = hardware stable identity trong payload
  - `nwk_addr` = runtime/debug only, không dùng làm primary key
- OTA behavior cố định:
  - cloud chỉ publish `manifest` và `ota desired`
  - gateway tải `.ota` từ `artifact.url`, verify `sha256`/`size_bytes`, lưu vào `SB_OTA_DIR` mặc định `./ota-files`
  - gateway không publish binary qua MQTT
  - progress/event MQTT chỉ phản ánh workflow staging/offer/result

### 4. Broker config và docs

- Rewrite Mosquitto ACL theo namespace `sb/v1/+/+/+/#`
- Giữ 3 principal tối thiểu:
  - `gateway`: readwrite toàn namespace của gateway
  - `client`: read state/registry/event/reply/progress/health/log, write `desired`, `command request`, `ota manifest`, `ota desired`
  - `monitor`: read-only toàn namespace
- Rewrite docs theo source of truth mới:
  - `MQTT_CONTRACT.md`: topic tree, envelope, retained/LWT/QoS, examples
  - `UART_FRAME_FORMAT.md`: ghi rõ native mode **không định nghĩa custom app UART trên host-radio**; serial host-radio là EZSP/ASH của Z3Gateway; phần frame application của repo là IPC NDJSON
  - `OTA_CAMPAIGN_CONTRACT.md`: manifest, desired, progress, event, staging rules

## Test Plan

- Unit tests:
  - topic builder/parser cho toàn bộ `sb/v1`
  - envelope validation, required/optional fields
  - IPC NDJSON encode/decode, kind routing
  - command lifecycle state machine
  - OTA manifest validation và artifact metadata checks
- Integration tests với fake IPC peer:
  - adapter gửi `registry/reported/event` -> bridge publish đúng topic, retained flag đúng
  - MQTT `desired` -> bridge phát IPC `desired`
  - MQTT `commands/.../request` -> bridge phát IPC `command_request` và republish đủ lifecycle replies
  - MQTT OTA manifest/device desired -> gateway stage file, emit progress/event
  - MQTT connect/disconnect -> `gateway/online` retained + LWT đúng
- Manual smoke:
  1. chạy Mosquitto từ docker compose
  2. chạy bridge với fake IPC peer
  3. publish sample `command request`, `desired`, `ota manifest`
  4. verify topic shape, payload envelope, retained behavior
- Không test custom UART, không test serial EFR32, không test EZSP parser trong repo này.
- Bổ sung tooling test chuẩn:
  - thêm `pytest` vào dev dependencies
  - bỏ test `FakeUart` cũ hoàn toàn

## Assumptions And Defaults

- Runtime target là **Ubuntu/Linux only**; Windows chỉ còn là môi trường soạn code, không là target vận hành.
- Repo sau refactor **không** giữ dashboard, cloud backend, mobile app, hay agent/tooling scripts.
- Repo **không** implement lại Z3Gateway serial/EZSP; boundary của repo dừng ở IPC socket với adapter local.
- Legacy custom coordinator mode với `@STATE/@EVENT/@REQ/...` bị loại khỏi repo, không archive, không compat stub.
- Default env mới:
  - `SB_TENANT_ID=hust`
  - `SB_SITE_ID=lab01`
  - `SB_GATEWAY_ID=gw-ubuntu-01`
  - `SB_IPC_SOCKET_PATH=/tmp/sb-gateway.sock`
  - `SB_OTA_DIR=./ota-files`
  - `SB_COMMAND_TIMEOUT_MS=5000`
