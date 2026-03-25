# IoT Smart Building Platform

Nền tảng quản lý thiết bị IoT Zigbee/BLE cho tòa nhà thông minh, xây dựng trên kiến trúc Z3Gateway-native.

## Kiến trúc

```
Flutter App ──HTTP──▶ Cloud API (FastAPI :8000) ◄──▶ Mosquitto (:1883) ◄──MQTT──▶ Gateway Bridge ◄──IPC──▶ Z3Gateway ◄──EZSP/ASH──▶ EFR32 NCP ◄──Zigbee──▶ End Devices
                           │ SQLite
                           ▼
                        cloud.db
```

| Thành phần | Mô tả | Trạng thái |
|---|---|---|
| **Gateway Bridge** (`gateway/`) | Cầu nối MQTT ↔ IPC, chạy trên Linux cạnh coordinator Zigbee | Done |
| **Cloud Backend** (`cloud/`) | FastAPI REST API + MQTT subscriber, quản lý device/state/command | Done |
| **MQTT Broker** (`mqtt/`) | Mosquitto broker config + Docker Compose | Done |
| **Deploy Scripts** (`deploy/`) | Auto deploy lên AWS EC2 từ Windows (PowerShell) | Done |

## Cấu trúc repository

```
gateway/          Gateway MQTT ↔ IPC bridge (Python, Linux runtime)
cloud/            Cloud backend — FastAPI REST API + MQTT subscriber (Python)
mqtt/             Local Mosquitto broker configuration
deploy/           EC2 deployment scripts (PowerShell) + docker-compose
docs/             Architecture contracts, sprint plan, implementation plans
end_devices/      End device firmware (placeholder)
mobile_app/       Mobile app code (placeholder)
```

## Quick Start

### 1. MQTT Broker (local)

```bash
cd mqtt/docker
docker compose up -d
```

### 2. Cloud Backend

```bash
pip install -r cloud/requirements.txt
python -m cloud.app.seed          # Seed sample data
python -m cloud                   # API server → http://localhost:8000/docs
```

### 3. Gateway Bridge

```bash
pip install -r gateway/requirements.txt
cp gateway/.env.example gateway/.env
python -m gateway
```

### 4. Tests

```bash
pytest gateway/tests/ -v
```

## Deploy lên EC2

```powershell
# Cấu hình (1 lần)
cp deploy\.env.deploy.example deploy\.env.deploy
# Sửa: EC2_HOST, EC2_KEY, MQTT passwords

# Setup EC2 (1 lần)
powershell -ExecutionPolicy Bypass -File deploy\ec2-setup.ps1

# Deploy (mỗi lần update code)
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
```

Chi tiết: xem [SUMMARY.md](SUMMARY.md)

## API Endpoints

| Method | Path | Mô tả |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/api/devices` | Danh sách devices (optional `?room_id=`) |
| GET | `/api/devices/{device_id}` | Chi tiết device |
| GET | `/api/devices/{device_id}/state` | State mới nhất |
| POST | `/api/devices/{device_id}/command` | Gửi command |
| GET | `/api/commands/{command_id}` | Trạng thái command |
| GET | `/api/events` | Lịch sử events |

## Tài liệu

| File | Nội dung |
|---|---|
| [SUMMARY.md](SUMMARY.md) | Tổng kết toàn bộ dự án (hướng dẫn chi tiết, API reference, DB schema, MQTT) |
| [CLAUDE.md](CLAUDE.md) | Hướng dẫn cho AI assistant (kiến trúc, contracts, dev commands) |
| [docs/MQTT_CONTRACT.md](docs/MQTT_CONTRACT.md) | MQTT topic tree, envelope, QoS, retain |
| [docs/UART_FRAME_FORMAT.md](docs/UART_FRAME_FORMAT.md) | IPC boundary (NDJSON over Unix socket) |
| [docs/OTA_CAMPAIGN_CONTRACT.md](docs/OTA_CAMPAIGN_CONTRACT.md) | OTA artifact staging workflow |
| [docs/CLOUD_IMPLEMENTATION_PLAN.md](docs/CLOUD_IMPLEMENTATION_PLAN.md) | Cloud DB schema + API design |

## Git Workflow Rules

### Branch Naming

- Format: `prefix/<jira-ticket-id>-<branch-description>`
- Allowed prefix: `feature`, `bugfix`
- Ví dụ: `feature/1-create-code-base`

### Pull Request Rules

- Tất cả code phải merge vào `main` qua pull request.
- Không được commit/merge trực tiếp vào `main`.
- Mỗi pull request phải được approve trước khi merge.