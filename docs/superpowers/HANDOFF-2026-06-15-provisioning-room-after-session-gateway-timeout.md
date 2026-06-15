# Handoff: Provisioning Room After Session + Gateway Timeout

Date: 2026-06-15
Branch: `feat/automation-home-room-ux-redesign`

## What changed

- Mobile provisioning now starts the Cloud provisioning session before asking for a room.
- Cloud now allows `provisioning_sessions.room_id = NULL` at session creation.
- Mobile assigns room after session creation with:
  - `PATCH /api/provisioning/sessions/{session_id}/room`
- Gateway `gateway.prepare_join` contract is unchanged:
  - target only needs `eui64`, `install_code`, `duration_sec`
  - Gateway does not need `room_id` for the join command
- Cloud stores the chosen room on the session and uses it when the device joins.

## Production deployment done

- Deployed Cloud files into `sb-cloud-api`.
- Ran Alembic migration:
  - `20260615_01_provisioning_room_after_session`
- Verified production DB:
  - `provisioning_sessions.room_id` is nullable.
  - `alembic_version = 20260615_01`
- Reset production device data for fresh provisioning:
  - `TRUNCATE TABLE devices CASCADE`
  - cascaded to `device_states`, `events`, `commands`, `provisioning_sessions`
- Preserved factory payload/install code:
  - `0000000000000053 | sensor | EFR32MG12_ENV_KIT | install_code length 36`

## APK

Release APK built and installed via ADB:

- `mobile_app/build/app/outputs/flutter-apk/app-release.apk`
- size: `71119344`
- installed package:
  - `versionCode=1204`
  - `versionName=1.2.4`

## Verification already run

Local verification:

- `python -m pytest cloud/tests/test_provisioning.py -q`
  - `45 passed`
- `python -m pytest cloud/tests/test_provisioning.py cloud/tests/test_rooms.py cloud/tests/test_automations.py -q`
  - `91 passed`
- `flutter analyze`
  - no issues
- `flutter test`
  - `159 passed`
- focused mobile re-run:
  - `flutter test test/provisioning_view_test.dart test/remote_provisioning_repository_test.dart`
  - `13 passed`

ADB/runtime verification:

- App parsed scanned QR correctly:
  - `EUI64 = 0000000000000053`
  - `Type = environment`
  - `Model = EFR32MG12_ENV_KIT`
- Cloud no longer returns `422`.
- Cloud logs show the new expected flow:
  - `POST /api/provisioning/sessions` -> `201 Created`
  - `PATCH /api/provisioning/sessions/{id}/room` -> `200 OK`
  - Cloud publishes `gateway.prepare_join`

Screenshots:

- `mobile_app/test_artifacts/adb-qr-camera-ready-2026-06-15.png`
- `mobile_app/test_artifacts/adb-after-start-room-dialog-2026-06-15.png`
- `mobile_app/test_artifacts/adb-provisioning-failed-gateway-timeout-2026-06-15.png`

## Current blocker

The remaining failure is not the mobile QR payload or Cloud validation.

Current runtime failure:

- App shows `FAILED`
- Reason: `cloud-side timeout expired`
- DB shows latest `gateway.prepare_join` commands timing out.
- Cloud publishes command, but no `commands/{id}/reply` is received.
- Mosquitto socket check showed only Cloud connected to broker:
  - `172.19.0.3:8883 -> 172.19.0.4:37467`
- EC2 Docker only has:
  - `sb-cloud-api`
  - `sb-nginx`
  - `sb-mosquitto`
  - `sb-postgres`
- No Gateway container/process is visible on EC2.

## What teammate should fix next

Focus on Gateway connectivity/reply path:

1. Confirm the real Gateway host/process is running and connected to Mosquitto.
2. Confirm it subscribes to the Cloud command topic for:
   - `gateway.prepare_join`
3. Confirm it publishes replies to:
   - `sb/v1/hust/lab01/gw-ubuntu-01/commands/{command_id}/reply`
4. Retry provisioning after Gateway is online.

Expected success evidence:

- Cloud log has MQTT reply for the command.
- Command status changes from `accepted` to `executed` or a specific Gateway-side failure.
- Session transitions past `pending`/timeout.
- On real device join, Cloud receives `provisioning_joined` and creates a `devices` row with:
  - `eui64 = 0000000000000053`
  - `device_type = sensor`
  - selected `room_id`

## Important notes

- Do not put `room_id` back into `gateway.prepare_join`; that was the wrong coupling.
- `room_id` is now a Cloud/session assignment concern.
- Install code is still required for secure join and should stay in `factory_devices`, not in API responses.
