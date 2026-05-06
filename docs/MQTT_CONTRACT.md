# MQTT Contract

Đây là contract chính thức cho toàn bộ giao tiếp MQTT trong hệ thống. Mọi publisher và subscriber đều phải tuân thủ tài liệu này.

> **Cấu hình broker**: xem [mqtt/README.md](../mqtt/README.md) — bao gồm cách chạy local, tài khoản, ACL, và cổng mạng.

---

## Namespace

Toàn bộ MQTT traffic sử dụng namespace:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

Giá trị mặc định khi phát triển:

- `tenant_id = hust`
- `site_id = lab01`
- `gateway_id = gw-ubuntu-01`

## Envelope chung

Mọi MQTT message đều dùng chung JSON envelope:

```json
{
  "schema": "sb.v1",
  "msg_id": "e6f67ab087c64f1e9457a2f6e03f9a68",
  "ts": 1773990000000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "trace_id": "trace-01",
  "correlation_id": "cmd_01",
  "payload": {}
}
```

**Trường bắt buộc:** `schema`, `msg_id`, `ts`, `tenant_id`, `site_id`, `gateway_id`, `source`, `payload`.

**Trường tùy chọn:** `trace_id`, `correlation_id`.

### Kiểu của `correlation_id`

`correlation_id` là **optional**. Khi có mặt, nó dùng để nối các message cùng
một luồng nghiệp vụ (ví dụ: request ↔ reply). Quy ước format:

- Luồng lệnh (commands): `correlation_id = "cmd_" + {command_id}`. Ví dụ nếu
  `command_id = "a1b2c3"` thì `correlation_id = "cmd_a1b2c3"`.
- Các luồng khác (OTA, scene...) nếu muốn dùng correlation_id thì áp dụng
  prefix tương tự (`ota_`, `scene_`...), không tự phát minh format mới.

Subscriber **không** được dùng `correlation_id` làm khoá chính để tra cứu
command; khoá chính luôn là `command_id` lấy từ topic
`commands/{command_id}/reply`. `correlation_id` chỉ để trace / log.

### Kiểu của `ts`

`ts` là **số nguyên** — Unix epoch tính bằng **milliseconds** (UTC). Ví dụ
`1773990000000` tương ứng `2026-03-19T07:00:00Z`.

- Publisher (gateway / cloud / adapter) luôn phát `ts` dạng số nguyên ms.
- Subscriber tự chuyển sang định dạng hiển thị cần dùng. Cloud chuẩn hoá về
  chuỗi `HH:MM MM/DD/YYYY` trước khi trả ra REST API cho consumer.
- Không truyền `ts` dưới dạng chuỗi ISO8601, chuỗi số có dấu nháy, hay chuỗi
  đã format — việc format là trách nhiệm của phía hiển thị.

## Cây topic

### Gateway

```text
sb/v1/{tenant}/{site}/{gateway}/gateway/online
sb/v1/{tenant}/{site}/{gateway}/gateway/health
sb/v1/{tenant}/{site}/{gateway}/gateway/log
```

### Thiết bị (Devices)

Topic thiết bị chứa `{device_type}` làm một level routing, cho phép wildcard
theo nhóm thiết bị (ví dụ: `devices/light/+/reported` — lấy tất cả đèn).

```text
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/registry
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/reported
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/telemetry
sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/event
```

Giá trị `device_type` đã biết: `light`, `motion`, `lock`, `switch`, `unknown`.

> **Phase 0 freeze (v1):** chỉ `light`, `switch`, `motion` có capability chính thức — xem
> [DEVICE_CAPABILITY_MATRIX.md](./DEVICE_CAPABILITY_MATRIX.md).
> Đối ngoại (MQTT + `payload.device_type`) **luôn dùng `motion`**;
> các tên cũ `occ` / `occupancy` chỉ là legacy nội bộ.
> Trong `payload.state` của cảm biến `motion`, giá trị occupancy được biểu diễn là
> `"occupied"` / `"unoccupied"` (đó là *trạng thái đo*, không phải *device_type*).
> `lock` và `unknown` hợp lệ trong topic nhưng chưa có capability v1.

### Lệnh điều khiển (Commands)

```text
sb/v1/{tenant}/{site}/{gateway}/commands/{command_id}/request
sb/v1/{tenant}/{site}/{gateway}/commands/{command_id}/reply
```

### OTA

```text
sb/v1/{tenant}/{site}/{gateway}/ota/campaigns/{campaign_id}/manifest
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/progress
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/event
```

### Nhóm (Groups)

```text
sb/v1/{tenant}/{site}/{gateway}/groups/{group_id}/reported
sb/v1/{tenant}/{site}/{gateway}/groups/{group_id}/desired
```

### Kịch bản (Scenes)

```text
sb/v1/{tenant}/{site}/{gateway}/scenes/{scene_id}/desired
sb/v1/{tenant}/{site}/{gateway}/scenes/{scene_id}/event
```

## Retain và QoS

> **Demo vs production:** Bảng dưới liệt kê QoS của **kiến trúc thực tế** (production).
> Bản triển khai demo hiện tại của dự án (`cloud/`, `gateway/`, broker local
> và EC2) **publish/subscribe toàn bộ topic ở QoS 0** để đơn giản hoá vận hành
> và giảm overhead khi test. Khi chuyển sang production, publisher/subscriber
> phải nâng QoS theo bảng này — đặc biệt là các luồng trạng thái và lệnh
> (retained + QoS 1) không được hạ cấp. Retain policy giữ nguyên cho cả hai
> môi trường.

| Topic | QoS | Retain | Ghi chú |
| --- | --- | --- | --- |
| `gateway/online` | 1 | có | Dùng Last Will and Testament (LWT) |
| `gateway/health` | 1 | có | |
| `gateway/log` | 0 | không | |
| `devices/*/*/registry` | 1 | có | |
| `devices/*/*/reported` | 1 | có | |
| `devices/*/*/desired` | 1 | có | |
| `devices/*/*/telemetry` | 0 | không | Tần suất cao, mất 1 gói không nghiêm trọng |
| `devices/*/*/event` | 1 | không | |
| `commands/*/request` | 1 | không | |
| `commands/*/reply` | 1 | không | |
| `ota/campaigns/*/manifest` | 1 | có | |
| `ota/devices/*/desired` | 1 | có | |
| `ota/devices/*/progress` | 1 | có | |
| `ota/devices/*/event` | 1 | không | |
| `groups/*/reported` | 1 | có | |
| `groups/*/desired` | 1 | không | |
| `scenes/*/desired` | 1 | không | |
| `scenes/*/event` | 1 | không | |

**LWT cho `gateway/online`:**

- Khi mất kết nối bất thường: broker tự publish envelope retained với `payload.value = "offline"`
- Khi kết nối thành công: gateway publish envelope retained với `payload.value = "online"`

## Vòng đời lệnh (Command Lifecycle)

Gateway publish một reply message cho mỗi bước trạng thái:

```text
accepted → queued → sent → executed | failed | timeout
```

Quy tắc:

- `correlation_id` của mọi reply (nếu có) luôn là `"cmd_" + {command_id}`;
  bản thân `correlation_id` là **optional** — gateway/adapter có thể bỏ qua,
  consumer vẫn phải tra command theo `{command_id}` trong topic
- `commands/{command_id}/reply` không bao giờ retain
- Z3Gateway C phát ra toàn bộ lifecycle: `accepted`, `queued`, `sent`
- Z3Gateway C phát ra kết quả cuối cùng (`executed` / `failed` / `timeout`)

Ví dụ payload reply tối giản:

```json
{
  "status": "executed",
  "device_id": "light-01",
  "reason": null
}
```

## Mô hình định danh (Identity Model)

| Trường | Vai trò | Ghi chú |
| --- | --- | --- |
| `device_id` | Định danh logic, ổn định | Khóa chính trong hệ thống |
| `eui64` | Định danh phần cứng IEEE | Nằm trong payload |
| `nwk_addr` | Địa chỉ mạng runtime | Chỉ dùng debug, không bao giờ làm khóa |

## Ví dụ

### Trạng thái thiết bị (reported)

Topic:

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/light/light-01/reported
```

Payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "5c6d467f5f90460da65a9db62288def6",
  "ts": 1773990900000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "payload": {
    "device_id": "light-01",
    "device_type": "light",
    "eui64": "00124b0001aa22bb",
    "nwk_addr": "0x4F2A",
    "state": {
      "power": "on",
      "level": 180,
      "reachable": true
    }
  }
}
```

### Sự kiện motion occupancy changed

Gateway publish event này khi trạng thái occupancy của motion sensor đổi
từ giá trị trước đó. Reported state vẫn nằm ở
`devices/motion/{id}/reported`; event dùng để cloud lưu lịch sử.

Topic:

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/motion/00124b0001aa22cc/event
```

Payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "b1c2d3e4f5a6478899aabbccddeeff00",
  "ts": 1776064565000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "payload": {
    "device_id": "00124b0001aa22cc",
    "device_type": "motion",
    "event": "occupancy_changed",
    "occupancy": "occupied",
    "eui64": "00124b0001aa22cc",
    "nwk_addr": "0x4F2A",
    "raw": "0x01"
  }
}
```

### Gửi lệnh (command request)

Topic:

```text
sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/request
```

Payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "fb5247dbeb4f480ebcb1e835a85d8182",
  "ts": 1773990960000,
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "cloud",
  "correlation_id": "cmd_01",
  "payload": {
    "device_id": "light-01",
    "op": "device.command",
    "target": {
      "endpoint": 1,
      "cluster_id": "0x0006",
      "command": "off"
    },
    "timeout_ms": 5000
  }
}
```

## Ví dụ wildcard subscription

Topic filter phổ biến cho từng vai trò subscriber. Xem thêm [tài khoản và phân quyền](../mqtt/README.md#tài-khoản).

### Dashboard (tổng quan site)

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/reported
sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/event
sb/v1/hust/lab01/gw-ubuntu-01/gateway/+
```

### Dashboard (chỉ đèn)

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/light/+/reported
sb/v1/hust/lab01/gw-ubuntu-01/devices/light/+/event
```

### Cloud backend

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/reported
sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/telemetry
sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/event
sb/v1/hust/lab01/gw-ubuntu-01/commands/+/reply
sb/v1/hust/lab01/gw-ubuntu-01/gateway/online
```

### Gateway (nhận từ cloud)

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/desired
sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request
sb/v1/hust/lab01/gw-ubuntu-01/ota/campaigns/+/manifest
sb/v1/hust/lab01/gw-ubuntu-01/ota/devices/+/desired
sb/v1/hust/lab01/gw-ubuntu-01/groups/+/desired
sb/v1/hust/lab01/gw-ubuntu-01/scenes/+/desired
```

### Debug (chỉ dùng ngắn hạn, không dùng production)

```text
sb/v1/hust/lab01/gw-ubuntu-01/#
```

## Quy tắc thiết kế

1. **Namespace cố định**: `sb/v1/{tenant}/{site}/{gateway}/...` — không đổi tên.
2. **Tên channel cố định**: `registry`, `reported`, `desired`, `telemetry`, `event`, `request`, `reply`.
3. **`device_type` trong topic**: cho phép wildcard theo loại thiết bị; giá trị cũng nằm trong payload `device_type`.
4. **Verb lệnh trong payload, không trong topic**: dùng `.../request` với `op` trong payload, không bao giờ `.../cmd/on`.
5. **Source trong payload, không trong topic**: dùng trường `source`, không bao giờ `iot/labA/mobile/...`.
6. **Wildcard chỉ dùng phía subscriber**: publisher luôn dùng topic name cụ thể.
7. **Chỉ thêm topic mới, không đổi tên topic cũ**: tương thích ngược là bắt buộc.
