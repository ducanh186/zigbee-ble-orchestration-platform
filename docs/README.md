# Documentation Index

This folder is the documentation for the IoT Smart Building / Zigbee orchestration platform. Production architecture: **single-process Z3Gateway C with direct MQTT integration**.

For the operational runbook see [`instruct.md`](./instruct.md).

## Contracts (frozen, do not break)

- [`MQTT_CONTRACT.md`](./MQTT_CONTRACT.md) — topic namespace, envelope, per-device-type payloads.
- [`PROVISIONING_CONTRACT.md`](./PROVISIONING_CONTRACT.md) — secure install-code join flow across Mobile App, Cloud, and Gateway.
- [`AUTOMATION_MQTT_CONTRACT.md`](./AUTOMATION_MQTT_CONTRACT.md) — automation rule desired / reported / event channels (extends `MQTT_CONTRACT.md`).
- [`OTA_CAMPAIGN_CONTRACT.md`](./OTA_CAMPAIGN_CONTRACT.md) — OTA rollout metadata flow.
- [`DEVICE_CAPABILITY_MATRIX.md`](./DEVICE_CAPABILITY_MATRIX.md) — per-`device_type` capabilities (v1 freeze).
- [`ADAPTER_ACTION_MAP.md`](./ADAPTER_ACTION_MAP.md) — MQTT → Z3Gateway C action mapping.

## Architecture

- [`plan.md`](./plan.md) — current architecture plan (Z3Gateway-native, single process).
- [`UART_FRAME_FORMAT.md`](./UART_FRAME_FORMAT.md) — host ↔ NCP boundary and process layout.

## Hardware / firmware

- [`FLASHING.md`](./FLASHING.md) — how to flash every board, build matrix, artifact inventory, tracking policy.

## Runbook

- [`instruct.md`](./instruct.md) — end-to-end bring-up, vận hành, debug. Session notes appended over time.

## Automation feature docs

- [`AUTOMATION_APP_DESIGN_BRIEF.md`](./AUTOMATION_APP_DESIGN_BRIEF.md) — mobile screen design brief.
- [`AUTOMATION_USER_GUIDE.md`](./AUTOMATION_USER_GUIDE.md) — end-user / demo guide.
