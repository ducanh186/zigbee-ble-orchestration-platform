# OTA Campaign Contract

## Goal

Cloud coordinates OTA rollout through metadata only.

Z3Gateway C:

1. receives the campaign manifest directly over MQTT
2. downloads the `.ota` artifact from `artifact.url`
3. verifies `sha256` and `size_bytes`
4. stores the file under `SB_OTA_DIR`
5. offers the staged file to the target device through native Zigbee OTA behavior

Z3Gateway C never publishes firmware binary over MQTT.

## MQTT Topics

```text
sb/v1/{tenant}/{site}/{gateway}/ota/campaigns/{campaign_id}/manifest
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/progress
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/event
```

## Manifest Payload

```json
{
  "campaign_id": "ota-camp-001",
  "target": {
    "device_type": "light",
    "manufacturer_id": "0x1002",
    "image_type": "0x0001",
    "min_fw_version": 2,
    "max_fw_version": 2
  },
  "artifact": {
    "url": "https://example.com/light_v3.ota",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "size_bytes": 184320,
    "file_version": 3,
    "stack_version": "zigbee-8.x"
  },
  "rollout": {
    "batch_size": 5,
    "window_start": "2026-03-19T23:00:00Z",
    "window_end": "2026-03-20T05:00:00Z"
  },
  "policy": {
    "allow_on_battery": false,
    "required_online_sec": 300,
    "max_retry": 3
  }
}
```

## Device Desired Payload

```json
{
  "campaign_id": "ota-camp-001",
  "action": "stage_and_offer"
}
```

## Progress Payload

Z3Gateway C uses retained progress messages as the latest device snapshot for rollout state.

```json
{
  "device_id": "light-01",
  "campaign_id": "ota-camp-001",
  "status": "staging",
  "progress_pct": 0
}
```

```json
{
  "device_id": "light-01",
  "campaign_id": "ota-camp-001",
  "status": "staged",
  "progress_pct": 100
}
```

## Event Payload

Events are non-retained and describe failures or terminal rollout milestones.

```json
{
  "device_id": "light-01",
  "campaign_id": "ota-camp-001",
  "event": "artifact_stage_failed",
  "reason": "checksum mismatch"
}
```

## Internal OTA Flow (inside Z3Gateway C)

After successful staging, Z3Gateway C handles the OTA offer internally:

1. Z3Gateway C subscribes to `ota/campaigns/{campaign_id}/manifest` and
   `ota/devices/{device_id}/desired`
2. On receiving a manifest, it downloads the artifact via HTTP, verifies checksum and
   size, and stores it under `SB_OTA_DIR` (default `./ota-files`)
3. On receiving `ota_desired` with `action: "stage_and_offer"`, it locates the staged
   artifact and initiates native Zigbee OTA offer to the target device
4. Progress and events are published directly to MQTT by Z3Gateway C

This is an **internal function call** within the Z3Gateway C process — there is no
IPC handoff or intermediate bridge process.

> **Historical note:** earlier versions of this contract described an "IPC Handoff"
> where a bridge process forwarded an `ota_desired` IPC record to a local adapter.
> That architecture has been replaced. Z3Gateway C handles the entire OTA lifecycle
> as a single process.
