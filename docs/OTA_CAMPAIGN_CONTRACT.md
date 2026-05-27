# OTA Campaign Contract

## Contract status

This document is the planned OTA rollout contract. It is intentionally separated
from the currently implemented Cloud/Gateway runtime.

Current repo audit:

- Cloud has no `ota_campaigns`, `ota_targets`, or `ota_events` ORM models yet.
- Cloud has no `/api/ota/*` router yet.
- Z3Gateway C contains Silicon Labs OTA cluster configuration/autogen files, but
  no project-owned MQTT OTA runtime in `gateway/Z3GatewayHost/app/` yet.
- Therefore Cloud can only create a campaign record after the data model exists.
  A real rollout requires the Gateway capability checklist below.

Cloud coordinates OTA rollout through metadata only. Z3Gateway C owns artifact
download, local staging, Zigbee OTA offer, progress, terminal events, cancel, and
rollback behavior.

Z3Gateway C never publishes firmware binary over MQTT.

External references used for this contract:

- Silicon Labs Zigbee OTA image creation: Image Builder creates a `.ota`
  over-the-air file from a `.gbl` Gecko Bootloader file, and Commander creates
  the `.gbl` from the application image.
  https://docs.silabs.com/zigbee/latest/ota-bootload-server-client-setup-zigbee-sdk-v7x-higher/05-ota-image-creation
- Silicon Labs Zigbee OTA hands-on: the Z3Gateway host app is the OTA server
  side, and the generated `.ota` image is placed in the `ota-files` folder beside
  the Z3Gateway executable for the OTA run.
  https://docs.silabs.com/zigbee/latest/ota-bootload-server-client-setup-zigbee-sdk-v7x-higher/06-zigbee-ota-hands-on-tutorial
- AWS IoT OTA model: an OTA update is an orchestrated update object with targets,
  files, code-signing resources, and a device-side agent that downloads, stores,
  verifies, and installs the image.
  https://docs.aws.amazon.com/freertos/latest/userguide/ota-manager.html

## Operation vocabulary vs MQTT topic shape

Some tasks describe OTA as MQTT operations:

| Operation name | Contract meaning | MQTT representation |
| --- | --- | --- |
| `ota.start` | Cloud starts or resumes a rollout target | publish campaign `manifest`, then device `desired` with `action: "stage_and_offer"` |
| `ota.cancel` | Cloud cancels a rollout target | publish device `cancel` with `action: "cancel"` |
| `ota.progress` | Gateway reports rollout progress | gateway publishes device `progress` |
| `ota.complete` | Gateway reports terminal success | gateway publishes device `event` with `event: "complete"` and final `progress.status: "completed"` |

The operation names are vocabulary for API, logs, and tests. They are not topic
names. The MQTT contract remains topic-based so subscribers can route with stable
wildcards.

## MQTT Topics

```text
sb/v1/{tenant}/{site}/{gateway}/ota/campaigns/{campaign_id}/manifest
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/desired
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/cancel
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/progress
sb/v1/{tenant}/{site}/{gateway}/ota/devices/{device_id}/event
```

Topic roles:

| Topic suffix | Direction | Retain | Meaning |
| --- | --- | --- | --- |
| `ota/campaigns/{campaign_id}/manifest` | Cloud -> Gateway | yes | campaign artifact metadata and rollout policy |
| `ota/devices/{device_id}/desired` | Cloud -> Gateway | yes | target-specific rollout intent |
| `ota/devices/{device_id}/cancel` | Cloud -> Gateway | no | cancel a target or campaign execution path |
| `ota/devices/{device_id}/progress` | Gateway -> Cloud | yes | latest target state snapshot |
| `ota/devices/{device_id}/event` | Gateway -> Cloud | no | append-only milestone/failure event |

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

Required artifact metadata:

| Field | Reason |
| --- | --- |
| `manufacturer_id` | must match Zigbee OTA image header and target device |
| `image_type` | selects the correct firmware family |
| `file_version` | prevents flashing the same or lower version by mistake |
| `stack_version` | documents SDK/stack compatibility |
| `size_bytes` | guards against truncated or wrong files |
| `sha256` | guards against corrupt or replaced files |
| `url` | lets Gateway download the artifact directly |

## Device Desired Payload

```json
{
  "campaign_id": "ota-camp-001",
  "action": "stage_and_offer"
}
```

## Cancel Payload

```json
{
  "campaign_id": "ota-camp-001",
  "action": "cancel",
  "reason": "operator_cancelled"
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

Allowed target statuses:

```text
pending -> staging -> staged -> offering -> downloading -> applying -> completed
                                  |             |             |
                                  v             v             v
                              canceling      failed       failed
                                  |
                                  v
                               canceled

rollback_pending -> rolled_back | failed
```

## Event Payload

Events are non-retained and describe failures or terminal rollout milestones.
Cloud must store them append-only for audit.

```json
{
  "device_id": "light-01",
  "campaign_id": "ota-camp-001",
  "event": "artifact_stage_failed",
  "reason": "checksum mismatch"
}
```

Allowed event names:

```text
artifact_stage_started
artifact_staged
artifact_stage_failed
offer_started
download_progress
complete
failed
cancel_requested
canceled
rollback_requested
rolled_back
```

## Internal OTA Flow (inside Z3Gateway C)

After successful staging, Z3Gateway C handles the OTA offer internally:

1. Z3Gateway C subscribes to `ota/campaigns/{campaign_id}/manifest` and
   `ota/devices/{device_id}/desired`
2. On receiving a manifest, it downloads the artifact via HTTP, verifies checksum and
   size, and stores it under `SB_OTA_DIR` (default `./ota-files`)
3. On receiving `ota_desired` with `action: "stage_and_offer"`, it locates the staged
   artifact and initiates native Zigbee OTA offer to the target device
4. On receiving `ota/devices/{device_id}/cancel`, it stops the target path if the
   native OTA runtime can safely cancel at the current stage
5. Progress and events are published directly to MQTT by Z3Gateway C

This is an **internal function call** within the Z3Gateway C process — there is no
IPC handoff or intermediate bridge process.

> **Historical note:** earlier versions of this contract described an "IPC Handoff"
> where a bridge process forwarded an `ota_desired` IPC record to a local adapter.
> That architecture has been replaced. Z3Gateway C handles the entire OTA lifecycle
> as a single process.

## Gateway capability checklist

Cloud-side OTA manager only orchestrates. Before claiming real OTA rollout, the
Gateway must provide these capabilities:

| Gateway capability | Meaning |
| --- | --- |
| Subscribe OTA manifest / desired / cancel topics | Receive Cloud OTA intent |
| Download artifact URL | Gateway downloads firmware itself |
| Verify `sha256` + `size_bytes` | Reject wrong or corrupt artifact |
| Store into `SB_OTA_DIR` | Keep local staged artifact |
| Native ZCL OTA server/client flow | Deliver firmware to Zigbee end-device |
| Publish progress/event/complete/failed | Let Cloud track target state |
| Cancel path | Stop a rollout that is still cancelable |
| Rollback path | Return to a previous version or execute rollback policy |

## Firmware artifact pipeline prerequisites

Minimum prerequisites before OTA campaign creation:

| Requirement | Purpose |
| --- | --- |
| Real `.ota` or `.gbl` artifact | File Gateway downloads for OTA |
| Metadata: `manufacturer_id`, `image_type`, `file_version`, `stack_version`, `size_bytes`, `sha256` | Gateway and end-device validate correct firmware |
| Static file hosting or object storage | Stable internal artifact URL |
| SHA256 generation script | Avoid hand-typed checksum mistakes |
| Version policy | Prevent flashing lower/same firmware version accidentally |

`.gbl` is the Gecko Bootloader OTA upgrade image. `.s37` is the primary Commander
flash image and should not be treated as the OTA campaign artifact unless the
Gateway/runtime explicitly supports that format.

For this project, SCRUM-8 should use artifact URL + metadata over MQTT instead of
sending firmware bytes as a MQTT payload. MQTT carries the operation intent
(`ota.start`, `ota.cancel`) and status (`ota.progress`, `ota.complete`); HTTP or
static/object storage carries the firmware artifact itself.

## Cloud data model proposal

Do not add a migration until this state machine is accepted. Minimum tables:

### `ota_campaigns`

```text
id
name
artifact_url
sha256
size_bytes
file_version
manufacturer_id
image_type
device_type
status: draft | staged | running | canceling | completed | failed | rolled_back
rollout_policy
rollback_policy
created_at
updated_at
started_at
completed_at
```

### `ota_targets`

```text
id
campaign_id
device_id
gateway_id
status: pending | staging | staged | offering | downloading | applying | completed | failed | canceled | rollback_pending | rolled_back
progress_pct
retry_count
last_error
current_fw_version
target_fw_version
updated_at
```

### `ota_events`

```text
id
campaign_id
device_id nullable
event_type
payload_json
created_at
```

`ota_events` is append-only. Never update old event rows in place because OTA
needs an audit trail.

## Targeting phases

Targeting must be conservative:

| Phase | Targeting scope | Reason |
| --- | --- | --- |
| 1 | single device | safest first implementation path |
| 2 | explicit device list | still auditable and avoids hidden grouping logic |
| 3 | device group | only after a real `device_groups` model exists |

Do not implement group targeting as a free-form string. OTA to the wrong group is
a high-impact failure.
