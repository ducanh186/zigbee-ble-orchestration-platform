# Native Boundary and IPC Frame Format

## Native Mode Boundary

For this repository, the production architecture is **Z3Gateway-native only**.

That means:

- `Ubuntu host <-> NCP radio` uses **EZSP/ASH**
- the serial/UART link between host and EFR32 is **owned by Z3Gateway**
- this repository does **not** define any custom `@DATA/@CMD/@ACK` application protocol on that serial link

In other words, there is no project-specific application UART frame format for the host-radio boundary in native mode.

## Application Boundary Used By This Repo

The application contract implemented by this repo is:

```text
Z3Gateway adapter <-> local IPC socket <-> MQTT bridge
```

Transport:

- Unix domain socket
- default path: `/tmp/sb-gateway.sock`
- one full-duplex adapter connection at a time

Wire format:

- NDJSON
- UTF-8
- one JSON object per line

## IPC Record Schema

Common fields:

```json
{
  "v": 1,
  "kind": "reported",
  "msg_id": "0df5d2c39615483e87679b5411696cc4",
  "ts": "2026-03-19T07:20:00Z",
  "source": "adapter",
  "trace_id": "trace-01",
  "correlation_id": "cmd-01",
  "device_id": "light-01",
  "command_id": "cmd-01",
  "campaign_id": "ota-camp-01",
  "status": "executed",
  "payload": {}
}
```

Required fields:

- `v`
- `kind`
- `msg_id`
- `ts`
- `source`
- `payload`

Optional fields:

- `trace_id`
- `correlation_id`
- `device_id`
- `command_id`
- `campaign_id`
- `status`

## IPC Kinds

### Adapter -> bridge

- `registry`
- `reported`
- `event`
- `gateway_health`
- `gateway_log`
- `command_reply`
- `ota_progress`
- `ota_event`

### Bridge -> adapter

- `desired`
- `command_request`
- `ota_manifest`
- `ota_desired`

## Examples

### Reported device state

```json
{"v":1,"kind":"reported","msg_id":"7cfaf7eb8d7e4c0ca3d166714d165ecb","ts":"2026-03-19T07:21:00Z","source":"adapter","device_id":"light-01","payload":{"device_id":"light-01","device_type":"light","eui64":"00124b0001aa22bb","nwk_addr":"0x4F2A","state":{"power":"on","level":180,"reachable":true}}}
```

### Desired state forwarded from MQTT

```json
{"v":1,"kind":"desired","msg_id":"94c75323c9b34558bf806b44a0fb2ced","ts":"2026-03-19T07:22:00Z","source":"cloud","device_id":"light-01","payload":{"device_id":"light-01","desired":{"power":"off"}}}
```

### Command request forwarded from MQTT

```json
{"v":1,"kind":"command_request","msg_id":"5eaf455478bb4118b02ddb0f65b8696a","ts":"2026-03-19T07:23:00Z","source":"cloud","device_id":"light-01","command_id":"cmd-01","correlation_id":"cmd-01","payload":{"device_id":"light-01","op":"device.command","target":{"endpoint":1,"cluster_id":"0x0006","command":"off"},"timeout_ms":5000}}
```

### Command reply from adapter

```json
{"v":1,"kind":"command_reply","msg_id":"90c3d5c8d70a4929b680e011d2f4b0b1","ts":"2026-03-19T07:23:01Z","source":"adapter","device_id":"light-01","command_id":"cmd-01","status":"executed","payload":{"device_id":"light-01","status":"executed","reason":null}}
```
