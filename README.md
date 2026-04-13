# IoT Smart Building Platform

Nền tảng quản lý thiết bị IoT Zigbee/BLE cho tòa nhà thông minh, xây dựng trên kiến trúc Z3Gateway-native.

## Kiến trúc

```
Flutter App ──HTTP──▶ Cloud API (FastAPI :8000) ◄──▶ Mosquitto (:1883) ◄──MQTT──▶ Gateway Bridge ◄──IPC──▶ Z3Gateway ◄──EZSP/ASH──▶ EFR32 NCP ◄──Zigbee──▶ End Devices
                           │ SQLite
                           ▼
                        cloud.db
```

| Thành phần | Mô tả | Trạng thái |
|---|---|---|
| **Gateway Bridge** (`gateway/`) | Cầu nối MQTT ↔ IPC, chạy trên Linux cạnh coordinator Zigbee | Done |
| **Cloud Backend** (`cloud/`) | FastAPI REST API + MQTT subscriber, quản lý device/state/command | Done |
| **MQTT Broker** (`mqtt/`) | Mosquitto broker config + Docker Compose | Done |
| **Deploy Scripts** (`deploy/`) | Auto deploy lên AWS EC2 từ Windows (PowerShell) | Done |

## Cấu trúc repository

```
gateway/          Gateway MQTT ↔ IPC bridge 
cloud/            Cloud backend — FastAPI REST API + MQTT subscriber 
mqtt/             Local Mosquitto broker configuration
deploy/           EC2 deployment scripts (PowerShell) + docker-compose
docs/             Architecture contracts, sprint plan, implementation plans
end_devices/      End device firmware 
mobile_app/       Mobile app code 
```

## Git Workflow Rules

### Branch Naming

- Format: `prefix/<jira-ticket-id>-<branch-description>`
- Allowed prefix: `feature`, `bugfix`
- Ví dụ: `feature/1-create-code-base`

### Pull Request Rules

- Tất cả code phải merge vào `main` qua pull request.
- Không được commit/merge trực tiếp vào `main`.
- Mỗi pull request phải được approve trước khi merge.