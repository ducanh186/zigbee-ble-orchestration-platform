# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Zigbee/BLE IoT orchestration platform** built around a Z3Gateway-native architecture. The system enables cloud-based management of Zigbee end devices through a gateway bridge that translates between MQTT and local IPC.

**Key architectural decision**: The host-to-radio boundary uses **EZSP/ASH** protocol owned by Z3Gateway. This repository does NOT implement custom UART protocols on the serial link.

## Repository Structure

```
gateway/          Gateway MQTT <-> IPC bridge (Python, Linux runtime)
cloud/            Cloud backend — FastAPI REST API + MQTT subscriber (Python)
mqtt/             Local Mosquitto broker configuration
deploy/           EC2 deployment scripts (PowerShell) + docker-compose
docs/             Architecture contracts, sprint plan, implementation plans
end_devices/      End device firmware (placeholder)
mobile_app/       Mobile app code (placeholder)
```

## Core Architecture

### Gateway Bridge (`gateway/`)

The gateway bridge implements a **contract-aware MQTT <-> IPC translator**:

- **MQTT side**: Publishes/subscribes to the `sb/v1/{tenant_id}/{site_id}/{gateway_id}/...` namespace
- **IPC side**: Unix domain socket at `/tmp/sb-gateway.sock` using NDJSON over UTF-8
- **Runtime**: Python 3.12+, Linux/POSIX only

**Key modules**:
- `bridge.py`: Core routing logic between MQTT and IPC
- `models.py`: Pydantic models for MQTT envelopes and IPC records
- `topics.py`: Topic builders and subscription filters
- `lifecycle.py`: Command lifecycle tracker (accepted → queued → sent → executed/failed/timeout)
- `ipc.py`: Unix socket server with automatic client replacement
- `ota.py`: OTA artifact download, verification, and staging manager
- `config.py`: Settings loaded from `gateway/.env`

### Cloud Backend (`cloud/`)

FastAPI REST API + MQTT subscriber/publisher for cloud-side device management.

- **Stack**: FastAPI + SQLAlchemy 2.0 async + aiosqlite (SQLite) + Paho MQTT
- **DB**: 7 tables — `homes`, `rooms`, `users`, `devices`, `device_states`, `events`, `commands`
- **Entry point**: `python -m cloud` (uvicorn) or Docker container

**Key modules**:
- `app/main.py`: FastAPI app with lifespan (init DB + MQTT client)
- `app/config.py`: pydantic-settings with `SB_` env prefix
- `app/database.py`: SQLAlchemy async engine + session factory
- `app/models.py`: ORM models (Home, Room, User, Device, DeviceState, Event, Command)
- `app/schemas.py`: Pydantic request/response schemas
- `app/mqtt_client.py`: MQTT subscriber (reported/event/reply → DB) + command publisher
- `app/seed.py`: Seed script with sample home/rooms/devices
- `app/routers/`: health, devices, events, commands

**API endpoints**:
- `GET /health` — healthcheck
- `GET /api/devices` — list devices (optional `?room_id=`)
- `GET /api/devices/{device_id}` — device detail
- `GET /api/devices/{device_id}/state` — latest reported state
- `POST /api/devices/{device_id}/command` — send command → MQTT publish
- `GET /api/commands/{command_id}` — command status
- `GET /api/events` — event history (`?device_id=&event_type=&limit=&offset=`)

### Protocol Contracts

**MQTT envelope** (all topics):
```json
{
  "schema": "sb.v1",
  "msg_id": "uuid",
  "ts": "ISO8601",
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway|cloud|adapter",
  "trace_id": "optional",
  "correlation_id": "optional",
  "payload": {}
}
```

**IPC record** (NDJSON line):
```json
{
  "v": 1,
  "kind": "reported|desired|command_request|...",
  "msg_id": "uuid",
  "ts": "ISO8601",
  "source": "adapter|cloud",
  "payload": {}
}
```

### Identity Model

- `device_id`: logical stable identifier (primary)
- `eui64`: hardware identifier (in payloads)
- `nwk_addr`: runtime debug field only (never a primary key)

### Command Lifecycle

Commands follow a strict state machine:
```
accepted → queued → sent → executed | failed | timeout
```

- Gateway emits: `accepted`, `queued`, `sent`, and `timeout` (if adapter doesn't respond)
- Adapter emits: `executed` or `failed`
- All replies use `correlation_id = {command_id}`

### OTA Workflow

1. Cloud publishes campaign manifest to `ota/campaigns/{campaign_id}/manifest`
2. Gateway downloads artifact from `artifact.url`, verifies SHA256 and size
3. Gateway stages file under `SB_OTA_DIR` (default: `./ota-files`)
4. Gateway forwards `ota_desired` IPC record with `local_artifact_path` to adapter
5. Adapter handles Zigbee OTA protocol natively

**Important**: Gateway never publishes firmware binaries over MQTT.

## Development Commands

### Cloud Backend

```bash
# Install dependencies
pip install -r cloud/requirements.txt

# Seed sample data
python -m cloud.app.seed

# Run the API server (dev mode with reload)
python -m cloud
# Swagger UI at http://localhost:8000/docs

# Run with uvicorn directly
uvicorn cloud.app.main:app --reload --port 8000
```

### Gateway Bridge

```bash
# Install dependencies
pip install -r gateway/requirements.txt

# Create configuration
cp gateway/.env.example gateway/.env

# Run the bridge
python -m gateway

# Run all tests
pytest gateway/tests/

# Run specific test
pytest gateway/tests/test_bridge.py::test_function_name

# Run with coverage
pytest --cov=gateway --cov-report=term-missing gateway/tests/
```

### MQTT Broker (local dev)

```bash
cd mqtt/docker
docker compose up -d      # Start
docker compose down        # Stop
docker compose logs -f     # View logs
```

**Broker ports**: `1883` (MQTT), `9001` (WebSocket)

**Principals**: `gateway` (readwrite), `client` (read state + write commands), `monitor` (read-only)

### Deploy to EC2

```powershell
# 1. Configure (once)
cp deploy\.env.deploy.example deploy\.env.deploy
# Edit: EC2_HOST, EC2_KEY, passwords

# 2. First-time EC2 setup (once)
powershell -ExecutionPolicy Bypass -File deploy\ec2-setup.ps1

# 3. Deploy (each code update)
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1

# 4. Utilities
powershell -File deploy\logs.ps1              # all logs
powershell -File deploy\logs.ps1 cloud-api    # API logs only
powershell -File deploy\seed-remote.ps1       # seed DB on EC2
powershell -File deploy\ssh.ps1               # SSH into EC2
```

**Production containers**: `sb-mosquitto` (:1883) + `sb-cloud-api` (:8000)

## Git Workflow Rules

### Branch Naming

- Branch names must follow this format: `prefix/<jira-ticket-id>-<branch-description>`.
- Allowed `prefix` values are: `feature`, `bugfix`.
- Use lowercase kebab-case for `<branch-description>`.
- Example: if Jira ticket ID is `1` and description is `create code base`, the branch name is `feature/1-create-code-base`.

### Pull Request Rules

- All work must be merged into `main` through a pull request.
- Direct merge/commit to `main` is not allowed.
- Every pull request must be approved before merging.

## Configuration

Default development namespace:
- `tenant_id`: `hust`
- `site_id`: `lab01`
- `gateway_id`: `gw-ubuntu-01`

### Gateway env vars (set in `gateway/.env`):
- `SB_MQTT_HOST`, `SB_MQTT_PORT`, `SB_MQTT_USERNAME`, `SB_MQTT_PASSWORD`
- `SB_IPC_SOCKET_PATH` (default: `/tmp/sb-gateway.sock`)
- `SB_OTA_DIR` (default: `./ota-files`)
- `SB_COMMAND_TIMEOUT_MS` (default: `5000`)

### Cloud env vars (set in `cloud/.env`):
- `SB_DATABASE_URL` (default: `sqlite:///./cloud.db`)
- `SB_MQTT_HOST`, `SB_MQTT_PORT`, `SB_MQTT_USERNAME`, `SB_MQTT_PASSWORD`
- `SB_TENANT_ID`, `SB_SITE_ID`, `SB_GATEWAY_ID`
- `SB_API_HOST` (default: `0.0.0.0`), `SB_API_PORT` (default: `8000`)

## Testing Strategy

Tests use **pytest** with test doubles for external dependencies:

- `FakeMQTTPublisher`: Captures MQTT publishes for assertions
- `FakeIPCServer`: Captures IPC sends without opening real sockets

Test structure (gateway):
- `conftest.py`: Shared fixtures and test doubles
- `test_models.py`: Pydantic model validation
- `test_topics.py`: Topic builders and parsing
- `test_ipc.py`: IPC encoding/decoding
- `test_lifecycle.py`: Command lifecycle state machine
- `test_bridge.py`: End-to-end bridge routing logic

## Key Contracts to Reference

When working on protocol-related code, always reference:
- `docs/MQTT_CONTRACT.md`: MQTT topic structure, QoS, retain policies
- `docs/UART_FRAME_FORMAT.md`: IPC boundary (not UART in native mode)
- `docs/OTA_CAMPAIGN_CONTRACT.md`: OTA artifact staging workflow
- `docs/CLOUD_IMPLEMENTATION_PLAN.md`: Cloud backend DB schema + API design

## Known Issues & Deployment Troubleshooting

Các lỗi đã gặp khi deploy từ Windows (PowerShell) lên EC2 (Ubuntu) và cách khắc phục:

### 1. CRLF trong SSH heredoc (PowerShell → Linux)

**Lỗi**: PowerShell here-string `@"..."@` tạo ra `\r\n`, bash trên Linux từ chối ký tự `\r` → lệnh SSH thất bại im lặng hoặc báo lỗi cú pháp.

**Cách sửa**: Không dùng inline heredoc. Thay vào đó ghi script ra file tạm, strip `\r`, SCP lên EC2 rồi chạy `bash /tmp/_deploy_cmd.sh`. Xem hàm `Invoke-EC2` trong `deploy/deploy.ps1`.

### 2. UTF-8 BOM từ PowerShell

**Lỗi**: `Set-Content -Encoding utf8` trong PowerShell 5.x thêm BOM (3 byte `EF BB BF`) vào đầu file → bash trên Linux không parse được dòng đầu.

**Cách sửa**: Dùng `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))` để ghi file UTF-8 không BOM.

### 3. Stderr bị PowerShell bắt thành lỗi

**Lỗi**: Khi `$ErrorActionPreference = "Stop"`, các warning từ stderr (ví dụ `mosquitto_passwd` in cảnh báo về permission) khiến PowerShell throw exception, dừng script.

**Cách sửa**: Tạm set `$ErrorActionPreference = "Continue"` trong block SSH, và parse exit code từ output thay vì dựa vào `$LASTEXITCODE`. Pattern: append `echo EXIT_CODE=$?` vào cuối lệnh remote, rồi regex match kết quả.

### 4. Inline comment trong `.env` file

**Lỗi**: `EC2_HOST=52.199.233.62  # Public IPv4` → PowerShell đọc cả `52.199.233.62  # Public IPv4` làm giá trị hostname → SSH thất bại.

**Cách sửa**: **Không dùng inline comment** trong `.env.deploy`. Comment phải ở dòng riêng (`# comment` trên dòng trước).

### 5. Mosquitto config sai directive

**Lỗi**: `mosquitto.conf` có 2 vấn đề:

- `keepalive_interval 60` → không phải broker option (chỉ dùng cho bridge config) → Mosquitto báo `Error: Invalid bridge configuration` ở line đó.
- `message_size_limit 65536` → deprecated trong Mosquitto 2.x.

**Cách sửa**: Xoá `keepalive_interval` (không cần thiết cho broker), đổi `message_size_limit` thành `max_packet_size`.

### 6. Port conflict trên EC2 (native Mosquitto vs Docker)

**Lỗi**: EC2 Ubuntu có sẵn Mosquitto cài qua `apt` chạy dưới dạng systemd service, chiếm port 1883 → Docker container `sb-mosquitto` không bind được port.

**Cách sửa**: `sudo systemctl stop mosquitto && sudo systemctl disable mosquitto` trước khi chạy Docker. Deploy script nên kiểm tra và xử lý tự động.

### 7. Docker healthcheck thiếu credentials

**Lỗi**: Healthcheck dùng `mosquitto_sub -h localhost -t '$SYS/broker/uptime' -C 1 -W 3` nhưng broker set `allow_anonymous false` → healthcheck bị `Connection Refused: not authorised` → container mãi ở trạng thái `unhealthy` → cloud-api (depends_on: service_healthy) không bao giờ start.

**Cách sửa**: Thêm credentials vào healthcheck: `mosquitto_sub -h localhost -u monitor -P monitor123 -t '$$SYS/broker/uptime' -C 1 -W 3`. Đồng thời cập nhật ACL cho user `monitor` được đọc `$SYS/#`.

### 8. ACL quá hẹp cho healthcheck

**Lỗi**: User `monitor` chỉ có `pattern read $SYS/broker/load/#` và `pattern read $SYS/broker/clients/+` → không match `$SYS/broker/uptime` → healthcheck vẫn bị từ chối dù đã có credentials.

**Cách sửa**: Đổi ACL của monitor thành `topic read $SYS/#` để cover tất cả `$SYS` subtopics.

### 9. Port 8000 bị chiếm bởi process cũ

**Lỗi**: Một tiến trình `uvicorn` cũ (chạy manual trước đó) vẫn đang chiếm port 8000 → Docker container `sb-cloud-api` không bind được.

**Cách sửa**: `sudo lsof -i :8000` để tìm PID, rồi `sudo kill <PID>`. Deploy script nên kiểm tra port trước khi `docker compose up`.

### 10. docker-compose.prod.yml có `version` key lỗi thời

**Lỗi**: `version: "3.8"` gây warning `the attribute 'version' is obsolete` trên Docker Compose V2.

**Cách sửa**: Xoá dòng `version: "3.8"`. Docker Compose V2 không cần key này.

### Checklist trước khi deploy

```bash
# Trên EC2, kiểm tra trước khi docker compose up:
sudo systemctl status mosquitto    # Phải inactive, nếu active → stop & disable
sudo lsof -i :1883                 # Phải trống
sudo lsof -i :8000                 # Phải trống
```
