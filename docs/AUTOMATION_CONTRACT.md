# Automation Contract (v1)

Contract chính thức cho luồng automation rule giữa Cloud (FastAPI), Gateway (Z3Gateway C), và Mobile (Flutter). Mọi publisher / subscriber / consumer phải tuân thủ tài liệu này.

> Tài liệu liên quan: [MQTT_CONTRACT.md](./MQTT_CONTRACT.md), [CLOUD_IMPLEMENTATION_PLAN.md](./CLOUD_IMPLEMENTATION_PLAN.md), [automation-e2e-plan.md](./automation-e2e-plan.md), [AUTOMATION_USER_GUIDE.md](./AUTOMATION_USER_GUIDE.md).

---

## 1. Phạm vi và nguyên tắc

- Cloud là **source of truth** cho rule definition (table `automations`).
- Gateway là **runtime executor**: nhận retained `desired/automation/{id}`, eval trigger, publish `device.command` đến `commands/{cmd_id}/request`, và emit `gateway/event` với `event=automation_synced|automation_sync_failed|automation_executed`.
- Mobile chỉ gọi REST API; không tự eval rule cục bộ.
- Tất cả MQTT payload dùng envelope chuẩn ở [MQTT_CONTRACT.md §Envelope chung](./MQTT_CONTRACT.md). `payload` là inner block riêng cho từng topic, mô tả bên dưới.

### Implementation audit note — 2026-05-21

This section is the target contract. The current repo does not yet prove the
whole contract live:

- Cloud validates and stores automation rules, publishes retained
  `desired/automation/{id}`, and persists synthetic gateway lifecycle events in
  local tests.
- Gateway currently subscribes to `commands/+/request`; no
  `desired/automation/{id}` subscriber/parser was found in
  `gateway/Z3GatewayHost/app/`.
- Gateway switch handling observes switch `toggle` events, but the default
  switch-to-light relay is disabled because direct Zigbee binding owns that path.
- Motion occupancy is configured/discovered, but the current gateway app code did
  not show a published `occupancy_changed` event or reported motion state path.

Do not claim SCRUM-51 as fully live end-to-end until EC2 API evidence, MQTT
trace, gateway log, cloud DB rows, and mobile evidence all come from the same
hardware/demo run.

---

## 2. Event catalogue (hard-coded MVP)

Trigger event hợp lệ trên Cloud API + Gateway:

| device_type | event              | state schema                                   |
|-------------|--------------------|------------------------------------------------|
| `switch`    | `switch_toggle`    | `{}` (state phải vắng mặt hoặc empty dict)     |
| `motion`    | `occupancy_changed`| `{ "occupancy": "occupied" \| "unoccupied" }`  |

Alias chấp nhận khi nhập rule: `event = "toggle"` cũng được map sang `switch_toggle` (xem `cloud/app/routers/automations.py:95`).

Event không nằm trong bảng trên → Cloud trả `422 Unsupported … event`.

---

## 3. Action catalogue

| target device_type | command   | mô tả                       |
|--------------------|-----------|-----------------------------|
| `light`            | `on`      | bật đèn                     |
| `light`            | `off`     | tắt đèn                     |
| `light`            | `toggle`  | đảo trạng thái hiện tại     |

`device_type != "light"` hoặc `command` ngoài danh sách → Cloud trả `422`.

Mapping action → ZCL command (gateway thực hiện, không bắt buộc trong rule payload):

| command  | cluster | ZCL command   |
|----------|---------|---------------|
| `on`     | `0x0006`| `on`          |
| `off`    | `0x0006`| `off`         |
| `toggle` | `0x0006`| `toggle`      |

---

## 4. Rule schema

### 4.1 REST API request (Cloud → Cloud)

`POST /api/automations`:

```json
{
  "name": "Motion turns on lab lights",
  "enabled": true,
  "trigger": {
    "device_id": "motion-01",
    "device_type": "motion",
    "event": "occupancy_changed",
    "state": { "occupancy": "occupied" }
  },
  "actions": [
    { "device_id": "light-01", "device_type": "light", "command": "on" },
    { "device_id": "light-02", "device_type": "light", "command": "on" }
  ]
}
```

`PUT /api/automations/{id}` — thêm `"version": <current>` để optimistic concurrency. Phiên bản stale → `409`.

### 4.2 REST API response (`AutomationOut`)

```json
{
  "id": "f1b3c4d5...",
  "name": "Motion turns on lab lights",
  "enabled": true,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "version": 1,
  "trigger": { ... },
  "actions": [ ... ],
  "sync_status": "pending",            // pending | synced | failed
  "last_run_status": "never_run",      // never_run | executed | failed | timeout
  "last_error": null,
  "created_at": "07:00 03/19/2026",
  "updated_at": "07:00 03/19/2026"
}
```

### 4.3 Validation rules

| Rule                                                       | Mã lỗi |
|------------------------------------------------------------|--------|
| `trigger.device_id` không tồn tại                          | 422 |
| `trigger.device_type` ≠ device thực tế                     | 422 |
| `trigger.device_type` không thuộc {switch, motion}         | 422 |
| `actions[*].device_id` không tồn tại                       | 422 |
| `actions[*].device_type` ≠ "light"                         | 422 |
| `actions[*].command` ngoài {on, off, toggle}               | 422 |
| `switch` trigger có state ≠ empty                          | 422 |
| `motion` trigger thiếu state.occupancy hoặc giá trị lạ     | 422 |
| `PUT` version mismatch                                     | 409 |
| `GET/PUT/DELETE` automation không tồn tại                  | 404 |

Reference: `cloud/app/routers/automations.py:68-110`.

---

## 5. MQTT topics

### 5.1 Cloud → Gateway: desired rule (retained)

Topic: `sb/v1/{tenant}/{site}/{gateway}/desired/automation/{automation_id}`

- **Retained**: yes (gateway phải tự nhận snapshot khi reconnect).
- **QoS**: 0 (demo), nâng ≥1 cho production.
- **Tombstone (delete)**: cùng topic, `payload.deleted = true`, `version` bump.

Envelope payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "uuid-hex",
  "ts": 1773990000000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "cloud",
  "payload": {
    "id": "f1b3c4d5...",
    "name": "Motion turns on lab lights",
    "enabled": true,
    "tenant_id": "hust",
    "site_id": "lab01",
    "gateway_id": "gw-ubuntu-01",
    "version": 1,
    "trigger": { ... },
    "actions": [ ... ],
    "deleted": false
  }
}
```

Reference publisher: `cloud/app/mqtt_client.py:608` (`publish_automation_rule`).

### 5.2 Gateway → Cloud: lifecycle event

Topic: `sb/v1/{tenant}/{site}/{gateway}/gateway/event`

Inner `payload.event` ∈ {`automation_synced`, `automation_sync_failed`, `automation_executed`}.

```json
// automation_synced — gateway đã apply rule vào local state
{
  "event": "automation_synced",
  "rule_id": "f1b3c4d5...",
  "version": 1
}

// automation_sync_failed — desired không parse được hoặc target device thiếu
{
  "event": "automation_sync_failed",
  "rule_id": "f1b3c4d5...",
  "reason": "trigger device unknown"
}

// automation_executed — rule đã fire, kèm result
{
  "event": "automation_executed",
  "rule_id": "f1b3c4d5...",
  "result": "ok",                  // ok | failed | timeout
  "reason": null,                  // string khi result != ok
  "actions": [
    { "device_id": "light-01", "command": "on", "command_id": "..." }
  ]
}
```

Cloud subscriber (`cloud/app/mqtt_client.py:455-504`) cập nhật `automations.sync_status`, `last_run_status`, `last_error` tương ứng.

### 5.3 Gateway → Devices: action execution

Mỗi action trong rule sinh một command request theo command tree chuẩn ở [MQTT_CONTRACT.md §Commands]. Topic `sb/v1/{tenant}/{site}/{gateway}/commands/{cmd_id}/request`, payload theo schema `CommandCreate` + `LightCommandTarget`.

---

## 6. State machine

```
                ┌────────────────────────────────────────┐
                │      Cloud REST mutation (POST/PUT/    │
                │      DELETE/enable/disable)            │
                └─────────────┬──────────────────────────┘
                              │ publish desired (retained)
                              ▼
                  ┌────────────────────────┐
       version++  │   sync_status=pending  │
                  └─────────┬──────────────┘
                            │ gateway parses desired
              ┌─────────────┴────────────┐
              ▼                          ▼
   ┌───────────────────┐      ┌──────────────────────┐
   │ event=synced      │      │ event=sync_failed    │
   │ sync_status=synced│      │ sync_status=failed   │
   │ last_error=null   │      │ last_error=<reason>  │
   └─────────┬─────────┘      └──────────────────────┘
             │ trigger matches
             ▼
   ┌──────────────────────────────────────────────┐
   │ event=automation_executed                    │
   │ result ∈ {ok, failed, timeout}               │
   │ last_run_status=executed|failed|timeout      │
   └──────────────────────────────────────────────┘
```

---

## 7. Operation matrix (REST → MQTT)

| REST op                                | DB effect                            | MQTT publish                            |
|----------------------------------------|--------------------------------------|-----------------------------------------|
| `POST /api/automations`                | insert, version=1, sync=pending      | `desired/automation/{id}` retained       |
| `PUT /api/automations/{id}`            | version++, sync=pending              | `desired/automation/{id}` retained       |
| `POST /api/automations/{id}/enable`    | enabled=true, version++, sync=pending| `desired/automation/{id}` retained       |
| `POST /api/automations/{id}/disable`   | enabled=false, version++, sync=pending| `desired/automation/{id}` retained      |
| `DELETE /api/automations/{id}`         | row removed                          | `desired/automation/{id}` `deleted=true` |

Gateway phản hồi qua `gateway/event` (mục 5.2). Cloud không xoá row khi DELETE — DELETE rút row khỏi DB ngay, tombstone retained để gateway dọn local state.

---

## 8. Mobile API surface

Mobile chỉ gọi REST endpoints sau (không subscribe MQTT):

```
GET    /api/automations
GET    /api/automations/{id}
POST   /api/automations
PUT    /api/automations/{id}
POST   /api/automations/{id}/enable
POST   /api/automations/{id}/disable
DELETE /api/automations/{id}
GET    /api/automation-events?automation_id=&limit=&offset=   # SCRUM-49
```

Repository / view-model thực tế: `mobile_app/lib/data/repositories/remote_automation_repository.dart`, `mobile_app/lib/ui/features/automation/view_models/automation_view_model.dart`.

---

## 9. Versioning policy

- Bump `version` trên mọi mutation (POST=1, PUT/enable/disable/DELETE +1).
- Gateway reject desired có `version <= local_version`.
- Mobile so sánh `version` để tránh ghi đè rule mới hơn (UI hiển thị conflict toast nếu PUT 409).

---

## 10. References

- Publisher: `cloud/app/mqtt_client.py` (`publish_automation_rule`, `_handle_gateway_event`)
- API: `cloud/app/routers/automations.py`
- Schemas: `cloud/app/schemas.py` (`AutomationCreate`, `AutomationUpdate`, `AutomationOut`)
- Model: `cloud/app/models.py` (`Automation`)
- Tests: `cloud/tests/test_automations.py`, `cloud/tests/test_mqtt_client.py`, `cloud/tests/test_automation_e2e.py`
- Mobile: `mobile_app/lib/ui/features/automation/`
