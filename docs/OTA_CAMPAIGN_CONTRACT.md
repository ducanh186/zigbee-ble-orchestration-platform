# OTA Campaign Contract

## Goal

Cloud coordinates OTA rollout through metadata only.

The gateway:

1. receives the campaign manifest over MQTT
2. downloads the `.ota` artifact from `artifact.url`
3. verifies `sha256` and `size_bytes`
4. stores the file under `SB_OTA_DIR`
5. forwards normalized OTA intent to the local adapter over IPC

The gateway never publishes firmware binary over MQTT.

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

The gateway uses retained progress messages as the latest device snapshot for rollout state.

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

## IPC Handoff

After successful staging, the bridge forwards an `ota_desired` IPC record that includes:

- `device_id`
- `campaign_id`
- `action`
- normalized manifest payload
- `local_artifact_path`

That handoff allows the local adapter to offer the staged file through native Zigbee OTA behavior without re-downloading or using MQTT as a binary channel.
