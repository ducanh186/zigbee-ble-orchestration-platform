# MQTT Broker

Thư mục này chứa cấu hình Mosquitto local cho namespace `sb/v1` của gateway bridge.

> **Contract đầy đủ**: xem [docs/MQTT_CONTRACT.md](../docs/MQTT_CONTRACT.md) — bao gồm envelope schema, cây topic, ví dụ payload, wildcard subscription, và quy tắc thiết kế.

## Các file cấu hình

| File | Mô tả |
| --- | --- |
| `config/mosquitto.conf` | Cấu hình chính của broker (listener, auth, persistence, log) |
| `config/acl.conf` | Phân quyền topic theo user — xem [Tài khoản](#tài-khoản) |
| `config/bridge.conf` | Bridge local → EC2 (chỉ dùng trên máy gateway, không deploy lên EC2) |
| `docker/docker-compose.yml` | Docker Compose cho broker local |

## Namespace

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

Giá trị mặc định khi phát triển: `tenant_id = hust`, `site_id = lab01`, `gateway_id = gw-ubuntu-01`.

## Bảng topic tổng hợp

Tất cả topic đều nằm dưới prefix `sb/v1/{tenant}/{site}/{gateway}/` (viết tắt `…/`).

| Tài nguyên | Topic | QoS | Retain | Ghi chú |
| --- | --- | --- | --- | --- |
| Gateway online | `…/gateway/online` | 1 | có | LWT — xem [Contract § Retain và QoS](../docs/MQTT_CONTRACT.md#retain-và-qos) |
| Gateway health | `…/gateway/health` | 1 | có | |
| Gateway log | `…/gateway/log` | 0 | không | |
| Device registry | `…/devices/{type}/{id}/registry` | 1 | có | |
| Device reported | `…/devices/{type}/{id}/reported` | 1 | có | |
| Device desired | `…/devices/{type}/{id}/desired` | 1 | có | |
| Device telemetry | `…/devices/{type}/{id}/telemetry` | 0 | không | Dữ liệu cảm biến tần suất cao |
| Device event | `…/devices/{type}/{id}/event` | 1 | không | |
| Command request | `…/commands/{cmd_id}/request` | 1 | không | |
| Command reply | `…/commands/{cmd_id}/reply` | 1 | không | |
| OTA manifest | `…/ota/campaigns/{camp_id}/manifest` | 1 | có | |
| OTA desired | `…/ota/devices/{id}/desired` | 1 | có | |
| OTA progress | `…/ota/devices/{id}/progress` | 1 | có | |
| OTA event | `…/ota/devices/{id}/event` | 1 | không | |
| Group reported | `…/groups/{grp_id}/reported` | 1 | có | |
| Group desired | `…/groups/{grp_id}/desired` | 1 | không | |
| Scene desired | `…/scenes/{scene_id}/desired` | 1 | không | |
| Scene event | `…/scenes/{scene_id}/event` | 1 | không | |

## Chạy local

```bash
cd mqtt/docker
docker compose up -d
```

Docker Compose yêu cầu có sẵn:

- `mqtt/passwords/passwd` — file mật khẩu đã hash
- `mqtt/data/` — thư mục persistence (tự tạo nếu chưa có)

## Tài khoản

Phân quyền chi tiết nằm trong `config/acl.conf`.

| User | Quyền | Mục đích |
| --- | --- | --- |
| `gateway` | đọc/ghi toàn bộ namespace | Gateway bridge — publish/subscribe mọi topic |
| `client` | đọc state/health/log/reply/progress/event; ghi desired/request/manifest | Cloud backend, dashboard, mobile app |
| `monitor` | chỉ đọc toàn bộ + `$SYS/#` | Giám sát, healthcheck |
| `bridge` | đọc/ghi toàn bộ namespace | Bridge local ↔ EC2 |

## Cổng mạng

| Cổng | Giao thức |
| --- | --- |
| `1883` | MQTT |
| `9001` | MQTT over WebSocket |
