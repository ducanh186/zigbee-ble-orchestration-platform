# IoT Zigbee Smart Building — Sprint Plan

> **Team:** 2 người | **Kit:** EFR32 (Silicon Labs) | **IDE:** Simplicity Studio (C)  
> **Cloud:** AWS EC2 (Mosquitto + FastAPI) | **App:** Flutter  
> **Sensor:** PIR Occupancy | **Session:** 3 ngày / phase

## Mục lục

- [Phân công Team](#phân-công-team)
- [Tech Stack](#tech-stack)
- [Extensibility — Thêm Node Mới](#extensibility--thêm-node-mới)
- [Phase 0 — Planning & System Contract (Day 1–3)](#phase-0--planning--system-contract-day-13)
- [Phase 1 — Zigbee Local Network MVP (Day 4–6)](#phase-1--zigbee-local-network-mvp-day-46)
- [Phase 2 — Gateway Bridge MVP (Day 7–9)](#phase-2--gateway-bridge-mvp-day-79)
- [Phase 3 — Cloud + Local Automation (Day 10–12)](#phase-3--cloud--local-automation-day-1012)
- [Phase 4 — Mobile App MVP + E2E Demo (Day 13–15)](#phase-4--mobile-app-mvp--e2e-demo-day-1315)
- [Phase 5 — Smart Behavior & Polish (Day 16–18) [High Level]](#phase-5--smart-behavior--polish-day-1618-high-level)
- [Phase 6 — Advanced Features (Day 19–21) [High Level]](#phase-6--advanced-features-day-1921-high-level)
- [Phase 7 — Deployment & Hardening (Day 22–24) [High Level]](#phase-7--deployment--hardening-day-2224-high-level)
- [Timeline Summary](#timeline-summary)
- [Giao diện giữa 2 người (Contract Boundaries)](#giao-diện-giữa-2-người-contract-boundaries)

---

## Phân công Team

| Mốc | Person A (có Kit từ đầu) | Person B (không có Kit tuần 1) |
|---|---|---|
| **Tuần 1** | Firmware EFR32, hardware test, UART | Gateway Python, contracts, docs, EC2 setup |
| **Tuần 2+** | Cả 2 đều có kit — chia theo module | Theo ownership module |

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Zigbee Nodes | EFR32 (Silicon Labs) | Simplicity Studio, EmberZNet stack, C |
| Coordinator | EFR32 (NCP mode) | Z3Gateway hoặc custom NCP, UART to host |
| Gateway Host | Linux laptop → RPi later | Python 3.10+, PySerial, Paho MQTT |
| MQTT Broker | Mosquitto on AWS EC2 | Port 1883 → 8883 TLS later |
| Cloud Backend | FastAPI on EC2 | REST API + MQTT subscriber |
| Database | SQLite → PostgreSQL later | On EC2 |
| Mobile App | Flutter | Provider/Riverpod, HTTP to EC2 API |
| Version Control | Git (GitHub) | main, develop, feature/*, firmware/* |

---

## Extensibility — Thêm Node Mới

Cấu trúc gateway theo plugin pattern:

```
gateway/
├── devices/
│   ├── registry.py            # device_type → handler mapping
│   ├── base_handler.py        # abstract class
│   ├── light_handler.py       # On/Off + Level Control
│   ├── switch_handler.py      # Button events
│   └── occupancy_handler.py   # PIR occupied/unoccupied
├── uart/
│   ├── parser.py              # Parse @DATA, @CMD, @ACK
│   └── serial_manager.py      # Connect, reconnect, queue
├── mqtt/
│   ├── bridge.py              # Publish/Subscribe
│   └── topics.py              # Topic naming convention
├── automation/
│   ├── engine.py              # Rule evaluation
│   └── rules.json             # Declarative rules
└── config.py
```

**Khi thêm node mới (VD: Temperature Sensor):**

| Step | Layer | Việc cần làm | Ví dụ |
|---|---|---|---|
| 1 | Firmware (C) | Tạo project mới, thêm ZCL cluster, flash EFR32 | Temperature Measurement cluster (0x0402) |
| 2 | Coordinator | Không cần sửa — đã forward mọi @DATA generic | Tự forward attribute report |
| 3 | Gateway: Handler | Tạo `temperature_handler.py` extends `base_handler` | parse cluster 0x0402, convert °C |
| 4 | Gateway: Registry | Thêm 1 dòng vào `registry.py` | `register('temp_sensor', TempHandler)` |
| 5 | MQTT Topics | Tự generate theo convention, không sửa code | `home/1/device/temp_001/state` |
| 6 | Cloud DB | Schema generic (JSON value), không cần migration | `{temperature: 23.5}` |
| 7 | Cloud API | GET /devices/{id}/state đã hoạt động cho mọi device | Không sửa |
| 8 | App | Thêm 1 Flutter widget cho device type mới | `TemperatureCard` widget |

**→ Không sửa gateway core, UART parser, hay MQTT bridge.**

---

## Phase 0 — Planning & System Contract (Day 1–3)

**Goal:** Chốt architecture, contract, scope. Sau phase này 2 người làm không đụng nhau.

### Person A (có Kit)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-001 | Kiểm tra kit EFR32: flash test firmware, verify UART output | 3 | Highest | Board boot OK; UART output visible trên terminal |
| IOT-002 | Xác nhận pin mapping EFR32 cho Light/Switch/PIR | 2 | Highest | Pin mapping doc: GPIO cho LED, button, PIR input |
| IOT-003 | Tạo Simplicity Studio project cho Coordinator (NCP) | 3 | Highest | Project build thành công, firmware flash OK |
| IOT-004 | Thiết kế UART frame format: `@DATA`, `@CMD`, `@ACK`, `@INFO` | 3 | Highest | Contract doc reviewed bởi Person B |

### Person B (không có Kit)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-005 | Vẽ architecture diagram (Zigbee→Gateway→MQTT→EC2→App) | 3 | Highest | Diagram có mũi tên data flow, reviewed |
| IOT-006 | Viết MQTT topic contract + JSON payload schema | 3 | Highest | Topic contract doc hoàn thành |
| IOT-007 | Viết device ID + naming convention doc | 2 | High | Convention doc: device_id format, endpoint numbering |
| IOT-008 | Setup Jira backlog: Epics + import tasks Phase 0–2 | 2 | High | Board có đầy đủ tickets |
| IOT-009 | Setup Git repo structure | 2 | High | Repo ready, README + .gitignore |
| IOT-010 | Setup AWS EC2: Mosquitto MQTT broker + backend skeleton | 3 | High | Mosquitto running; pub/sub test OK từ local |

### Contracts cần chốt

**UART Frame Format:**
```
@DATA|{device_id}|{endpoint}|{cluster_id}|{attr_id}|{value}|{timestamp}
@CMD|{command_id}|{device_id}|{endpoint}|{cluster_id}|{command}|{params}
@ACK|{command_id}|{status}|{timestamp}
@INFO|{event}|{device_id}|{details}
```

**MQTT Topics:**
```
home/{home_id}/device/{device_id}/state      # Gateway → Cloud (telemetry)
home/{home_id}/device/{device_id}/command    # Cloud → Gateway (control)
home/{home_id}/device/{device_id}/ack        # Gateway → Cloud (response)
home/{home_id}/device/{device_id}/event      # Gateway → Cloud (join/leave/error)
```

**JSON Payload (state):**
```json
{
  "device_id": "0x1A2B",
  "device_type": "light",
  "endpoint": 1,
  "attributes": {
    "on_off": true
  },
  "timestamp": "2025-03-17T10:30:00Z",
  "rssi": -45
}
```

### Deliverables Phase 0
- [ ] Architecture diagram
- [ ] UART contract doc
- [ ] MQTT topic contract + JSON schema
- [ ] Naming convention doc
- [ ] Git repo ready
- [ ] EC2 Mosquitto running
- [ ] Jira backlog populated

---

## Phase 1 — Zigbee Local Network MVP (Day 4–6)

**Goal:** 3 node join network, switch điều khiển light cục bộ.

### Person A (Firmware — C trên Simplicity Studio)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-011 | Coordinator firmware: network formation + Trust Center + permit join | 5 | Highest | Network form; PAN ID visible; permit join controllable |
| IOT-012 | Light device firmware: On/Off cluster server (ZCL 0x0006) | 5 | Highest | Light join network; LED toggles on command |
| IOT-013 | Switch device firmware: On/Off client cluster + button handler | 4 | Highest | Switch join; button press → toggle command |
| IOT-014 | Zigbee binding test: switch → light direct control | 3 | Highest | Bấm switch → light bật/tắt; persistent sau reset |
| IOT-015 | Coordinator UART output: gửi `@DATA` khi nhận state change | 4 | Highest | UART log hiện đúng format khi light toggle |

**Firmware notes:**
- Coordinator: EmberZNet NCP hoặc Z3Gateway, EFR32 board
- Light: Zigbee Router (cấp nguồn liên tục), On/Off server cluster
- Switch: Zigbee End Device hoặc Router, On/Off client cluster
- Tất cả dùng Simplicity Studio IDE, EmberZNet Zigbee stack, C language

### Person B (Gateway Python — offline với mock data)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-016 | Gateway: `base_handler.py` — abstract device handler class | 3 | Highest | Abstract methods: `parse_state()`, `generate_command()`, `to_mqtt_payload()` |
| IOT-017 | Gateway: `registry.py` — device type registration system | 2 | Highest | Register/lookup by device_type; dynamic registration |
| IOT-018 | Gateway: `light_handler.py` — parse light state, generate command | 3 | Highest | Unit test pass; parse On/Off; generate toggle/on/off |
| IOT-019 | Gateway: `switch_handler.py` — parse switch button events | 2 | High | Unit test pass |
| IOT-020 | Gateway: UART parser (`parser.py`) — parse `@DATA`, build `@CMD` | 4 | Highest | Parser test với mock data pass; handle malformed frames |
| IOT-021 | Gateway: `serial_manager.py` — serial connect, reconnect, read loop | 3 | Highest | Connect/disconnect test pass; auto-reconnect |
| IOT-022 | Gateway: mock UART data generator cho offline testing | 2 | Medium | Mock tool generates realistic @DATA frames |

### Deliverables Phase 1
- [ ] Zigbee network: coordinator + light + switch join OK
- [ ] Direct binding: switch → light hoạt động
- [ ] Coordinator gửi @DATA qua UART
- [ ] Gateway code skeleton tested với mock data

---

## Phase 2 — Gateway Bridge MVP (Day 7–9)

**Goal:** Zigbee ↔ UART ↔ MQTT chạy xuyên suốt đến EC2.

### Person A (Firmware + UART integration)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-023 | PIR Occupancy sensor firmware: Occupancy Sensing cluster (ZCL 0x0406) | 5 | Highest | PIR join; report occupied/unoccupied; debounce PIR signal |
| IOT-024 | Coordinator: forward occupancy event qua UART `@DATA` | 3 | Highest | `@DATA` hiện occupancy state khi PIR trigger |
| IOT-025 | Coordinator: nhận `@CMD` từ UART → gửi Zigbee command | 5 | Highest | Gateway gửi `@CMD` → light bật/tắt |
| IOT-026 | Coordinator: gửi `@ACK` sau khi command thực thi | 3 | Highest | `@ACK` visible trên UART; include success/fail |
| IOT-027 | E2E test: PIR trigger → UART → gateway terminal log | 2 | High | Wave hand → gateway log shows event < 1s |

**PIR Sensor notes:**
- Cluster: Occupancy Sensing (0x0406) — ZCL standard
- PIR output → GPIO input trên EFR32
- Configurable timeout trước khi chuyển unoccupied (VD: 30s)
- Attribute reporting: on change + periodic (backup)

### Person B (Gateway MQTT + Pipeline)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-028 | Gateway: MQTT bridge (`bridge.py`) — publish state, subscribe command | 5 | Highest | Publish to EC2 Mosquitto OK; subscribe command topic OK |
| IOT-029 | Gateway: `topics.py` — topic naming + payload serialization | 2 | High | Topics match contract doc |
| IOT-030 | Gateway: `occupancy_handler.py` — extends base_handler | 3 | Highest | Handler registered; parse occupied/unoccupied; test pass |
| IOT-031 | Gateway: device registry persistence (JSON file) | 3 | High | Registry survives restart; load from `devices.json` |
| IOT-032 | Gateway: integrate UART ↔ MQTT full pipeline | 4 | Highest | State: Zigbee → UART → parser → handler → MQTT on EC2 |
| IOT-033 | Gateway: command pipeline MQTT → UART → Zigbee → ACK → MQTT | 4 | Highest | MQTT command → `@CMD` → Zigbee → `@ACK` → MQTT ack; < 2s |

### Deliverables Phase 2
- [ ] PIR sensor join + report occupancy
- [ ] Gateway bridge: Zigbee ↔ MQTT 2 chiều
- [ ] Device registry persistent
- [ ] Command + ACK round-trip hoạt động
- [ ] Data visible trên EC2 MQTT broker

---

## Phase 3 — Cloud + Local Automation (Day 10–12)

**Goal:** Automation local chạy offline. Cloud lưu state + history. API sẵn sàng cho app.

### Person A (Gateway automation + reliability)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-034 | Gateway: automation engine — load rules từ `rules.json` | 4 | Highest | Engine load rules OK; rule format documented |
| IOT-035 | Gateway: rule `occupancy==occupied` → light on | 3 | Highest | PIR detect → light bật < 1s; no cloud dependency |
| IOT-036 | Gateway: rule `unoccupied for X sec` → light off (timeout) | 3 | Highest | Timer works; reset if re-occupied; timeout configurable |
| IOT-037 | Gateway: reconnect UART + MQTT khi mất kết nối | 3 | High | Rút cable → cắm lại → auto reconnect |
| IOT-038 | Gateway: comprehensive logging | 3 | High | Log: device join/leave, cmd, ack, errors, rule executions |

**rules.json example:**
```json
{
  "rules": [
    {
      "name": "occupancy_light_on",
      "trigger": {
        "device_type": "occupancy_sensor",
        "attribute": "occupied",
        "condition": "equals",
        "value": true
      },
      "action": {
        "target_type": "light",
        "target_room": "same",
        "command": "on"
      }
    },
    {
      "name": "vacancy_light_off",
      "trigger": {
        "device_type": "occupancy_sensor",
        "attribute": "occupied",
        "condition": "equals",
        "value": false
      },
      "action": {
        "target_type": "light",
        "target_room": "same",
        "command": "off"
      },
      "delay_seconds": 120
    }
  ]
}
```

### Person B (Cloud on EC2)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-039 | EC2: Database schema (SQLite/PostgreSQL) | 3 | Highest | Tables: devices, device_states, events, homes, rooms, users |
| IOT-040 | EC2: MQTT subscriber — receive telemetry → write to DB | 4 | Highest | Gateway publish → DB row created; verified by query |
| IOT-041 | EC2: REST API (FastAPI) — devices, state, command, events | 5 | Highest | Postman test pass: GET /devices, POST /command → MQTT |
| IOT-042 | EC2: Event history API with filtering | 3 | High | `GET /events?device_id=X&type=occupancy&from=...&to=...` |
| IOT-043 | EC2: User-home-room data model + seed data | 2 | Medium | 1 user → 1 home → rooms → devices; seed script |

**EC2 API endpoints:**
```
GET    /api/devices                      # List all devices
GET    /api/devices/{id}                 # Device detail
GET    /api/devices/{id}/state           # Latest state
POST   /api/devices/{id}/command         # Send command → MQTT
GET    /api/events                       # Event history (paginated)
GET    /api/rooms                        # List rooms
POST   /api/auth/login                   # Login → token
```

### Deliverables Phase 3
- [ ] Local automation: occupancy → light works offline
- [ ] Cloud: device state synced real-time
- [ ] Event history stored + queryable
- [ ] REST API fully tested
- [ ] Gateway auto-reconnect working

---

## Phase 4 — Mobile App MVP + E2E Demo (Day 13–15)

**Goal:** App điều khiển được. 3 demo scenarios chạy ổn định. Evidence cho báo cáo.

### Person A (Integration testing + demo)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-044 | Demo 1: occupancy → gateway rule → light on → app sees state | 3 | Highest | Chạy 3 lần không crash; video recorded |
| IOT-045 | Demo 2: app button → command → light toggles → ack on app | 3 | Highest | Round-trip < 2s; video recorded |
| IOT-046 | Demo 3: mất internet → local automation vẫn chạy → sync lại | 3 | Highest | Wifi off → PIR works → wifi on → events sync |
| IOT-047 | Gateway: offline event cache + replay khi internet về | 4 | High | Events cached → replayed → no data loss |
| IOT-048 | Capture screenshots/video/logs cho báo cáo | 2 | High | Evidence folder đầy đủ 3 demos |

### Person B (Flutter app)

| ID | Task | Points | Priority | AC |
|---|---|---|---|---|
| IOT-049 | Flutter: bootstrap + navigation + project structure | 3 | Highest | App runs on emulator; navigation works |
| IOT-050 | Flutter: login/logout screen | 2 | High | Login → dashboard; logout → login screen |
| IOT-051 | Flutter: home dashboard — room list, device list, state | 4 | Highest | Dashboard shows rooms + devices + current state |
| IOT-052 | Flutter: light control screen — on/off toggle + status | 3 | Highest | Toggle → pending → success/fail feedback |
| IOT-053 | Flutter: occupancy monitor — real-time state | 3 | Highest | State updates on app within 2s of PIR trigger |
| IOT-054 | Flutter: error handling — timeout, offline banner | 2 | Medium | Network error → banner; timeout → retry option |

### Demo Scenarios

**Demo 1 — Local Automation:**
```
PIR detect motion → @DATA qua UART → gateway rule engine
→ light ON command → @CMD qua UART → coordinator → Zigbee → LED bật
→ state pushed to EC2 → app shows "Light: ON"
```

**Demo 2 — Remote Control:**
```
User tap "ON" in app → POST /api/devices/light_01/command
→ EC2 publish MQTT → gateway subscribe → @CMD → coordinator
→ Zigbee → LED bật → @ACK → MQTT → EC2 → app shows success
```

**Demo 3 — Offline Resilience:**
```
Disconnect gateway wifi → PIR detect → local rule still works
→ light bật/tắt normally → events queued in offline cache
→ Reconnect wifi → cached events replay to MQTT → EC2 receives all
```

### Deliverables Phase 4
- [ ] Flutter app functional: dashboard + light control + occupancy
- [ ] 3 demo scenarios pass (3 lần mỗi demo)
- [ ] Video evidence + logs + screenshots
- [ ] Offline cache + replay working

---

## Phase 5 — Smart Behavior & Polish (Day 16–18) [High Level]

> *Chi tiết sẽ được refine dựa trên kết quả Phase 0–4*

| ID | Task | Assignee | Priority |
|---|---|---|---|
| IOT-055 | Zigbee Groups support for multi-light control (groupcast) | Person A | Medium |
| IOT-056 | Zigbee Scenes support cho smart lighting presets | Person A | Medium |
| IOT-057 | Gateway health monitoring (device online/offline detection) | Person A | High |
| IOT-058 | Cloud: push notification (motion detected / device offline) | Person B | Medium |
| IOT-059 | App: event history screen with timeline view | Person B | Medium |

---

## Phase 6 — Advanced Features (Day 19–21) [High Level]

| ID | Task | Assignee | Priority |
|---|---|---|---|
| IOT-060 | OTA firmware update mechanism qua gateway | Person A | Low |
| IOT-061 | Light module 220V integration + relay control | Person A | Medium |
| IOT-062 | Cloud: WebSocket real-time push (replace polling) | Person B | Medium |
| IOT-063 | App: settings screen + automation rule configuration | Person B | Low |

---

## Phase 7 — Deployment & Hardening (Day 22–24) [High Level]

| ID | Task | Assignee | Priority |
|---|---|---|---|
| IOT-064 | Gateway migration: Linux laptop → Raspberry Pi | Person A | Medium |
| IOT-065 | MQTT over TLS + credential management | Person B | High |
| IOT-066 | Zigbee secure join (install code policy) | Person A | Medium |
| IOT-067 | Persistent logging + log rotation + backup config | Person B | Medium |
| IOT-068 | Final documentation + deployment checklist | Both | Highest |

---

## Timeline Summary

| Phase | Days | Focus | Key Output |
|---|---|---|---|
| **0** | 1–3 | Contract & Planning | Docs + repo + EC2 Mosquitto + Jira |
| **1** | 4–6 | Zigbee Local | 3 nodes join + switch→light + gateway code |
| **2** | 7–9 | Gateway Bridge | UART↔MQTT 2 chiều + PIR sensor |
| **3** | 10–12 | Cloud + Automation | EC2 API + local rules offline |
| **4** | 13–15 | App + Demo | Flutter app + 3 demo scenarios |
| **5** | 16–18 | Polish | Groups, scenes, health monitor |
| **6** | 19–21 | Advanced | OTA, 220V, WebSocket |
| **7** | 22–24 | Deploy | RPi, TLS, docs |

---

## Giao diện giữa 2 người (Contract Boundaries)

Để 2 người làm song song không đụng nhau, 3 contract sau phải **khóa từ Phase 0**:

```
┌─────────────┐     UART Contract      ┌─────────────┐
│  Person A   │ ◄──────────────────────► │  Person B   │
│  Firmware   │  @DATA/@CMD/@ACK/@INFO  │  Gateway    │
│  (C code)   │                         │  (Python)   │
└─────────────┘                         └──────┬──────┘
                                               │
                                          MQTT Contract
                                        topic + JSON schema
                                               │
                                        ┌──────▼──────┐
                                        │   EC2 Cloud  │
                                        │  (FastAPI)   │
                                        └──────┬──────┘
                                               │
                                          REST API Contract
                                        endpoints + response
                                               │
                                        ┌──────▼──────┐
                                        │  Flutter App │
                                        └─────────────┘
```

**Rule:** Nếu contract thay đổi → cả 2 người phải agree trước khi sửa.
