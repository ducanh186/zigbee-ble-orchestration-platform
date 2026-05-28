# SCRUM-55 — Zigbee Security Baseline (Install-code TC join policy + reject default link key)

**Status:** Design approved (brainstorming Q1-Q4 + Section 1-2 ack 2026-05-28).
**Companion:** [PROVISIONING_CONTRACT.md](../../PROVISIONING_CONTRACT.md) §7 + §8.
**Ticket:** [SCRUM-55](https://hust-lab-iot-project.atlassian.net/browse/SCRUM-55).
**Branch:** `feat/55-zigbee-security-baseline` (off `main`).

## 1. Goal

Build the gateway-side **security primitive** that lets a Zigbee device join only when its install code has been pre-staged on the gateway. Reject any join attempt using the global default `ZigBeeAlliance09` link key. SCRUM-69's MQTT `gateway.prepare_join` op and the local commissioning CLI will later both call into this primitive — SCRUM-55 owns the primitive and the CLI; SCRUM-69 owns the MQTT plumbing.

## 2. Non-goals

- MQTT `gateway.prepare_join` op (SCRUM-69)
- `provisioning_joined` / `provisioning_failed` MQTT events (SCRUM-69)
- Device-side QR display (SCRUM-80 — already done)
- Reading install codes from manufacturing tokens on devices (Phase P1b)
- Provisioning session state machine (Cloud-side, SCRUM-70 etc.)

## 3. Architecture

Three-layer separation (per user's clarification):

```
┌──────────────── App / Mobile (SCRUM-77) ─────────────────┐
│   scans QR → POST /api/provisioning/sessions             │
└──────────────────────────┬───────────────────────────────┘
                           │ REST
┌──────────────────────────v───────────────────────────────┐
│   Cloud (SCRUM-70/71/72)                                  │
│   creates session → MQTT op gateway.prepare_join          │
└──────────────────────────┬───────────────────────────────┘
                           │ MQTT
┌──────────────────────────v───────────────────────────────┐
│   Gateway HOST (Z3GatewayHost)                            │
│   ┌─ SCRUM-69 (MQTT layer, future) ──────────────────┐    │
│   │  cmd_handler.c → dispatchGatewayOp                │    │
│   │  case "gateway.prepare_join":                     │    │
│   │     → netMgrOpenForJoinSecure(eui, ic, ic_len, s) │    │
│   └────────────────────┬──────────────────────────────┘    │
│                        │ same staging API                  │
│   ┌────────────────────v── SCRUM-55 (this spec) ─────┐    │
│   │  Local commissioning path:                        │    │
│   │  CLI: pjoin-secure <secs> <eui> <ic>              │    │
│   │     → netMgrOpenForJoinSecure(eui, ic, ic_len, s) │    │
│   │                                                    │    │
│   │  netMgrOpenForJoinSecure:                          │    │
│   │     ├─ secMgrStage(eui, ic, ic_len, secs)          │    │
│   │     └─ netMgrOpenForJoin(secs)  (existing)         │    │
│   │                                                    │    │
│   │  emberAfPluginNetworkCreatorSecurityGetInstallCodeCallback │
│   │     → secMgrLookup(eui)                            │    │
│   │                                                    │    │
│   │  Stack derives TC link key from IC via AES-MMO     │    │
│   └────────────────────┬──────────────────────────────┘    │
└────────────────────────┼───────────────────────────────────┘
                         │ EZSP
                         v
                ┌─────────────────┐
                │  NCP firmware   │  (no change)
                └─────────────────┘
```

## 4. Module boundaries

| File | Role | LOC est. |
|---|---|---|
| **NEW** `gateway/Z3GatewayHost/app/sec_mgr.c` | install-code staging + TC callback + EZSP policy init | ~180 |
| **NEW** `gateway/Z3GatewayHost/app/sec_mgr.h` | public API for net_mgr + CLI | ~30 |
| `gateway/Z3GatewayHost/app/net_mgr.{c,h}` | add `netMgrOpenForJoinSecure()` thin wrapper; tick `secMgrTick()` | +35 |
| `gateway/Z3GatewayHost/app/device_registry.c` | extend `emberAfTrustCenterJoinCallback` with secure-key-type log | +10 |
| `gateway/Z3GatewayHost/app/cmd_handler.c` | register CLI command `pjoin-secure` | ~50 |
| `gateway/Z3GatewayHost/config/network-creator-security-config.h` | flip `BDB_JOIN_USES_INSTALL_CODE_KEY` 0→1 | 1 |
| `gateway/Z3GatewayHost/Z3Gateway.project.mak` | register sec_mgr.c | +1 |

No NCP firmware change. No MQTT contract change. No new topic tree.

## 5. Public sec_mgr API

```c
// sec_mgr.h
#ifndef SEC_MGR_H
#define SEC_MGR_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "app/framework/include/af.h"

// Max IC length per Zigbee BDB spec (16-byte code + 2-byte CRC).
#define SEC_MGR_IC_MAX_LEN 18u

// Set Trust Center policies (DENY_TC_LINK_KEY_REQUESTS, etc.) via EZSP.
// Call once after stack init from emberAfMainInitCallback.
void secMgrInit(void);

// Stage an install code bound to a specific EUI64. Returns false if all
// slots are full or arguments are invalid (length not in {8,10,14,18}).
// duration_sec drives TTL = (duration_sec * 1000) + grace_ms (grace ~2000).
// eui64_le must be Ember little-endian (callers convert from big-endian hex).
bool secMgrStage(const uint8_t eui64_le[8],
                 const uint8_t *ic_bytes,
                 size_t         ic_len,
                 uint32_t       duration_sec);

// Look up staged IC for an EUI64 (callable from TC callback). Returns true
// and fills out_ic (caller-allocated, >= SEC_MGR_IC_MAX_LEN) + *out_len on
// hit; returns false on miss or expired slot.
bool secMgrLookup(const uint8_t eui64_le[8],
                  uint8_t      *out_ic,
                  size_t       *out_len);

// Periodic TTL sweep. Call from netMgrTick().
void secMgrTick(void);

#endif
```

## 6. Storage

```c
// sec_mgr.c
#define SEC_MGR_MAX_SLOTS 4u    // 4 concurrent commissionings; ~200 B static
#define SEC_MGR_TTL_GRACE_MS 2000u

typedef struct {
    bool      used;
    uint8_t   eui64_le[8];
    uint8_t   ic_bytes[SEC_MGR_IC_MAX_LEN];
    uint8_t   ic_len;
    uint32_t  ttl_deadline_ms;
} sec_slot_t;

static sec_slot_t g_slots[SEC_MGR_MAX_SLOTS];
```

On TTL expiry the slot is `memset(0)` so the IC does not linger in `.bss` for a core-dump inspector.

## 7. TC callback

```c
// sec_mgr.c (Silicon Labs SDK signature)
EmberStatus emberAfPluginNetworkCreatorSecurityGetInstallCodeCallback(
    EmberEUI64  newNodeEui64,
    uint8_t    *installCode,
    uint8_t    *installCodeLength)
{
    size_t len;
    if (!secMgrLookup(newNodeEui64, installCode, &len)) {
        *installCodeLength = 0;
        return EMBER_NOT_FOUND;       // stack denies join
    }
    *installCodeLength = (uint8_t)len;
    return EMBER_SUCCESS;
}
```

No log statement inside the callback (contract §7: never log raw IC).

## 8. EZSP policy init (in `secMgrInit`)

```c
// Disallow remote TC link key requests by default (contract §3.1 of Jira spec).
ezspSetPolicy(EZSP_TC_KEY_REQUEST_POLICY,
              EMBER_DENY_TC_LINK_KEY_REQUESTS /* 0x00 */);
```

`ALLOW_TC_REJOIN_WITH_WELL_KNOWN_KEY` is already `0` in config — verify and document.

## 9. CLI command

Registered via the existing `sl_cli` framework (the gateway's network-cli plugin already brings it in).

Signature:
```
pjoin-secure <duration_sec> <eui64-hex-be> <install-code-hex>
   duration_sec: 1..180
   eui64-hex-be: 16 hex chars (big-endian, contract format)
   install-code-hex: 16 / 20 / 28 / 36 hex chars (8/10/14/18 bytes)
```

Handler steps:
1. Validate duration_sec ∈ [1, 180].
2. Parse EUI64 big-endian hex → Ember little-endian via existing `parseHexEui64`.
3. Parse install-code hex → bytes. Validate length ∈ {8, 10, 14, 18}.
4. Call `netMgrOpenForJoinSecure(eui_le, ic_bytes, ic_len, duration_sec)`.
5. Print result (success or failure reason) — but never echo the IC back.
6. Log via `appLogLog("SEC", "stage", "eui64=%s duration_sec=%u")` — IC bytes NOT in the log.

Avoid name collision with the built-in `pjoin` (which is broadcast permit-join with default key) by using a distinct command name `pjoin-secure`.

## 10. Trust-Center join callback (existing, extended)

In `device_registry.c::emberAfTrustCenterJoinCallback`:

```c
// existing logic preserved; ADD:
const char *key_type;
switch (status) {
    case EMBER_STANDARD_SECURITY_SECURED_REJOIN:        key_type = "secured-rejoin"; break;
    case EMBER_STANDARD_SECURITY_UNSECURED_JOIN:        key_type = "unsecured-join"; break;
    case EMBER_STANDARD_SECURITY_SECURED_JOIN:          key_type = "secured-join"; break;
    case EMBER_DEVICE_LEFT:                              key_type = "left"; break;
    default:                                             key_type = "other"; break;
}
appLogLog("TC", "join", "\"eui64\":\"%s\",\"status\":\"0x%02X\",\"type\":\"%s\"",
          euiHexBE, (unsigned)status, key_type);
```

A successful install-code-derived join surfaces as `secured-join` with `decisionId` indicating IC-derived. This is the operator's positive-test signal.

## 11. Config header flip

```diff
- #define EMBER_AF_PLUGIN_NETWORK_CREATOR_SECURITY_BDB_JOIN_USES_INSTALL_CODE_KEY   0
+ #define EMBER_AF_PLUGIN_NETWORK_CREATOR_SECURITY_BDB_JOIN_USES_INSTALL_CODE_KEY   1
```

`ALLOW_TC_REJOIN_WITH_WELL_KNOWN_KEY` stays at 0 (verify post-build via autogen symbol).

## 12. Build & integration

Per repo's `CLAUDE.md` Z3Gateway round-trip:
1. Edit files in repo.
2. Stop running gateway (`kill $(cat /tmp/z3gw.pid)`, wait for `/dev/ttyACM0`).
3. Sync touched files to `~/ss_v5/v5_workspace/Z3GatewayHost/`.
4. Build in workspace: `make -f Z3Gateway.Makefile -j$(nproc) debug`.
5. Copy `build/debug/Z3Gateway` back to `gateway/Z3Gateway/Z3GatewayHost/build/debug/Z3Gateway`.
6. Restart gateway per `docs/instruct.md §G`.

The `sec_mgr.c` must be added to `Z3Gateway.project.mak` `APP_FILES` (or whatever the makefile uses for app sources).

## 13. Test plan

### 13.1 Source-level

| Test | Expected |
|---|---|
| `secMgrStage` 4 slots full → 5th call | returns `false` |
| `secMgrStage` IC length 7 / 11 / 17 | returns `false` (not in {8,10,14,18}) |
| `secMgrLookup` after stage | hit, returns IC bytes |
| `secMgrLookup` 1 ms before TTL | hit |
| `secMgrLookup` 1 ms after TTL | miss; slot wiped |
| `secMgrLookup` non-staged EUI | miss |
| `secMgrTick` 2× TTL | all expired slots wiped |
| no `printf`/`appLogLog`/`emberAfCorePrintln` reference to `ic_bytes` | confirmed by `grep` |

### 13.2 Hardware (log-based proxy — no sniffer)

**Setup:** Coordinator (NCP) running, gateway running, one **factory-fresh** end-device kit (Z3Light EUI `0000000000000055`).

**Happy path:**
1. Operator: `pjoin-secure 60 0000000000000055 <real-install-code-from-kit>` in gateway CLI.
2. End-device powered up (or button-resets).
3. Gateway log within 5 s: `@TC join eui64=0000000000000055 status=0x90 type=secured-join`.
4. Existing device-registry MQTT publish proceeds normally.
5. CLI `network info` shows the device joined.

**Negative path 1 — no stage:**
1. End-device powered up *without* prior `pjoin-secure`.
2. Operator: builtin `pjoin 60` (broadcast, default key).
3. End-device tries to join with ZigBeeAlliance09.
4. Gateway log: TC callback fires with `status=EMBER_NOT_FOUND` (or `0x06`), `type=other`. **No `secured-join` line.** Device join fails.

**Negative path 2 — wrong IC:**
1. Operator: `pjoin-secure 60 0000000000000055 <garbage-but-valid-length>`.
2. End-device tries to join.
3. Stack derives a wrong TC link key from the wrong IC; APS frame can't be decrypted by device.
4. Device association fails. Gateway log shows incomplete join sequence.

Evidence: capture all three runs to `testing_tools/evidence/SCRUM-55/{happy,no-stage,wrong-ic}.log` (gitignored).

## 14. Open questions / risks

1. **CLI registration site.** `sl_cli` requires either a static command table OR runtime registration. Z3GatewayHost's `cmd_handler.c` is an MQTT command handler, not CLI. The CLI handler should likely live in `sec_mgr.c` and be registered via the SDK's standard CLI macro (`SL_CLI_COMMAND_*`). To verify in implementation: how Z3GatewayHost currently registers custom commands.
2. **EZSP enum name.** `EZSP_TC_KEY_REQUEST_POLICY` is the policy ID; `EMBER_DENY_TC_LINK_KEY_REQUESTS = 0x00` is the value. SDK header names may vary by version — verify at compile time.
3. **TTL clock source.** Gateway uses `msTick()` (gettimeofday-based, see `app_utils.c`). Wraps every 49 days — acceptable; staging windows are ≤180 s.
4. **Rebuild round-trip vs the binary copy-back path.** `CLAUDE.md` says copy binary back to `gateway/Z3Gateway/Z3GatewayHost/build/debug/Z3Gateway` but earlier P0 audit §9 flagged this directory layout as drifted from actual repo. Will validate during implementation.

## 15. Acceptance checklist

```
[ ] Code changes per §4 module boundary
[ ] Source tests per §13.1 all pass
[ ] Happy-path HW test per §13.2 → secured-join log
[ ] Negative path 1 (no stage) → no join, log shows reject
[ ] Negative path 2 (wrong IC) → no join, log shows fail
[ ] grep proves zero raw-IC log statements
[ ] PR opened against main with link to this spec
[ ] SCRUM-55 transitioned to Done in Jira
```
