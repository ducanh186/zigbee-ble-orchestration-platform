# Gateway and Local Zigbee Security Requirements

Last updated: 2026-06-01

Status: IMPLEMENTATION_REQUIRED

This document is the implementation contract for the Gateway and local Zigbee
owners. It turns the production security audit into concrete work that must be
completed and evidenced before stable production readiness can be claimed.

It does not claim that production readiness is complete. Live gateway hardware,
broker, and radio evidence remains required.

## Scope

In this document, "local Zigbee" means the local runtime below the Cloud/MQTT
boundary:

```text
Cloud API
  -> Mosquitto MQTT over TLS/mTLS
  -> Native Z3Gateway host app
  -> EFR32 NCP / local Zigbee stack
  -> Zigbee end devices
```

Repository areas in scope:

| Area | Repo path | Owner responsibility |
|---|---|---|
| Gateway host app | `gateway/Z3GatewayHost/app/` | MQTT client, command parsing, command dispatch, logging, runtime identity. |
| Gateway Zigbee config | `gateway/Z3GatewayHost/config/` | Trust Center, network creator security, permit join, key policy. |
| NCP/local Zigbee firmware | `end_devices/ncp-uart-hw-fresh/` | NCP firmware build, serial boundary, stack security support. |
| End-device firmware | `end_devices/Z3Light/`, `end_devices/Z3Switch/`, `end_devices/Z3_Occupancy_Sensor/` | Device join, rejoin, install-code identity, secure operational behavior. |
| Production docs | `docs/production/` | Evidence, operator procedure, and release readiness boundary. |

Out of scope for this document:

- Real certificate/private-key generation.
- Real production passwords or raw secrets.
- Stable production readiness approval.
- Cloud/App auth implementation details, except where Gateway depends on them.

## Security Target

The target is a Gateway and local Zigbee path that is secure by default:

1. Gateway production mode fails fast without explicit MQTT identity,
   credentials, and TLS/mTLS certificate paths.
2. Gateway connects to the broker through TLS/mTLS only in production.
3. Gateway accepts join commands only through the Cloud-controlled
   `gateway.prepare_join` path.
4. Permit join is closed by default and short-lived when opened.
5. Zigbee joining requires per-device install-code material.
6. Default global key joins and insecure well-known-key rejoins are rejected.
7. Runtime logs never expose install codes, MQTT passwords, private-key paths
   with secret content, bearer tokens, or raw certificate material.
8. Production readiness stays blocked until live hardware negative tests pass.

## Gateway Requirements

| ID | Requirement | Evidence required |
|---|---|---|
| GW-SEC-01 | Production mode must fail fast when `SB_ENV=production` or `SB_PRODUCTION=1` and any required MQTT host, port, username, password, tenant id, site id, gateway id, CA cert, client cert, or client key value is missing. | Static test or startup log showing failure for one missing required value; source reference in `gateway/Z3GatewayHost/app/app_mqtt.c`. |
| GW-SEC-02 | Production Gateway MQTT must use TLS/mTLS to broker port `8883`; plain `1883` is development-only and must not be part of the secure production compose path. | `mosquitto_tls_set` source reference, production env example, and broker connection log with TLS enabled. |
| GW-SEC-03 | Gateway identity must be runtime-configurable per physical gateway. Do not hardcode production tenant/site/gateway identity in source. | Source or env evidence for `SB_TENANT_ID`, `SB_SITE_ID`, and `SB_GATEWAY_ID`; topic sample using the configured identity. |
| GW-SEC-04 | Gateway must reject commands whose topic or payload targets a different gateway identity. | Negative test log showing a mismatched gateway id command is ignored or rejected. |
| GW-SEC-05 | Gateway command parsers must reject missing, malformed, oversized, or unsupported `gateway.prepare_join` payloads before touching Zigbee join state. | Tests or logs for missing `eui64`, bad `eui64`, missing `install_code`, bad `install_code`, and out-of-range duration. |
| GW-SEC-06 | Gateway must not log raw install codes, MQTT passwords, private keys, bearer tokens, or full command payloads containing secrets. | No-secret log scan from one provisioning run and one failed provisioning run. |
| GW-SEC-07 | Permit join must be closed by default. Opening join must happen only after a valid Cloud-originated `gateway.prepare_join` command. | Boot log showing closed join state; successful secure join log tied to one `gateway.prepare_join` command id. |
| GW-SEC-08 | Permit join duration must be bounded and short. The current Cloud contract uses `1..180` seconds; Gateway must also clamp or reject unsafe values. | Negative test for over-limit duration and successful test within limit. |
| GW-SEC-09 | Gateway reply/events must include enough operational evidence without leaking secrets: command id, status, reason, gateway id, EUI64 when safe, and sanitized error code. | Sample accepted, failed, and rejected command replies. |
| GW-SEC-10 | Any remote CLI, debug TCP port, raw socket, or local management channel must be disabled in production or restricted to localhost/SSH/VPN-only operator access. | Config or operator firewall evidence; if a channel remains enabled, document bind address and access control. |

## Local Zigbee Requirements

| ID | Requirement | Evidence required |
|---|---|---|
| LZ-SEC-01 | Trust Center joins must require install-code-derived key material for production commissioning. | `network-creator-security-config.h` evidence and a successful install-code join log. |
| LZ-SEC-02 | Devices using the default global Zigbee key must fail to join during a production secure join window. | Live negative radio test log showing rejection and no registry row/event for the device. |
| LZ-SEC-03 | Well-known-key rejoin paths must be disabled or explicitly rejected for production. | Gateway security config evidence and one rejoin negative test if hardware supports the scenario. |
| LZ-SEC-04 | Network-key update policy must be production-appropriate and operator-approved. Development/test timing must not be used silently in production. | Config diff or operator decision record for Trust Center network-key update interval. |
| LZ-SEC-05 | NCP UART/ASH access must be physically local or protected by OS permissions. Do not expose raw NCP control over a public network port. | Host service config, permissions, or deployment diagram showing the NCP boundary is local-only. |
| LZ-SEC-06 | End devices must use unique identity material. Install codes and QR payloads must not be reused across production devices. | Manufacturing/provisioning record format with redacted examples; no raw install code in git. |
| LZ-SEC-07 | End-device firmware must not print install codes, link keys, network keys, or trust center keys over serial logs in production builds. | Log scan from each production firmware family: light, switch, motion. |
| LZ-SEC-08 | End-device rejoin behavior must be tested after power cycle and after Trust Center key update. | Live rejoin test log that proves legitimate devices can recover without enabling default-key joins. |

## Required Evidence Bundle

Before a stable production release can claim this path is ready, attach an
evidence bundle to the release ticket with these files or equivalent records:

```text
gateway-build.txt
gateway-production-env.redacted.txt
gateway-mqtt-mtls-connect.log
gateway-prepare-join-success.log
gateway-prepare-join-malformed-negative.log
zigbee-install-code-join-success.log
zigbee-default-key-join-rejected.log
zigbee-rejoin-policy.log
ncp-boundary-evidence.txt
end-device-log-scan-light.txt
end-device-log-scan-switch.txt
end-device-log-scan-motion.txt
no-secret-scan-summary.txt
```

Rules for the bundle:

- Redact passwords, private keys, raw install codes, bearer tokens, and full
  certificate/private-key contents.
- Include firmware build id, gateway hardware id, NCP firmware id, and test
  timestamp.
- Include pass/fail outcome and operator name for every live hardware test.
- Keep raw secrets outside git and outside pull-request descriptions.

## Acceptance Checklist

Gateway owner must complete:

- [ ] `GW-SEC-01` production fail-fast evidence captured.
- [ ] `GW-SEC-02` MQTT TLS/mTLS connection evidence captured.
- [ ] `GW-SEC-03` runtime gateway identity evidence captured.
- [ ] `GW-SEC-04` wrong-gateway command rejection evidence captured.
- [ ] `GW-SEC-05` malformed `gateway.prepare_join` rejection evidence captured.
- [ ] `GW-SEC-06` no-secret gateway log scan completed.
- [ ] `GW-SEC-07` permit join closed by default and secure open path proven.
- [ ] `GW-SEC-08` unsafe permit duration rejection proven.
- [ ] `GW-SEC-09` sanitized command reply/event samples captured.
- [ ] `GW-SEC-10` debug/CLI/local management exposure decision recorded.

Local Zigbee owner must complete:

- [ ] `LZ-SEC-01` install-code join success evidence captured.
- [ ] `LZ-SEC-02` default global key join rejection evidence captured.
- [ ] `LZ-SEC-03` well-known-key rejoin rejection evidence captured or explicitly accepted by operator risk review.
- [ ] `LZ-SEC-04` production network-key update policy recorded.
- [ ] `LZ-SEC-05` NCP UART/ASH boundary evidence captured.
- [ ] `LZ-SEC-06` unique end-device identity material process recorded.
- [ ] `LZ-SEC-07` end-device no-secret serial log scans completed.
- [ ] `LZ-SEC-08` legitimate end-device rejoin recovery evidence captured.

Release owner must complete:

- [ ] Evidence bundle attached to the release or production-readiness ticket.
- [ ] `docs/production/production-final-report.md` updated with live evidence status.
- [ ] No raw secret appears in tracked docs, PR descriptions, commit messages, or logs.
- [ ] Stable production release remains blocked until all required live evidence is present or explicitly accepted by the operator.

## Negative Test Matrix

| Test | Expected result |
|---|---|
| Start Gateway in production mode with missing MQTT password. | Startup fails before connecting. |
| Start Gateway in production mode with missing client key path. | Startup fails before connecting. |
| Connect Gateway to production broker without client certificate. | Broker rejects connection. |
| Publish command with a different gateway id. | Gateway ignores or rejects command. |
| Send `gateway.prepare_join` without `install_code`. | Gateway rejects command and does not open join. |
| Send `gateway.prepare_join` with invalid EUI64. | Gateway rejects command and does not open join. |
| Send `gateway.prepare_join` with duration above policy. | Gateway rejects or clamps according to documented policy. |
| Attempt default global key device join during permit window. | Join fails; Cloud has no accepted registry row for that device. |
| Power-cycle a legitimate installed device. | Device rejoins without enabling insecure global-key path. |
| Scan Gateway and end-device logs for secret patterns. | No raw install code, key, password, or bearer token is present. |

## Relationship To Existing Production Docs

- `docs/production/production-gateway.md` records local static Gateway config evidence.
- `docs/production/production-mqtt.md` records broker TLS/mTLS and ACL evidence.
- `docs/production/production-commissioning.md` records secure commissioning source evidence and live negative procedure.
- This document is the cross-team checklist that tells Gateway and local Zigbee owners what to implement and what evidence to return.

When evidence is collected, update this document only with sanitized references.
Do not paste raw secrets or full private logs into git.
