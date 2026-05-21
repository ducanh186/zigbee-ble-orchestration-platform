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
| [AUTOMATION_CONTRACT.md](./AUTOMATION_CONTRACT.md) | Automation rule contract and SCRUM-51 implementation audit note |
| [OTA_CAMPAIGN_CONTRACT.md](./OTA_CAMPAIGN_CONTRACT.md) | Planned OTA campaign contract, artifact staging prerequisites, Gateway capability checklist |
| [SCRUM_51_EVIDENCE_AND_SCRUM_8_READY_AUDIT.md](./SCRUM_51_EVIDENCE_AND_SCRUM_8_READY_AUDIT.md) | SCRUM-51 evidence gap audit and SCRUM-8 definition of ready |
| [CLOUD_IMPLEMENTATION_PLAN.md](./CLOUD_IMPLEMENTATION_PLAN.md) | Cloud DB schema + API design |
| [AUTOMATION_USER_GUIDE.md](./AUTOMATION_USER_GUIDE.md) | User guide for the Automation feature |
| [plan.md](./plan.md) | Gateway architecture plan (frozen) |
| [FLASHING.md](./FLASHING.md) | Firmware flashing instructions |
| [FIRMWARE_ARTIFACTS.md](./FIRMWARE_ARTIFACTS.md) | Pre-built firmware binaries |
