# Cloud Backend

FastAPI REST API + MQTT subscriber/publisher cho cloud-side device management.

## Stack

- **FastAPI** + **SQLAlchemy 2.0** async + **asyncpg** (PostgreSQL)
- **Paho MQTT** subscriber + publisher
- **Pydantic v2** settings + schemas

## Cấu trúc

```
cloud/
├── app/
│   ├── main.py           # FastAPI app + lifespan (init DB + MQTT)
│   ├── config.py          # pydantic-settings (SB_ env prefix)
│   ├── database.py        # SQLAlchemy async engine + session factory
│   ├── models.py          # 7 ORM tables (homes, rooms, users, devices, device_states, events, commands)
│   ├── schemas.py         # Pydantic request/response schemas
│   ├── mqtt_client.py     # MQTT subscriber (reported/event/reply → DB) + command publisher
│   ├── seed.py            # Seed script (1 home, 2 rooms, 3 devices, 1 user)
│   └── routers/
│       ├── health.py      # GET /health
│       ├── devices.py     # GET /api/devices, /{id}, /{id}/state
│       ├── events.py      # GET /api/events
│       └── commands.py    # POST command + GET status
├── Dockerfile
├── requirements.txt
└── .env.example
```

## Chạy local

### 1. Bật Postgres + Mosquitto (Docker)

```bash
# Postgres
docker run -d --name sb-postgres -p 5432:5432 \
  -e POSTGRES_USER=sb_user -e POSTGRES_PASSWORD=sb_pass -e POSTGRES_DB=sb_cloud \
  postgres:16-alpine

# Mosquitto (từ repo)
cd mqtt/docker && docker compose up -d
```

### 2. Cài deps + chạy API

```bash
pip install -r cloud/requirements.txt

# (tuỳ chọn) Seed sample data — 1 home, 2 rooms, 3 devices
python -m cloud.app.seed

# Chạy API (auto reload)
python -m cloud
```

Swagger UI: http://localhost:8000/docs

### 3. Test

```bash
# Unit tests — dùng sqlite in-memory, không cần Postgres/MQTT
pytest cloud/tests/ -v

# End-to-end smoke test — cần Postgres + Mosquitto + API chạy
python cloud/scripts/smoke_test.py
```

## Deploy lên EC2 (AWS)

Stack production gồm 3 container: `sb-postgres` + `sb-mosquitto` + `sb-cloud-api`,
được orchestrate bằng `deploy/docker-compose.prod.yml` trên EC2 Ubuntu.

### Yêu cầu

- EC2 Ubuntu 22.04+ (Docker + Docker Compose v2 cài sẵn — dùng `deploy/ec2-setup.ps1` nếu là lần đầu)
- Security group mở port **8000** (API) và **1883** (MQTT)
- Trên máy dev: PowerShell 5+, SSH client, `tar` (Windows 10+ có sẵn)
- Private key (.pem) để SSH vào EC2

### Các bước

```powershell
# 1) Copy file cấu hình mẫu và điền thông số EC2 của bạn
cp deploy\.env.deploy.example deploy\.env.deploy
# Mở file bằng editor và set: EC2_HOST, EC2_KEY, các password MQTT/Postgres
# LƯU Ý: không thêm inline comment (# ...) trong file .env.deploy

# 2) (Lần đầu tiên) cài Docker + dừng Mosquitto native trên EC2
powershell -ExecutionPolicy Bypass -File deploy\ec2-setup.ps1

# 3) Deploy: đóng gói code, upload qua scp, build + docker compose up
powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1

# 4) Seed dữ liệu mẫu trên EC2 (1 home, 2 rooms, 3 devices)
powershell -ExecutionPolicy Bypass -File deploy\seed-remote.ps1

# 5) Tiện ích
powershell -File deploy\logs.ps1               # xem log tất cả container
powershell -File deploy\logs.ps1 cloud-api     # log cloud-api
powershell -File deploy\ssh.ps1                # SSH vào EC2
```

Sau khi deploy thành công:

- API Swagger: `http://<EC2_HOST>:8000/docs`
- Health: `http://<EC2_HOST>:8000/health`
- MQTT broker: `<EC2_HOST>:1883`

### Database migration

`init_db()` chạy tự động khi container cloud-api khởi động:

- `create_all` — tạo bảng còn thiếu (không đụng bảng đã có).
- ALTER TABLE IF NOT EXISTS — thêm cột mới (`timeout_ms`, `expires_at`) an toàn trên Postgres hiện hữu.

Nếu cần reset hoàn toàn DB (mất data):

```bash
# Trên EC2:
cd /home/ubuntu/iot-platform/deploy
docker compose -f docker-compose.prod.yml down -v    # -v xoá volume
docker compose -f docker-compose.prod.yml up -d
```

### Troubleshooting deploy

Xem mục **Known Issues** trong `CLAUDE.md` ở root (CRLF heredoc, UTF-8 BOM, port
conflict mosquitto native, Docker healthcheck thiếu credentials, v.v.).

Lỗi hay gặp và fix nhanh:

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| `tar: Cannot connect to C:` khi deploy từ Windows | GNU tar của Git Bash parse `C:\...` như remote host | `deploy.ps1` đã fallback sang pipe stdout — chạy lại |
| `sb-cloud-api` không start do `sb-mosquitto` unhealthy | ACL `monitor` không cover `$SYS/broker/uptime` | `acl.conf` phải có `topic read $SYS/#` cho user `monitor` |
| Port 1883 conflict | Mosquitto systemd trên EC2 | `sudo systemctl stop mosquitto && sudo systemctl disable mosquitto` |
| Cloud API báo `relation "commands" does not exist` | Container start trước khi Postgres ready | Compose đã có `depends_on: postgres service_healthy`; thử `docker compose restart cloud-api` |

## API Endpoints

| Method | Path | Mô tả |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/api/devices` | Danh sách devices (`?room_id=`) |
| GET | `/api/devices/{device_id}` | Chi tiết device |
| GET | `/api/devices/{device_id}/state` | State mới nhất |
| POST | `/api/devices/{device_id}/command` | Gửi command → MQTT publish |
| GET | `/api/commands/{command_id}` | Trạng thái command |
| GET | `/api/events` | Lịch sử events (`?device_id=&event_type=&limit=&offset=`) |

## MQTT Integration

**Subscribe** (nhận từ gateway):
- `sb/v1/{tenant}/{site}/{gw}/devices/+/reported` → Upsert device + ghi state
- `sb/v1/{tenant}/{site}/{gw}/devices/+/event` → Ghi event
- `sb/v1/{tenant}/{site}/{gw}/commands/+/reply` → Cập nhật command status
- `sb/v1/{tenant}/{site}/{gw}/gateway/online` → Log

**Publish** (gửi đến gateway):
- `sb/v1/{tenant}/{site}/{gw}/commands/{cmd_id}/request` → Khi POST command

## Cấu hình (Environment Variables)

| Biến | Default | Mô tả |
|---|---|---|
| `SB_DATABASE_URL` | `postgresql+asyncpg://sb_user:sb_pass@localhost:5432/sb_cloud` | Database URL |
| `SB_MQTT_HOST` | `localhost` | MQTT broker host |
| `SB_MQTT_PORT` | `1883` | MQTT broker port |
| `SB_MQTT_USERNAME` | `client` | MQTT username |
| `SB_MQTT_PASSWORD` | `client` | MQTT password |
| `SB_TENANT_ID` | `hust` | Tenant ID |
| `SB_SITE_ID` | `lab01` | Site ID |
| `SB_GATEWAY_ID` | `gw-ubuntu-01` | Home hub identifier |
| `SB_API_HOST` | `0.0.0.0` | API bind host |
| `SB_API_PORT` | `8000` | API bind port |

## Database Schema

```
homes ──── rooms ──── devices ──┬── device_states
  │                              ├── events
  └── users                      └── commands
```

7 bảng: `homes`, `rooms`, `users`, `devices`, `device_states`, `events`, `commands`
