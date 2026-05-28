# Provisioning Contract (Secure Join via Install Code) — v1 draft

Contract chính thức cho luồng provisioning thiết bị Zigbee bằng **Install Code**.
Mọi bên (Mobile App, Cloud, Z3Gateway) phải tuân theo tài liệu này. Đây là
output của SCRUM-69 (Phase A0 — chốt contract trước khi code).

Liên quan:

- Envelope, namespace, command lifecycle: [MQTT_CONTRACT.md](./MQTT_CONTRACT.md)
- MQTT ↔ gateway action: [ADAPTER_ACTION_MAP.md](./ADAPTER_ACTION_MAP.md)
- device_type freeze: [DEVICE_CAPABILITY_MATRIX.md](./DEVICE_CAPABILITY_MATRIX.md)
- Audit nền: `PROVISIONING_AUDIT_REPORT.md` (local, gitignored)

> **Trạng thái:** draft để team (P + A1 + A2) review. Chưa freeze cho tới khi cả
> 3 bên ký xác nhận. Mọi thay đổi field/enum sau freeze phải qua review.

---

## 1. Ranh giới (frozen)

```text
Mobile App  →  REST  →  Cloud  →  MQTT  →  Z3Gateway  →  Zigbee
 (scan/nhập)         (session)       (prepare_join)     (TC secure join)
```

Bất biến:

- **App chỉ biết REST.** App không publish MQTT, không nói chuyện Zigbee, không
  derive link key, không xử lý crypto. App chỉ đọc QR/nhập tay → validate cơ
  bản → POST lên Cloud → poll trạng thái.
- **Cloud là bộ điều phối.** Cloud giữ session state, publish lệnh MQTT, nhận
  reply/event, cập nhật registry.
- **Gateway sở hữu Zigbee.** Gateway nhận `gateway.prepare_join`, stage install
  code, mở permit-join, để network-creator-security plugin derive TC link key,
  publish kết quả join.

---

## 2. device_type (freeze v1)

Chỉ chấp nhận: `light`, `switch`, `motion`.
KHÔNG dùng `occupancy` / `occ` ở đối ngoại (xem DEVICE_CAPABILITY_MATRIX.md).

---

## 3. QR payload (App đọc)

QR hiển thị trên màn thiết bị (hoặc sticker / nhập tay) mã hoá JSON:

```json
{
  "version": 1,
  "eui64": "A8D417FEFF570B00",
  "install_code": "83FED3407A939723A5C639B26916D505C3B5",
  "device_type": "light",
  "model": "EFR32MG12_LIGHT_KIT"
}
```

| Field | Kiểu | Bắt buộc | Ghi chú |
| --- | --- | --- | --- |
| `version` | int | có | Schema version. v1 = 1. App reject version không hỗ trợ. |
| `eui64` | hex string (16 hex chars) | có | IEEE address, big-endian hex, không `0x`. |
| `install_code` | hex string | có | Install code kèm CRC little-endian. Độ dài hợp lệ: raw 6/8/12/16 bytes + CRC 2 bytes (full hex length 16/20/28/36). Xem §7. |
| `device_type` | enum | có | `light \| switch \| motion`. |
| `model` | string | không | Ví dụ `EFR32MG12_LIGHT_KIT`. Optional. |

App validate **local** trước khi gửi: parse được JSON, `version` hỗ trợ,
`eui64` đúng hex/độ dài, `install_code` đúng hex, `device_type` hợp lệ. App
**không** bắt buộc kiểm CRC install code; Cloud là authority và reject payload
sai CRC trước khi tạo provisioning session.

SCRUM-77 chỉ dùng QR/manual input như kênh out-of-band. BLE/Zigbee Direct không
nằm trong request/response của contract này; nếu làm BLE provisioning thì tách
thành sprint riêng vì cần BLE GATT services, secure session và commissioning
flow riêng.

---

## 4. REST contract (App ↔ Cloud)

Base: `/api/provisioning`.

### 4.1 `POST /api/provisioning/sessions`

Tạo session và kích hoạt provisioning.

Request:

```json
{
  "gateway_id": "gw-ubuntu-01",
  "room_id": 1,
  "device": {
    "eui64": "A8D417FEFF570B00",
    "install_code": "83FED3407A939723A5C639B26916D505C3B5",
    "device_type": "light",
    "model": "EFR32MG12_LIGHT_KIT"
  }
}
```

Response `201`:

```json
{
  "session_id": "8b1c...hex",
  "status": "pending",
  "gateway_id": "gw-ubuntu-01",
  "room_id": 1,
  "eui64": "A8D417FEFF570B00",
  "device_type": "light",
  "model": "EFR32MG12_LIGHT_KIT",
  "reason": null,
  "expires_at": "HH:MM MM/DD/YYYY",
  "created_at": "HH:MM MM/DD/YYYY",
  "updated_at": "HH:MM MM/DD/YYYY"
}
```

Lỗi `4xx` (body):

```json
{ "detail": { "error_code": "INVALID_INSTALL_CODE", "message": "..." } }
```

### 4.2 `GET /api/provisioning/sessions/{session_id}`

App poll. Trả cùng shape `ProvisioningSessionOut` như trên, với `status` cập
nhật. `install_code` **không bao giờ** xuất hiện trong response.

### 4.3 `DELETE /api/provisioning/sessions/{session_id}`

Hủy phiên: Cloud đóng permit-join sớm (`gateway.close_network`) và đánh dấu
session `cancelled`. Trả `200` với session đã cập nhật, hoặc `409` nếu session
đã ở terminal state.

---

## 5. Status enum + chuyển trạng thái

```text
pending      — đã tạo session, chưa gửi gateway xong
permit_open  — gateway đã stage install code + mở permit-join (reply executed)
joining      — (optional) thiết bị bắt đầu join, gateway báo tiến trình
joined       — thiết bị join thành công, device registry đã tạo
failed       — gateway báo lỗi / command failed
expired       — quá expires_at mà chưa joined
cancelled    — App hủy session
```

Chuyển hợp lệ:

```text
pending → permit_open → joined
pending → failed
permit_open → joining → joined
permit_open → failed | expired
pending|permit_open|joining → cancelled (do DELETE)
```

`joined | failed | expired | cancelled` là **terminal** (App dừng poll).

---

## 6. Error code enum (REST 4xx)

| error_code | HTTP | Khi nào |
| --- | --- | --- |
| `INVALID_QR_PAYLOAD` | 422 | Body sai cấu trúc / thiếu field. |
| `INVALID_EUI64` | 422 | `eui64` sai format/độ dài. |
| `INVALID_INSTALL_CODE` | 422 | `install_code` sai format/độ dài/CRC. |
| `UNSUPPORTED_DEVICE_TYPE` | 422 | `device_type` ngoài `light/switch/motion`. |
| `GATEWAY_NOT_FOUND` | 404 | `gateway_id` ≠ gateway Cloud quản. |
| `ROOM_NOT_FOUND` | 404 | `room_id` không tồn tại. |
| `SESSION_ALREADY_ACTIVE` | 409 | Đã có session non-terminal cho cùng `eui64`. |

---

## 7. Install code (format + nơi validate CRC)

- Install code gồm các byte + 2 byte CRC-16 cuối (theo Zigbee BDB spec).
- Độ dài hợp lệ (số byte gồm CRC): 8, 10, 14, 18 bytes (tương ứng 6/8/12/16
  byte code + 2 byte CRC). Biểu diễn hex string không dấu cách.
- **Nơi validate CRC chuẩn = Gateway** (stack từ chối CRC sai khi derive key).
  Cloud chỉ validate format/độ dài; App chỉ validate là hex.
- Cloud/Gateway **không** log raw install code. Cloud cân nhắc encrypt at rest
  (quyết định triển khai: app-level AES với key trong env cho MVP).

---

## 8. MQTT contract (Cloud ↔ Gateway)

Tái sử dụng channel lệnh hiện có — **không** tạo topic tree mới.

### 8.1 Downlink: op `gateway.prepare_join`

Topic: `sb/v1/{tenant}/{site}/{gateway}/commands/{command_id}/request`

```json
{
  "schema": "sb.v1",
  "msg_id": "...",
  "ts": 1773990000000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "cloud",
  "correlation_id": "cmd_{command_id}",
  "payload": {
    "op": "gateway.prepare_join",
    "target": {
      "eui64": "A8D417FEFF570B00",
      "install_code": "83FED3407A939723A5C639B26916D505C3B5",
      "duration_sec": 60
    },
    "timeout_ms": 5000
  }
}
```

Gateway: stage `(eui64 → install_code, TTL=duration_sec+grace)`, mở permit-join
`duration_sec` giây (reuse `netMgrOpenForJoin`), reply lifecycle như command
thường (`accepted → queued → sent → executed | failed | timeout`). Khi thiết bị
join, plugin gọi `emberAfPluginNetworkCreatorSecurityGetInstallCodeCallback` để
lấy install code đã stage → derive TC link key (AES-MMO, gateway không tự code
crypto). Cần bật `EMBER_AF_PLUGIN_NETWORK_CREATOR_SECURITY_BDB_JOIN_USES_INSTALL_CODE_KEY = 1`.

### 8.2 Command reply → Cloud cập nhật session

| reply `status` | session |
| --- | --- |
| `executed` | `permit_open` |
| `failed` / `timeout` | `failed` (kèm reason) |

### 8.3 Uplink event: `gateway/event`

Topic: `sb/v1/{tenant}/{site}/{gateway}/gateway/event`

```json
{ "...envelope...", "source": "gateway",
  "payload": {
    "event": "provisioning_joined",
    "eui64": "A8D417FEFF570B00",
    "device_type": "light",
    "nwk_addr": "0x4F2A"
  }
}
```

`event` mới: `provisioning_joined` (kèm `eui64`, `device_type`, `nwk_addr`),
`provisioning_failed` (kèm `eui64`, `reason`). Cloud match theo
`eui64 + gateway_id + active session`.

- `provisioning_joined` → session `joined`; create/update `devices` row, gán
  `room_id`, mask/clear install code trong session.
- `provisioning_failed` → session `failed` + reason.

Lưu ý: gateway cũng publish retained `devices/{type}/{eui64}/registry` như cũ;
Cloud không được phụ thuộc thứ tự giữa event và registry.

---

## 9. Sequence (happy path)

```text
App           Cloud                 Gateway              Device
 | POST session  |                     |                    |
 |-------------->| create session      |                    |
 |  201 pending  | (status=pending)    |                    |
 |<--------------|                     |                    |
 |               | PUB gateway.prepare_join (commands/.../request)
 |               |-------------------->| stage IC + permit-join
 |               | reply executed      |                    |
 |               |<--------------------| (status=permit_open)
 | GET (poll)    |                     |   join (secure)    |
 |-------------->| permit_open         |<-------------------|
 |               |  gateway/event provisioning_joined       |
 |               |<--------------------|                    |
 |               | create device+room  |                    |
 | GET (poll)    | status=joined       |                    |
 |<--------------|                     |                    |
```

---

## 10. Phân chia trách nhiệm

| Phần | Owner | Ticket |
| --- | --- | --- |
| Contract này | A | SCRUM-69 |
| provisioning_sessions table + schema | A2 | SCRUM-70 |
| REST endpoints + validation | A2 | SCRUM-71 |
| publish prepare_join + reply + timeout | A2 | SCRUM-72 |
| join correlation + device/room | A2 | SCRUM-73 |
| App models + QR validation | A1 | SCRUM-74 |
| App REST client + polling | A1 | SCRUM-75 |
| App wizard UI | A1 | SCRUM-76 |
| App QR scanner + manual | A1 | SCRUM-77 |
| Gateway prepare_join + TC install code + join event | P | (firmware/gateway) |

---

## 11. Quy tắc tương thích

1. Không tạo topic MQTT mới — chỉ thêm `op` và `event` value trong channel cũ.
2. Không đổi tên/format các field contract sau khi freeze nếu chưa review.
3. App ↔ Cloud chỉ qua REST; App không bao giờ chạm MQTT/Zigbee.
4. install code không log, không trả về REST.
5. `device_type` luôn theo freeze `light/switch/motion`.
