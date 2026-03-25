# Gateway Runtime

This package is the **Z3Gateway-native MQTT <-> IPC bridge**.

## Boundary

- `host <-> radio` is owned by **Z3Gateway** over **EZSP/ASH**
- this repo does **not** implement a custom application UART protocol on that link
- the bridge talks to a local adapter through:
  - Unix domain socket
  - NDJSON
  - default path `/tmp/sb-gateway.sock`

## MQTT Namespace

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

Core subscriptions:

- `devices/+/desired`
- `commands/+/request`
- `ota/campaigns/+/manifest`
- `ota/devices/+/desired`

Core publications:

- `gateway/online`
- `gateway/health`
- `gateway/log`
- `devices/*/registry`
- `devices/*/reported`
- `devices/*/event`
- `commands/*/reply`
- `ota/devices/*/progress`
- `ota/devices/*/event`

## Run

1. Install dependencies:

```bash
pip install -r gateway/requirements.txt
```

2. Create config:

```bash
cp gateway/.env.example gateway/.env
```

3. Start the bridge on Linux:

```bash
python -m gateway
```

4. Connect a local adapter to `/tmp/sb-gateway.sock`.

## Notes

- Runtime target is Linux/POSIX only.
- OTA files are staged under `SB_OTA_DIR` after checksum and size verification.
- Commands use lifecycle replies:
  `accepted -> queued -> sent -> executed | failed | timeout`
