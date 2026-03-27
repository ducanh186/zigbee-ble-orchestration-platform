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

```bash
# Cài dependencies
pip install -r cloud/requirements.txt

# Seed sample data
python -m cloud.app.seed

# Chạy API server (dev mode)
python -m cloud
```

Swagger UI: http://localhost:8000/docs

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
| `SB_GATEWAY_ID` | `gw-ubuntu-01` | Gateway ID |
| `SB_API_HOST` | `0.0.0.0` | API bind host |
| `SB_API_PORT` | `8000` | API bind port |

## Database Schema

```
homes ──── rooms ──── devices ──┬── device_states
  │                              ├── events
  └── users                      └── commands
```

7 bảng: `homes`, `rooms`, `users`, `devices`, `device_states`, `events`, `commands`
