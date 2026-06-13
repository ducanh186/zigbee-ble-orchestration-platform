# Manufacturing Install Code And Gateway Handoff

## Purpose

This document hands off the remaining Gateway verification and automation
compatibility work after hotfix `v1.2.4`.

The security decision is fixed:

- Manufacturing uploads the Install Code to Cloud.
- QR labels contain public identity only.
- Mobile never receives or stores the Install Code.
- Cloud sends the secret to Gateway only in `gateway.prepare_join`.

## Current Join Implementation

Gateway already contains the main secure-join path:

- `gateway/Z3GatewayHost/app/device_dispatch.c` accepts
  `gateway.prepare_join`, checks EUI-64 and Install Code, and applies the join
  duration.
- `gateway/Z3GatewayHost/app/sec_mgr.c` stages the Install Code by EUI-64 with
  a time-to-live and wipes released slots.
- `gateway/Z3GatewayHost/app/device_registry.c` publishes the joined event for
  a device that had a staged entry.

Do not replace this with a QR-carried secret or the Zigbee default global key.

## Command Contract

Cloud publishes:

```json
{
  "op": "gateway.prepare_join",
  "target": {
    "eui64": "00124B0000000001",
    "install_code": "<SERVER_OWNED_INSTALL_CODE>",
    "duration_sec": 180
  }
}
```

Required behavior:

1. Validate the EUI-64 and Install Code including CRC.
2. Stage the key only for the requested EUI-64.
3. Bound the join window by `duration_sec`.
4. Never log the Install Code or MQTT payload containing it.
5. Zero-wipe the staged key after join, expiry, cancellation, or replacement.
6. Report an explicit command acknowledgement and provisioning result.

## Manufacturing Integration Verification

Run this gate with a non-production test kit:

1. Register the kit with `deploy/manufacturing-register.ps1` or
   `deploy/manufacturing-register.sh`.
2. Confirm the generated QR contains no `install_code`.
3. Scan the QR in Mobile and create a provisioning session.
4. Confirm Cloud publishes one `gateway.prepare_join` for the matching EUI-64.
5. Confirm Gateway logs only EUI-64, duration, status, and reason.
6. Join the device and confirm the session reaches `joined`.
7. Confirm the staged secret is no longer available after completion.
8. Retry with an unregistered EUI-64 and confirm the join is rejected.

## Schedule Automation Continuation

Observed on 2026-06-13:

- Mobile successfully created a schedule rule.
- Cloud returned HTTP `201`.
- Cloud cron executed the schedule.
- Gateway reported `unsupported_trigger` while syncing the desired rule.

The rejection is expected from the current parser:

- `gateway/Z3GatewayHost/app/automation_rule.c` accepts switch, motion, and
  environment event triggers.
- A Cloud schedule trigger has `type: "schedule"` and no event
  `device_type`, so it reaches the unsupported-trigger path.

Cloud is already the cron execution owner. The recommended next contract is:

1. Do not add an independent Gateway cron engine without an explicit product
   decision.
2. Make schedule desired documents non-failing:
   - either Cloud omits Cloud-owned schedule rules from Gateway event-rule
     sync; or
   - Gateway recognizes `type: "schedule"` and acknowledges it as Cloud-owned
     without installing an event evaluator.
3. Keep device actions flowing through the existing command path when Cloud
   cron fires.

The Cloud and Gateway owners must choose one acknowledgement strategy so the
rule does not show a false sync failure.

## Schedule Acceptance Tests

- Event rules continue to sync and execute locally as before.
- Schedule rule creation remains HTTP `201`.
- The schedule executes once from Cloud at the expected time.
- Gateway no longer reports `unsupported_trigger` for the Cloud-owned rule.
- The action command reaches the intended device.
- No second execution occurs from a duplicate Gateway scheduler.

## Security Acceptance Tests

- Repository, CLI output, Cloud response, QR JSON, SVG, APK, and release notes
  contain no production Install Code.
- Gateway logs contain no Install Code.
- An expired staged key cannot authorize a later join.
- A key staged for EUI-64 A cannot authorize EUI-64 B.
- Well-known-key joins remain disabled in production.

## Definition Of Done

- Manufacturing registration is demonstrated from both Windows and Ubuntu.
- A printed public QR provisions a registered device end to end.
- Secret redaction is verified in Cloud and Gateway logs.
- The schedule sync strategy is selected, implemented, and covered by tests.
- The Gateway team records firmware/build identity and test evidence in its PR.
