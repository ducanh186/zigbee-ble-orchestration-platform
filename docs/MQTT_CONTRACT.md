# MQTT Contract

## Namespace

All MQTT traffic uses:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

Default development values:

- `tenant_id = hust`
- `site_id = lab01`
- `gateway_id = gw-ubuntu-01`

## Common Envelope

Every MQTT payload uses the same JSON envelope:

```json
{
  "schema": "sb.v1",
  "msg_id": "e6f67ab087c64f1e9457a2f6e03f9a68",
  "ts": "2026-03-19T07:00:00Z",
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "trace_id": "trace-01",
  "correlation_id": "cmd-01",
  "payload": {}
}
```

Required fields:

- `schema`
- `msg_id`
- `ts`
- `tenant_id`
- `site_id`
- `gateway_id`
- `source`
- `payload`

Optional fields:

- `trace_id`
- `correlation_id`

## Topic Tree

### Gateway

```text
sb/v1/{tenant}/{site}/{gateway}/gateway/online
sb/v1/{tenant}/{site}/{gateway}/gateway/health
sb/v1/{tenant}/{site}/{gateway}/gateway/log
```

### Devices

```text
sb/v1/{tenant}/{site}/{gateway}/devices/{device_id}/registry
sb/v1/{tenant}/{site}/{gateway}/devices/{device_id}/reported
sb/v1/{tenant}/{site}/{gateway}/devices/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/devices/{device_id}/event
```

### Commands

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

## Retain and QoS

| Topic kind | QoS | Retained |
| --- | --- | --- |
| `gateway/online` | 1 | yes |
| `gateway/health` | 1 | yes |
| `gateway/log` | 0 | no |
| `devices/*/registry` | 1 | yes |
| `devices/*/reported` | 1 | yes |
| `devices/*/desired` | 1 | yes |
| `devices/*/event` | 1 | no |
| `commands/*/request` | 1 | no |
| `commands/*/reply` | 1 | no |
| `ota/campaigns/*/manifest` | 1 | yes |
| `ota/devices/*/desired` | 1 | yes |
| `ota/devices/*/progress` | 1 | yes |
| `ota/devices/*/event` | 1 | no |

`gateway/online` uses MQTT Last Will and Testament:

- LWT payload: retained envelope with `payload.value = "offline"`
- On successful connect: retained envelope with `payload.value = "online"`

## Command Lifecycle

The gateway publishes one reply message per lifecycle step:

```text
accepted -> queued -> sent -> executed | failed | timeout
```

Rules:

- `correlation_id` for every reply equals `{command_id}`
- `commands/{command_id}/reply` is never retained
- the gateway emits `accepted`, `queued`, and `sent`
- the adapter emits the terminal result, or the gateway emits `timeout`

Minimal reply payload example:

```json
{
  "status": "executed",
  "device_id": "light-01",
  "reason": null
}
```

## Identity Model

- `device_id`: logical stable identifier owned by the system
- `eui64`: stable hardware identifier carried inside payloads
- `nwk_addr`: runtime/debug field only, never a primary identifier

## Examples

### Device reported state

Topic:

```text
sb/v1/hust/lab01/gw-ubuntu-01/devices/light-01/reported
```

Payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "5c6d467f5f90460da65a9db62288def6",
  "ts": "2026-03-19T07:15:00Z",
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

### Command request

Topic:

```text
sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/request
```

Payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "fb5247dbeb4f480ebcb1e835a85d8182",
  "ts": "2026-03-19T07:16:00Z",
  "tenant_id": "hust",
  "site_id": "lab01",
  "gateway_id": "gw-ubuntu-01",
  "source": "cloud",
  "correlation_id": "cmd-01",
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
