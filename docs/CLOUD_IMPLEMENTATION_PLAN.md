# Cloud Backend Implementation Plan

> **Phase B**: Database + API skeleton — runnable without Gateway
> **Stack**: FastAPI + SQLAlchemy + SQLite (→ PostgreSQL later) + Paho MQTT
> **Deploy target**: AWS EC2 via CLI

## Directory Structure

```
cloud/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app + lifespan (MQTT client start)
│   ├── config.py             # Settings from .env
│   ├── database.py           # SQLAlchemy engine + session
│   ├── models.py             # ORM models
│   ├── schemas.py            # Pydantic request/response schemas
│   ├── mqtt_client.py        # MQTT subscriber + command publisher
│   ├── seed.py               # Seed script: sample home/room/device
│   └── routers/
│       ├── __init__.py
│       ├── devices.py        # /api/devices/*
│       ├── events.py         # /api/events
│       ├── commands.py       # /api/devices/{id}/command
│       └── health.py         # /health
├── alembic/                  # DB migrations (later)
├── requirements.txt
├── .env.example
└── Dockerfile
```

## Database Schema

### Tables

```
homes
  id            TEXT PK (uuid)
  name          TEXT NOT NULL
  created_at    DATETIME DEFAULT now

rooms
  id            TEXT PK (uuid)
  home_id       TEXT FK -> homes.id
  name          TEXT NOT NULL
  created_at    DATETIME DEFAULT now

users
  id            TEXT PK (uuid)
  username      TEXT UNIQUE NOT NULL
  home_id       TEXT FK -> homes.id
  created_at    DATETIME DEFAULT now

devices
  id            TEXT PK (device_id, e.g. "light-01")
  device_type   TEXT NOT NULL (light, occupancy_sensor, switch, etc.)
  eui64         TEXT
  room_id       TEXT FK -> rooms.id NULLABLE
  name          TEXT
  is_online     BOOLEAN DEFAULT true
  created_at    DATETIME DEFAULT now
  updated_at    DATETIME DEFAULT now

device_states
  id            INTEGER PK AUTOINCREMENT
  device_id     TEXT FK -> devices.id
  state         JSON NOT NULL
  reported_at   DATETIME NOT NULL
  created_at    DATETIME DEFAULT now
  INDEX(device_id, reported_at DESC)

events
  id            INTEGER PK AUTOINCREMENT
  device_id     TEXT FK -> devices.id NULLABLE
  event_type    TEXT NOT NULL
  payload       JSON NOT NULL
  occurred_at   DATETIME NOT NULL
  created_at    DATETIME DEFAULT now
  INDEX(device_id, occurred_at DESC)

commands
  id            TEXT PK (command_id uuid)
  device_id     TEXT FK -> devices.id
  op            TEXT NOT NULL
  target        JSON NOT NULL
  status        TEXT NOT NULL DEFAULT 'accepted'
             -- accepted | queued | sent | executed | failed | timeout
  reason        TEXT NULLABLE
  created_at    DATETIME DEFAULT now
  updated_at    DATETIME DEFAULT now
  INDEX(device_id, created_at DESC)
```

## API Endpoints

### Group 1 — Must have (this sprint)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Healthcheck |
| GET | `/api/devices` | List all devices (optional `?room_id=`) |
| GET | `/api/devices/{device_id}` | Device detail |
| GET | `/api/devices/{device_id}/state` | Latest reported state |
| POST | `/api/devices/{device_id}/command` | Send command → publish MQTT |
| GET | `/api/events` | Event history (`?device_id=&type=&limit=&offset=`) |
| GET | `/api/commands/{command_id}` | Command status |

### Group 2 — Later

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Stub / fake token |
| GET | `/api/rooms` | List rooms |
| GET | `/api/homes` | List homes |
| Full pagination / filtering | | |

## MQTT Integration

### Subscriber — topics to listen

Using MQTT contract namespace: `sb/v1/{tenant}/{site}/{gw}/...`

| Topic pattern | Action |
|---------------|--------|
| `.../devices/+/reported` | Upsert device + insert device_state row |
| `.../devices/+/event` | Insert event row |
| `.../commands/+/reply` | Update command status |
| `.../gateway/online` | Log gateway connectivity |
| `.../gateway/health` | Log gateway health |

### Publisher — on API command

When `POST /api/devices/{id}/command`:
1. Create command row (status=accepted)
2. Publish to `sb/v1/{tenant}/{site}/{gw}/commands/{cmd_id}/request`
3. Return command_id to caller

## State Enums (frozen)

```
Light:       on | off | unreachable
Occupancy:   occupied | unoccupied | unreachable
Lock:        locked | unlocked | jammed | unreachable
Command:     accepted | queued | sent | executed | failed | timeout
```

## Seed Data

```
Home: "HUST Lab" (id: home-01)
  Room: "Lab 01" (id: room-01)
    Device: light-01 (light)
    Device: pir-01 (occupancy_sensor)
  Room: "Lab 02" (id: room-02)
    Device: light-02 (light)
User: admin (home_id: home-01)
```

## Deliverables Checklist

- [ ] FastAPI app boots, Swagger at `/docs`
- [ ] DB tables created via SQLAlchemy
- [ ] Seed script populates sample data
- [ ] All Group 1 APIs return valid responses
- [ ] MQTT subscriber receives state → writes DB
- [ ] POST /command → MQTT publish works
- [ ] Mock script: `mosquitto_pub` state → DB row appears
- [ ] Mock script: fake ack → command status updates
