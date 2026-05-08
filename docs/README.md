# Documentation

This folder contains all documentation relating to this project.

## Architecture

The production architecture is **Z3Gateway C single-process** with **direct MQTT integration**.
See [plan.md](./plan.md) for the frozen architecture and [UART_FRAME_FORMAT.md](./UART_FRAME_FORMAT.md)
for boundary definitions.

## Key Documents

| File | Content |
|---|---|
| [MQTT_CONTRACT.md](./MQTT_CONTRACT.md) | MQTT topic tree, envelope, QoS, retain |
| [UART_FRAME_FORMAT.md](./UART_FRAME_FORMAT.md) | Native boundary + application architecture |
| [ADAPTER_ACTION_MAP.md](./ADAPTER_ACTION_MAP.md) | MQTT ↔ Z3Gateway C action mapping |
| [DEVICE_CAPABILITY_MATRIX.md](./DEVICE_CAPABILITY_MATRIX.md) | device_type × capability freeze |
| [OTA_CAMPAIGN_CONTRACT.md](./OTA_CAMPAIGN_CONTRACT.md) | OTA artifact staging workflow |
| [CLOUD_IMPLEMENTATION_PLAN.md](./CLOUD_IMPLEMENTATION_PLAN.md) | Cloud DB schema + API design |
| [plan.md](./plan.md) | Gateway architecture plan (frozen) |
| [iot_zigbee_sprint_plan.md](./iot_zigbee_sprint_plan.md) | Original sprint plan (historical) |
| [FLASHING.md](./FLASHING.md) | Firmware flashing instructions |
| [FIRMWARE_ARTIFACTS.md](./FIRMWARE_ARTIFACTS.md) | Pre-built firmware binaries |