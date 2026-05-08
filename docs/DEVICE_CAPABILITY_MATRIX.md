# Device Capability Matrix (v1)

Tài liệu này **đóng băng** tập năng lực (capability) của từng `device_type` cho Phase 0.
Mọi publisher/subscriber MQTT, Z3Gateway C, và cloud service **phải** tuân theo danh sách này.
Bất kỳ mở rộng nào đều phải đưa vào phase sau, không được âm thầm thêm vào v1.

Xem thêm:

- Namespace và envelope: [MQTT_CONTRACT.md](./MQTT_CONTRACT.md)
- Ánh xạ MQTT ↔ Z3Gateway C action: [ADAPTER_ACTION_MAP.md](./ADAPTER_ACTION_MAP.md)
- Ranh giới native và MQTT: [UART_FRAME_FORMAT.md](./UART_FRAME_FORMAT.md)

---

## Các `device_type` chính thức v1

- `light`
- `switch`
- `motion`

**Chuẩn hoá tên**: đối ngoại (MQTT topic + `payload.device_type`) dùng `motion`.
Các tên cũ như `occ`, `occupancy` chỉ là từ vựng nội bộ/legacy — **không** xuất hiện trên
MQTT.

> Trong `payload.state`, cảm biến `motion` vẫn dùng giá trị `occupied` / `unoccupied`
> để mô tả trạng thái đo được (đó là giá trị *trạng thái*, không phải *device_type*).

`lock` và `unknown` có thể xuất hiện trong topic (hợp lệ theo contract) nhưng **không
thuộc v1 freeze** — chưa có capability chính thức.

---

## 1. Light

### Lệnh (commands — MQTT `commands/.../request` hoặc `devices/.../desired`)

| `op` / field | Kiểu | Bắt buộc | Ghi chú |
| --- | --- | --- | --- |
| `on` | command | có | Bật đèn |
| `off` | command | có | Tắt đèn |
| `set_level` | command | có | Đặt mức sáng, kèm `level ∈ [0..254]` |

Dạng gửi qua `commands/{command_id}/request`:

```json
{
  "device_id": "light-01",
  "op": "device.command",
  "target": {
    "endpoint": 1,
    "cluster_id": "0x0006",
    "command": "on"
  },
  "timeout_ms": 5000
}
```

Dạng gửi qua `devices/light/{device_id}/desired`:

```json
{
  "device_id": "light-01",
  "desired": { "power": "on", "level": 180 }
}
```

### Trạng thái báo cáo (reported — `devices/light/{device_id}/reported`)

| Trường state | Kiểu | Bắt buộc | Ghi chú |
| --- | --- | --- | --- |
| `power` | `"on" \| "off"` | có | Bắt buộc cho mọi reported |
| `level` | int `0..254` | có | Cluster Level Control (0x0008) |
| `reachable` | bool | có | Gateway suy ra từ last-seen / TX result |

### Event (nếu có)

Không có event bắt buộc cho `light` ở v1. Gateway có thể phát `event` cho các
tình huống bất thường (mất liên lạc, rejoin, …) nhưng cloud consumer **không** được
phụ thuộc vào chúng cho logic nghiệp vụ.

---

## 2. Switch

Thiết bị này là *remote control* phía client (ZCL On/Off cluster client-side).
Nó **không** nhận lệnh điều khiển — nó phát event do người dùng bấm.

### Lệnh

Không có. Gateway **không** chấp nhận `commands/.../request` hoặc
`devices/switch/.../desired` cho `device_type = switch` trong v1.

### Event (event — `devices/switch/{device_id}/event`)

| Trường `payload.event` | Kiểu | Bắt buộc | Ghi chú |
| --- | --- | --- | --- |
| `toggle` | enum event | có | Người dùng bấm nút; gateway phát event khi nhận ZCL On/Off command từ switch |

Ví dụ payload:

```json
{
  "device_id": "switch-01",
  "device_type": "switch",
  "event": "toggle",
  "eui64": "00124b0001bb33cc",
  "nwk_addr": "0x7A12"
}
```

### Trạng thái báo cáo (reported tối thiểu)

| Trường state | Kiểu | Bắt buộc | Ghi chú |
| --- | --- | --- | --- |
| `reachable` | bool | có | Chỉ bắt buộc `reachable`; không có `power/level` |
| `battery` | int `0..100` | không | Nếu thiết bị hỗ trợ Power Configuration (0x0001) |

---

## 3. Motion

### Lệnh

Không có. Gateway **không** chấp nhận `commands/.../request` hoặc
`devices/motion/.../desired` cho `device_type = motion` trong v1.

### Trạng thái báo cáo (reported — `devices/motion/{device_id}/reported`)

| Trường state | Kiểu | Bắt buộc | Ghi chú |
| --- | --- | --- | --- |
| `occupancy` | `"occupied" \| "unoccupied"` | có | Từ Occupancy Sensing cluster (0x0406) |
| `reachable` | bool | có | |
| `battery` | int `0..100` | không | Nếu thiết bị hỗ trợ Power Configuration (0x0001) |

Ví dụ payload:

```json
{
  "device_id": "motion-01",
  "device_type": "motion",
  "eui64": "00124b0001cc44dd",
  "nwk_addr": "0x9D01",
  "state": {
    "occupancy": "occupied",
    "reachable": true,
    "battery": 87
  }
}
```

### Event

Không bắt buộc ở v1. Các thay đổi occupancy được biểu diễn qua `reported`.

---

## Ma trận tổng hợp

| device_type | Commands | Events | Required state | Optional state |
| --- | --- | --- | --- | --- |
| `light` | `on`, `off`, `set_level` | — | `power`, `level`, `reachable` | — |
| `switch` | — | `toggle` | `reachable` | `battery` |
| `motion` | — | — | `occupancy`, `reachable` | `battery` |

---

## Không thuộc v1 (deferred)

Các mục sau **có** trong contract/topic tree nhưng **không** nằm trong Phase 0 freeze.
Cloud/adapter không được yêu cầu hỗ trợ chúng ở v1:

- OTA (`ota/...` topics)
- Groups (`groups/...`)
- Scenes (`scenes/...`)
- `device_type = lock`, `device_type = unknown` (hợp lệ trong contract, không có capability chính thức)
- Light capability mở rộng: color, color temperature, transition time
- Motion capability mở rộng: illuminance, temperature

---

## Nguyên tắc

1. **Không thêm capability mới** vào v1 nếu chưa cập nhật tài liệu này.
2. **Normalize tên** ở biên MQTT: `motion` (không dùng `occ`/`occupancy`).
3. **Giá trị state** `occupied`/`unoccupied` được giữ lại vì đó là *giá trị đo*,
   không phải *loại thiết bị*.
4. **Cloud consumer chỉ được dựa vào required fields**. Optional fields phải
   coi là có thể vắng.
