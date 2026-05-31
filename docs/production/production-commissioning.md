# Production Secure Commissioning Evidence

Last updated: 2026-06-01 03:34:10 +07:00

Jira: SCRUM-97

Status: VERIFIED_LOCALLY

## Scope

This phase hardens the Zigbee commissioning path. The production target is not simply "open permit join"; it is:

1. Cloud creates a bounded `gateway.prepare_join` command with one EUI64 and one install code.
2. The gateway parses that command without logging the raw install code.
3. The gateway stages the install code for that EUI64 through `netMgrOpenForJoinSecure`.
4. Zigbee BDB security rejects default global key joins.

## Source Evidence

| Contract | Evidence |
|---|---|
| Permit join duration is bounded at the API edge. | `cloud/app/schemas.py` keeps `CommissioningOpenBody.duration_sec` at `1..180`. |
| Backend permit-join open/close is admin-only. | `cloud/app/routers/gateways.py` uses `require_admin`; `cloud/tests/test_gateways.py` covers unauthenticated, operator-forbidden, and admin-allowed cases. |
| Provisioning publishes install-code join intent. | `cloud/app/routers/provisioning.py` publishes `gateway.prepare_join` with `eui64`, `install_code`, and `duration_sec`. |
| Gateway parses the secure join target. | `gateway/Z3GatewayHost/app/sb_command.h` and `.c` parse `eui64` and `install_code` from the command body. |
| Gateway uses the secure join path. | `gateway/Z3GatewayHost/app/device_dispatch.c` validates `eui64`, `install_code`, and duration before calling `netMgrOpenForJoinSecure`. |
| Install-code security is enabled. | `gateway/Z3GatewayHost/config/network-creator-security-config.h` sets `BDB_JOIN_USES_INSTALL_CODE_KEY` to `1`. |
| Default global key rejoin is disabled. | The same config sets well-known key rejoin flags to `0`. |

## Negative Procedure

Run this on real gateway hardware before a production cutover:

1. Start the gateway with production MQTT/TLS settings from `docs/production/production-gateway.md`.
2. Create a provisioning session through the backend so it publishes `gateway.prepare_join` with a known EUI64 and install code.
3. Attempt to join the matching Zigbee device with the correct install code.
4. Confirm the device joins and the gateway emits `permit_join_opened` without logging the raw install code.
5. Reset or use a second test device that only has the default global key.
6. Attempt to join during the same short permit-join window.
7. Confirm the default global key device is rejected and no registry entry is created.

Local repository verification cannot perform the live radio negative test. The required local guardrail is that source and config make the insecure path unavailable by default.

## Local Verification

Command:

```text
python -m pytest cloud/tests/test_secure_commissioning_contract.py -q
```

Expected result after Phase 5 implementation:

```text
4 passed
```

Full cloud regression should also pass:

```text
python -m pytest cloud/tests -q
```

## Deferred Live Evidence

- Capture gateway logs from one successful install-code join.
- Capture gateway logs from one rejected default global key join.
- Record the exact gateway firmware build and hardware serial.
- Attach the log bundle to `SCRUM-97` or the release ticket before final production readiness is claimed.
