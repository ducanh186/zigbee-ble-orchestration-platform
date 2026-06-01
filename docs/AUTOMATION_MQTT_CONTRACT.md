# Automation MQTT Contract (v1)

> **Status:** Phase 0 — contract freeze. Không bao gồm implementation. Khi áp
> dụng, mọi publisher/subscriber liên quan đến automation rule **phải** tuân
> thủ tài liệu này.
>
> Tài liệu này **bổ sung** cho [MQTT_CONTRACT.md](./MQTT_CONTRACT.md); không
> thay thế. Mọi neo bất biến (namespace, envelope chung, kiểu `ts`, design
> rules) đều tham chiếu file gốc đó.

## 1. Phạm vi

Đóng băng giao thức MQTT giữa **Cloud** và **Gateway** cho luồng automation
rule (CRUD rule + execution events). Mobile/Dashboard **không** subscribe MQTT
trực tiếp; mọi tương tác đi qua Cloud REST API.

Trong tài liệu này:

- **Cloud** = nguồn ủy quyền (authority) cho rule definition. Publish
  `automations/{id}/desired` retained mỗi khi có mutation (POST / enable /
  disable / update / delete).
- **Gateway** = consumer. Áp dụng rule vào local table, publish lại
  `automations/{id}/reported` retained, và publish `automations/{id}/event`
  no-retain mỗi lần rule fire.
- Định danh trên MQTT: **`automation_id`** (xem §6). Gateway có thể gọi nội bộ
  là "local rule" nhưng **trên wire luôn là `automation_id`**.

## 2. Topic tree

Thêm vào cây topic existing (xem [MQTT_CONTRACT.md §"Cây topic"](./MQTT_CONTRACT.md#cây-topic)),
song song với `devices/`, `commands/`, `ota/`, `groups/`, `scenes/`:

```text
sb/v1/{tenant}/{site}/{gateway}/automations/{automation_id}/desired      ← cloud → gateway, retained
sb/v1/{tenant}/{site}/{gateway}/automations/{automation_id}/reported     ← gateway → cloud, retained
sb/v1/{tenant}/{site}/{gateway}/automations/{automation_id}/event        ← gateway → cloud, no-retain
```

Đặt tên theo design rule §2 ([MQTT_CONTRACT.md §"Quy tắc thiết kế"](./MQTT_CONTRACT.md#quy-tắc-thiết-kế)):

- `automations/` (số nhiều) song song `devices/`, `groups/`, `scenes/`.
- Sử dụng channel name có sẵn `desired` / `reported` / `event` để khớp pattern
  desired/reported state model — không phát minh tên kênh mới.
- `op` (verb) nằm trong **payload**, không trong topic.

## 3. Common envelope

Áp dụng envelope chung của repo
([MQTT_CONTRACT.md §"Envelope chung"](./MQTT_CONTRACT.md#envelope-chung)).
Trường bắt buộc và optional giữ nguyên.

**`correlation_id` cho automation:** format `"auto_<automation_id>"` (theo
quy ước prefix đã nêu trong [MQTT_CONTRACT.md §"Kiểu của correlation_id"](./MQTT_CONTRACT.md#kiểu-của-correlation_id)).
Optional; consumer dùng `automation_id` trong topic làm khoá chính, không phải
`correlation_id`.

**`ts`:** integer Unix epoch milliseconds (UTC) — đồng nhất với existing
contract. Xem §13 về một mismatch cần lưu ý.

## 4. `automations/{automation_id}/desired` — Cloud → Gateway

Cloud publish state đầy đủ của rule mỗi lần có mutation. Payload **không
phải delta**: gateway luôn thay thế bản ghi local bằng payload mới nhất (theo
`version`).

**Retain:** YES.  
**QoS production:** 1. **QoS demo:** 0 (nhất quán với phần còn lại của repo).

### 4.1 Trường `op`

`payload.op` là verb bắt buộc. v1 chỉ chấp nhận 2 giá trị:

| `op` | Ý nghĩa |
|---|---|
| `upsert` | Tạo mới hoặc cập nhật rule. Kết hợp với `enabled=true|false` để biểu diễn enable/disable mà không cần thêm op riêng. |
| `delete` | Xoá rule khỏi local table. Xem §4.4. |

**Không** có `op=enable` / `op=disable` ở v1. Enable/disable là một
`upsert` với `enabled` thay đổi:

- `op=upsert, enabled=true` → tạo/cập nhật và bật.
- `op=upsert, enabled=false` → tạo/cập nhật nhưng tắt (gateway giữ rule trong
  table, không evaluate trigger).

### 4.2 Payload — upsert

```json
{
  "schema": "sb.v1",
  "msg_id": "5c6d467f5f90460da65a9db62288def6",
  "ts": 1779000000000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "cloud",
  "correlation_id": "auto_8c2f1d34",
  "payload": {
    "automation_id": "auto_8c2f1d34",
    "op": "upsert",
    "name": "Hallway switch toggles ceiling light",
    "enabled": true,
    "version": 3,
    "trigger": {
      "device_id": "0000000000000057",
      "device_type": "switch",
      "event": "switch_toggle",
      "state": {}
    },
    "actions": [
      {
        "device_id": "0000000000000055",
        "device_type": "light",
        "command": "toggle"
      }
    ]
  }
}
```

### 4.3 Enum bắt buộc trong payload (upsert)

| Field | Allowed values | Ghi chú |
|---|---|---|
| `op` | `upsert`, `delete` | xem §4.1 |
| `trigger.device_type` | `switch`, `motion` | v1 — khớp 4 mobile template |
| `trigger.event` | `switch_toggle`, `occupancy_changed` | snake_case (khớp `event:"occupancy_changed"` đã có trong motion event) |
| `trigger.state.occupancy` | `occupied`, `unoccupied` | bắt buộc khi `trigger.event=occupancy_changed`; vắng mặt với switch |
| `action.device_type` | `light` | v1 — chỉ light là target |
| `action.command` | `on`, `off`, `toggle` | khớp ZCL On/Off cluster 0x0006 |
| `actions` | length ≥ 1, ≤ §11 cap | |
| `enabled` | `true`, `false` | |
| `version` | int ≥ 1, tăng đơn điệu | Cloud tăng mỗi mutation; gateway dùng để chống ghi đè state cũ. |
| `name` | string, length 1..120 | Khớp `AutomationCreate.name` ở cloud schema. |

### 4.4 Delete — retained tombstone

v1 dùng **retained tombstone payload** (không dùng empty-retained). Empty
retained có thể dùng làm cleanup tương lai (xem §10).

```json
{
  "schema": "sb.v1",
  "msg_id": "9aaff1c30c2c4f6ab1afe2c5a1d99e02",
  "ts": 1779000060000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "cloud",
  "correlation_id": "auto_8c2f1d34",
  "payload": {
    "automation_id": "auto_8c2f1d34",
    "op": "delete",
    "version": 4,
    "deleted": true
  }
}
```

Gateway behaviour:

- Nếu `payload.op == "delete"` **hoặc** `payload.deleted == true`, gateway xoá
  rule khỏi local table.
- Sau đó publish `reported` với `sync_status = "deleted"` (xem §5).
- Tombstone vẫn retained: gateway boot lại sau xoá → broker replay tombstone
  → gateway xác nhận rule không có trong local table → không cần làm gì thêm.

## 5. `automations/{automation_id}/reported` — Gateway → Cloud

Gateway publish ack ngay sau khi áp dụng (hoặc fail) `desired`.

**Retain:** YES.  
**QoS production:** 1. **QoS demo:** 0.

### 5.1 Enum `sync_status` (gateway-published)

| `sync_status` | Khi nào | `last_error` |
|---|---|---|
| `synced` | Gateway đã insert/update local table thành công cho `op=upsert`. | `null` |
| `failed` | Validation fail, target device chưa biết, table full, version stale, … | string ASCII ≤ 200 char |
| `deleted` | Gateway đã xoá rule khỏi local table cho `op=delete`. | `null` |

> **Note:** `pending` là **Cloud DB column state** trước khi nhận ack — Gateway
> không bao giờ publish `sync_status=pending` trong `reported`. Cloud schema
> (`cloud/app/schemas.py:271`) hiện cho phép `pending|synced|failed`; cần thêm
> `deleted` khi implement Phase 1 (chỉ là schema change, không phải contract
> change — tài liệu này là source of truth).

### 5.2 Payload — synced

```json
{
  "schema": "sb.v1",
  "msg_id": "b4d9d1da8e9c4e6e9821f6a8a1cf001a",
  "ts": 1779000000050,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "correlation_id": "auto_8c2f1d34",
  "payload": {
    "automation_id": "auto_8c2f1d34",
    "version": 3,
    "sync_status": "synced",
    "last_error": null
  }
}
```

### 5.3 Payload — deleted

```json
{
  "schema": "sb.v1",
  "msg_id": "f9c0e2d1d7724012b94f0bc7a312bfca",
  "ts": 1779000060050,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "correlation_id": "auto_8c2f1d34",
  "payload": {
    "automation_id": "auto_8c2f1d34",
    "version": 4,
    "sync_status": "deleted",
    "last_error": null
  }
}
```

### 5.4 Payload — failed

```json
{
  "payload": {
    "automation_id": "auto_8c2f1d34",
    "version": 3,
    "sync_status": "failed",
    "last_error": "target_device_unknown:0000000000000099"
  }
}
```

### 5.5 Lý do retain

- Cloud restart → subscribe `automations/+/reported` → broker replay retained
  → Cloud rebuild `Automation.sync_status` / `Automation.last_error` cho từng
  rule mà không cần Gateway re-publish.
- Khi `sync_status=deleted`, Cloud có thể xử lý: hoặc giữ retained để cảnh
  báo "rule này đã bị gateway xác nhận xoá" (mặc định), hoặc về sau dọn bằng
  empty-retained (xem §10).

## 6. `automations/{automation_id}/event` — Gateway → Cloud (execution result)

Mỗi lần rule fire, Gateway publish 1 event. **KHÔNG retain** (event là dòng
thời gian — Event Center kéo về qua REST `/api/events/`).

**Retain:** NO.  
**QoS production:** 1. **QoS demo:** 0.

### 6.1 Payload

```json
{
  "schema": "sb.v1",
  "msg_id": "c7e3aa1bb9c84b9bbf6b3ad96e2b0c11",
  "ts": 1779000123456,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "correlation_id": "auto_8c2f1d34",
  "payload": {
    "automation_id": "auto_8c2f1d34",
    "event": "rule_fired",
    "run_id": "run_4a1c8e02",
    "version": 3,
    "trigger": {
      "device_id": "0000000000000057",
      "event": "switch_toggle"
    },
    "actions": [
      {
        "device_id": "0000000000000055",
        "command": "toggle",
        "status": "executed",
        "reason": null,
        "command_id": null
      }
    ],
    "status": "executed",
    "last_error": null
  }
}
```

### 6.2 Enum

| Field | Allowed values |
|---|---|
| `payload.event` | `rule_fired` (v1). Reserved cho v2: `rule_skipped` (cooldown / disabled / debounce). |
| `payload.status` (aggregate) | `executed`, `failed`, `timeout`, `skipped` |
| `actions[].status` (per action) | `executed`, `failed`, `timeout` |
| `actions[].command_id` | `null` ở v1 — xem §8. |

### 6.3 `run_id`

`run_id` là chuỗi opaque do Gateway sinh, dùng để nối execution event với
gateway log nội bộ. Cloud **không** dùng `run_id` làm primary key — khoá tự
nhiên là `(automation_id, ts)` (hoặc auto-increment `events.id`).

## 7. Identity / version model

| Field | Authority | Ghi chú |
|---|---|---|
| `automation_id` | Cloud sinh, immutable | Hex string `auto_<≥6 hex>`. Gateway **không bao giờ** tự sinh. Trên MQTT contract luôn là `automation_id`; Gateway có thể gọi internally là local rule index nhưng wire field cố định. |
| `version` | Cloud tăng mỗi mutation | Mỗi lần Cloud publish `desired` (upsert hoặc delete), `version` tăng +1. Gateway lưu `stored_version`; nếu nhận `desired` với `version ≤ stored_version` → gateway ack với `sync_status=synced` (idempotent) nhưng KHÔNG reapply payload. Tránh race ngược khi broker replay retained sau khi Cloud đã publish version mới hơn. |
| `run_id` | Gateway sinh | Chỉ xuất hiện trong `event`. Format gợi ý `run_<≥6 hex>`. |
| `correlation_id` | Format `auto_<automation_id>` | Optional, chỉ phục vụ trace. |

`automation_id` format đề xuất: `auto_` + 8 hex tối thiểu, ví dụ
`auto_8c2f1d34`. Phương án thay thế (UUID-32 hex như `command_id` hiện có)
được mở để Phase 1 chốt — không ảnh hưởng wire format vì cả hai đều là
string opaque.

## 8. Tách rời command lifecycle vs automation lifecycle

| Mặt | Manual device command (cloud-driven) | Automation rule (local-driven) |
|---|---|---|
| Topic request | `commands/{command_id}/request` | `automations/{automation_id}/desired` |
| Topic reply | `commands/{command_id}/reply` | `automations/{automation_id}/reported` |
| Topic event | (n/a) | `automations/{automation_id}/event` |
| Lifecycle stages | `accepted → queued → sent → executed | failed | timeout` | `desired upsert → reported synced → event rule_fired (run_id)` |
| Yêu cầu `command_id` | Có (định danh chính) | **Không bắt buộc ở v1** |

Action ở `automations/.../event` **không cần** tạo `command_id` ở v1 — gateway
thực thi local ZCL frame trực tiếp (giống đường `lightCtrlLocalToggle()`
hiện tại trong `gateway/Z3GatewayHost/app/light_ctrl.c`). Vì vậy
`actions[].command_id = null`.

v2 (future) có thể nối automation action với existing command lifecycle —
khi đó `actions[].command_id` mang `command_id` của một row tương ứng trong
bảng `commands` (kéo theo cloud command tracker, REST `/api/commands/{id}`,
v.v.). v2 không thuộc phạm vi Phase 0.

## 9. Retain / QoS

Bổ sung vào bảng [MQTT_CONTRACT.md §"Retain và QoS"](./MQTT_CONTRACT.md#retain-và-qos):

| Topic | QoS (production) | Retain | Ghi chú |
|---|---|---|---|
| `automations/*/desired` | 1 | có | Cloud → gateway. Cả `op=upsert` và `op=delete` (tombstone). |
| `automations/*/reported` | 1 | có | Gateway → cloud sync ack. |
| `automations/*/event` | 1 | không | Gateway → cloud execution events. |

Demo mode tiếp tục QoS 0 đồng nhất với phần còn lại của contract.

## 10. Tombstone vs empty-retained (future cleanup)

v1 **dùng tombstone payload** (xem §4.4) làm cơ chế chính cho delete. Lý do:

1. Tồn tại metadata `version`, `deleted=true`, `correlation_id` → cloud có
   thể log audit trail.
2. Tránh nhầm với "empty retained = retain-clear" mà Gateway đang dùng cho
   `devices/.../registry` slot drop (`cloud/app/mqtt_client.py:108-116`) —
   tránh đè lẫn semantics.

Empty retained payload được **reserve** cho cleanup tương lai: ví dụ sau X
ngày sau khi tombstone đã được cả Cloud và Gateway ack, một tooling job có
thể gửi empty retained để nhả slot retained trên broker. KHÔNG implement ở
Phase 0/1.

## 11. MVP cap (v1)

| Giới hạn | Giá trị v1 | Lý do |
|---|---|---|
| Số rule / gateway | **16** | Phù hợp với memory footprint của Z3Gateway host binary; mở rộng dễ ở v2 nếu cần. |
| Số action / rule | **4** | Đủ cho 4 mobile template hiện có (max 1 action/template trong UX hiện tại); buffer cho future "switch toggles up to N lights". |

Nếu Cloud có request vượt cap (e.g. mobile gửi 5 target lights trong một
rule), Cloud từ chối tại API layer trước khi publish:

- `HTTP 422` (validation) cho actions > 4.
- `HTTP 409` (conflict) cho rule count > 16 trên cùng gateway.

Gateway-side cũng check defensively: nếu nhận `desired` vượt cap, publish
`reported.sync_status=failed` với `last_error` tương ứng (vd `table_full`,
`too_many_actions`).

## 12. Sequence chuẩn (end-to-end)

```
Cloud DB: status=pending                                              Gateway local table
   │ POST /api/automations/  ─────────────────────────────────────────►        (empty)
   │ publish automations/{id}/desired op=upsert v=1 (retained) ──────►  insert rule
   │                                                  ◄────────────── publish reported sync_status=synced v=1 (retained)
DB: status=synced
   │
   │ <… physical switch toggle …>
   │                                                  ◄────────────── publish event rule_fired run_id=run_… status=executed
DB: last_run_status=executed
events: row inserted (event_type=automation_fired)
   │
   │ DELETE /api/automations/{id}  ──────────────────────────────────►
   │ publish automations/{id}/desired op=delete deleted=true v=2 (retained) ──► drop rule
   │                                                  ◄────────────── publish reported sync_status=deleted v=2 (retained)
DB: row deleted (or soft-deleted, TBD ở Phase 1)
```

Đường gãy được phép ở v1:

- Cloud không nhận `reported` trong N giây → cloud DB giữ `sync_status=pending`.
  v1 KHÔNG retry tự động (mobile thấy `pending` → người dùng quyết định).
  Timeout sweeper là việc của Phase 2+ (xem §14).
- Gateway boot → broker replay retained `desired` cho tất cả rule còn sống
  → gateway rebuild local table → từng rule publish lại `reported`.

## 13. Subscription / publisher matrix

| Vai trò | Subscribe | Publish |
|---|---|---|
| Cloud backend | `automations/+/reported` (retained — initial state sync), `automations/+/event` | `automations/+/desired` (retained, both `upsert` và `delete` tombstone) |
| Gateway | `automations/+/desired` (retained — initial state sync khi reconnect) | `automations/+/reported` (retained), `automations/+/event` (no-retain) |
| Mobile / Dashboard | (đi qua REST API cloud — **không** sub MQTT trực tiếp) | — |

Cập nhật bảng wildcard subscription trong
[MQTT_CONTRACT.md §"Ví dụ wildcard subscription"](./MQTT_CONTRACT.md#ví-dụ-wildcard-subscription)
tương ứng — xem patch nhỏ ở MQTT_CONTRACT.md.

## 14. Open decisions hoãn sang Phase 1+

- **Timeout sweeper Cloud-side** cho `sync_status=pending` quá lâu — Phase 2.
- **PUT/DELETE REST endpoint** cho automation rule (`cloud/app/routers/automations.py`
  hiện chỉ có create/list/get/enable/disable). Phase 1, không ảnh hưởng wire.
- **Soft-delete vs hard-delete** ở cloud DB row khi gateway ack `deleted`.
  Phase 1, không ảnh hưởng wire.
- **Cooldown / debounce** cho rule fire — Phase 2.
- **Multi-action atomicity / ordering** — v1 best-effort sequential, không
  transactional.

## 15. Docs/code mismatch flagged

**Existing contract dùng integer ms cho `ts`, KHÔNG phải ISO-8601.**

- [MQTT_CONTRACT.md §"Kiểu của ts"](./MQTT_CONTRACT.md#kiểu-của-ts) tuyên bố
  rõ: *"`ts` là **số nguyên** — Unix epoch tính bằng **milliseconds** (UTC)"*.
- Cloud code `cloud/app/mqtt_client.py:23` định nghĩa
  `_ts_ms_to_naive_utc(ts: object)` và dùng nó cho mọi `envelope.get("ts")`
  parse path (lines 192, 248, 386, 447, 491).
- Cloud publish path dùng `_now_ms()` (lines 516, 553), trả về integer ms.
- Gateway log cũng phát `"ts":1778885353513` (integer ms, đã quan sát thực tế
  ở `/tmp/z3gw.log`).

Phase 0 contract giữ integer ms để đồng nhất với existing — KHÔNG đổi sang
ISO-8601 trong Phase 0. Nếu chiến lược tổng thể là chuyển toàn repo sang
ISO-8601, đó phải là một migration RFC riêng (cập nhật cả cloud `_now_ms` +
gateway `app_mqtt.c` + tất cả existing topic), không phải patch ngầm trong
automation contract.

## 16. Out of scope ở Phase 0

- Implementation gateway-side (P0.11 / P0.12 / P0.13 / P0.14).
- Implementation cloud `publish_automation_desired` (P0.10).
- Cloud PUT / DELETE REST endpoint (P0.9).
- Mobile UI thay đổi (`sync_status` / `last_run_status` đã có sẵn binding).
- Cooldown / debounce logic.
- Multi-action ordering / atomicity.
- DB schema changes (sẽ cần thêm `deleted` vào `sync_status` Literal khi
  implement — không phải Phase 0).
