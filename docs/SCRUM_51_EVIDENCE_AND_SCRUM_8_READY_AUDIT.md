# SCRUM-51 Evidence Audit and SCRUM-8 Definition of Ready

Audit date: 2026-05-21

Branch: `docs/51-scrum51-evidence-scrum8-ready`

## Summary

SCRUM-51 is marked Done in Jira, but the repo evidence is only partial. Local
Cloud and Mobile tests pass, yet the live EC2 + MQTT + Z3Gateway + EFR32 evidence
bundle is not present in the repository.

SCRUM-8 is ready as a contract direction, not as an implementation ticket unless
the team accepts the state machine and confirms gateway OTA runtime ownership.
The correct architecture is native Z3Gateway C, direct MQTT metadata, artifact
download by URL, checksum/size verification, and no Python bridge or IPC handoff.

## Verified Commands

```text
python -m pytest cloud/tests/ -q
Result: 80 passed in 7.15s

python -m pytest cloud/tests/test_automations.py cloud/tests/test_mqtt_client.py cloud/tests/test_automation_e2e.py cloud/tests/test_automation_events.py -q
Result: 26 passed in 5.16s

cd mobile_app
flutter test
Result: 56 passed
```

## SCRUM-51 Evidence Matrix

| Evidence item | Current repo evidence | Status |
| --- | --- | --- |
| API evidence | Local FastAPI tests cover automation create/update/delete, validation, retained desired publish, and automation event log. No EC2 Postman/curl capture found. | Partial |
| MQTT trace | Cloud tests use `FakeMQTTPublisher` and assert topic/payload shape. No real `mosquitto_sub` trace for the same demo run found. | Missing live evidence |
| Gateway log | Gateway code logs MQTT command subscription, switch events, command dispatch, and local switch skeleton. No live gateway log slice tied to SCRUM-51 found. | Missing live evidence |
| Cloud DB rows | In-memory SQLite tests assert `automations`, `events`, and `automation_events`. No EC2 PostgreSQL row export found. | Partial |
| Mobile screenshots/video | `mobile_app/test_artifacts/` contains screenshots, including automation screens, but they are not tied to a SCRUM-51 live E2E run. No video found. | Partial |

## Bug and Risk Check

### Occupancy

Mobile occupancy UI is implemented defensively: it normalizes `occupied`,
`unoccupied`, booleans, and `1/0` from `SmartDevice.state`.

Risk: the live gateway path is not complete in current code evidence. The gateway
detects/configures the Occupancy Sensing cluster, but `telemetry_rx.c` does not
show a publish path for `occupancy_changed` or a motion reported state update.
Cloud `_handle_event()` stores motion events as `Event` rows but does not update
`DeviceState`, while the device card reads `/api/devices/{id}/state`. Therefore
the mobile chip can work with seeded/API state, but live occupancy is not proven.

### Switch and Light Automation

Cloud validation accepts:

- switch trigger: `switch_toggle` or alias `toggle`
- motion trigger: `occupancy_changed` with `occupied` or `unoccupied`
- light action: `on`, `off`, or `toggle`

Risk: gateway dynamic automation sync is not implemented/proven. Cloud publishes
retained `desired/automation/{id}`, but `app_mqtt.c` currently subscribes only to
`commands/+/request`. No gateway subscriber/parser for `desired/automation/{id}`
was found. The local switch relay is disabled by default because direct Zigbee
binding owns switch-to-light toggle in the current hardware path.

### Dashboard State Reflection

Mobile dashboard reads latest state through:

```text
GET /api/devices
GET /api/devices/{id}/state
```

Cloud infers light state after executed command replies for `on` and `off`, and
gateway reported state can also update the dashboard. `toggle` depends on the
real reported state arriving later because Cloud cannot infer final toggle state
without knowing the previous device state. Motion occupancy needs a real
`DeviceState` update or the card remains `UNKNOWN`.

## SCRUM-8 Definition of Ready

SCRUM-8 should be considered ready for implementation only when these are agreed:

| Item | Ready condition |
| --- | --- |
| Architecture | Native Z3Gateway C owns OTA runtime. Cloud only orchestrates campaign metadata. |
| No deprecated bridge | No Python bridge, no IPC handoff, no MQTT-to-IPC adapter. |
| MQTT shape | Keep topic tree: `manifest`, `desired`, `cancel`, `progress`, `event`. Treat `ota.start`, `ota.cancel`, `ota.progress`, and `ota.complete` as API/log/test vocabulary, not topic names. |
| Artifact transport | MQTT never carries firmware binary. MQTT carries artifact URL, SHA256, size, version, manufacturer/image metadata, and progress/events. |
| Artifact pipeline | A real `.ota` or `.gbl` artifact exists, plus metadata, static/object hosting URL, SHA256 generation, and version policy. |
| Gateway runtime | Gateway subscribes OTA manifest/desired/cancel, downloads artifact, verifies SHA/size, stores under `SB_OTA_DIR`, offers via native Zigbee OTA, publishes progress/events, and supports cancel/rollback policy. |
| Cloud data model | `ota_campaigns`, `ota_targets`, and append-only `ota_events` state machine accepted before migration. |
| Targeting | Phase 1 single device, Phase 2 explicit device list, Phase 3 real device group model only. |

## External Research Notes

- Silicon Labs Zigbee docs describe Image Builder generating `.ota` from `.gbl`:
  https://docs.silabs.com/zigbee/latest/ota-bootload-server-client-setup-zigbee-sdk-v7x-higher/05-ota-image-creation
- Silicon Labs OTA tutorial describes Z3Gateway as the server side and places the
  `.ota` image under the `ota-files` folder beside the Z3Gateway executable:
  https://docs.silabs.com/zigbee/latest/ota-bootload-server-client-setup-zigbee-sdk-v7x-higher/06-zigbee-ota-hands-on-tutorial
- AWS IoT OTA uses an orchestrated update object with targets, files, code
  signing, and a device-side agent that downloads, stores, verifies, and installs
  the image:
  https://docs.aws.amazon.com/freertos/latest/userguide/ota-manager.html

## Recommended Order

1. Capture or regenerate SCRUM-51 live evidence on EC2 with one consistent
   timestamped run.
2. Fix gateway dynamic automation sync if SCRUM-51 must prove app-created rules
   executing on hardware.
3. Add live occupancy publish/state update before claiming occupancy works on
   physical PIR.
4. Keep SCRUM-8 in design-ready state until gateway OTA runtime scope is accepted.
