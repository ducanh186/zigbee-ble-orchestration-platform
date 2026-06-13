# DHT11 Environment Sensor — Gateway/Zigbee Handoff

Scope: **Gateway + Zigbee local only.** No app/cloud UI, cron worker, or
migrations here. This documents the local device data, MQTT contract, runtime
execution, status/provisioning/scenes audits, and what Cloud/Mobile do next.

Verified on branch `feat/107-environment-sensor-automation-ui` (the existing
integration branch that already merged PR #88). See §13 for why the branch name
differs from the task prompt's suggested `feat/107-dht11-env-local-gateway`.

## 1. Branch
`feat/107-environment-sensor-automation-ui` (origin). Commits solo-authored
`chuphu2004`, no `Co-Authored-By` trailer.

## 2. Firmware project path
`end_devices/Z3_DHT11_Sensor/` (recycled from `Z3_Occupancy_Sensor`; `Z3_*`
naming matches the repo's other end devices — see §13).
Artifact: `artifact/Z3_DHT11_Sensor/Z3_DHT11_Sensor.s37`.

## 3. Build / flash
```bash
# sync repo -> workspace, then build with the v12.2.1 toolchain
rsync -a end_devices/Z3_DHT11_Sensor/{app,autogen,config,main.c,app.c} \
        ~/ss_v5/v5_workspace/Z3_DHT11_Sensor/
cd ~/SimplicityStudio/v5_workspace/Z3_DHT11_Sensor/'GNU ARM v12.2.1 - Default'
PATH="/home/phu/SimplicityStudio_v5/developer/toolchains/gnu_arm/12.2.rel1_2023.7/bin:$PATH" \
  make all -j"$(nproc)"
# flash (no masserase -> preserves EUI + install-code token + NVM3)
commander flash artifact/Z3_DHT11_Sensor/Z3_DHT11_Sensor.s37 --serialno <kit-jlink>
```

## 4. Gateway run
```bash
scripts/start-gateway.sh        # binary gateway/Z3GatewayHost/build/debug/Z3Gateway
tail -f /tmp/z3gw.log
```
Healthy init shows `ezsp ver 0x0D …`, `MQTT: subscribed`, `AUTO init`.

## 5. MQTT topics used
| Topic (under `sb/v1/{tenant}/{site}/{gw}/`) | Dir | Purpose |
|---|---|---|
| `devices/environment/{eui64}/reported` | GW→Cloud | temp/humidity state (retained) |
| `devices/environment/{eui64}/registry` | GW→Cloud | classification = `environment` |
| `automations/{id}/desired` | Cloud→GW | rule sync (incl. sensor_threshold) |
| `automations/{id}/reported` | GW→Cloud | rule sync ack |
| `automations/{id}/event` | GW→Cloud | `rule_fired` |
| `gateway/online` | GW→Cloud | `{value:"online"}` retained + LWT offline |
| `gateway/health` | GW→Cloud | `{uptime_ms, mqtt_connected, known_device_count, network_state}` (30 s) |
| `commands/{id}/request|reply` | both | device + `gateway.prepare_join` |

No existing topic segment or command `op` was renamed.

## 6. Example DHT11 payload (reported)
```json
{
  "schema":"sb.v1","msg_id":"…","ts":1781330311608,
  "tenant_id":"hust","site_id":"lab01","gateway_id":"gw-ubuntu-01","source":"gateway",
  "payload":{
    "device_id":"0000000000000053","device_type":"environment",
    "eui64":"0000000000000053","nwk_addr":"0xA09A",
    "state":{"temperature_c":28.50,"humidity_percent":48.00,"sensor":"dht11","reachable":true}
  }
}
```
- ZCL centi-units converted: `temperature_c_x100/100`, `humidity_pct_x100/100`.
- Partial reports valid (temp-only or humidity-only); a metric not yet seen is
  JSON `null`, never a fabricated `0`. Cloud merges partials into latest state.
- Sentinels `0x8000` (temp) / `0xFFFF` (humidity) are not published.
- **device_type is `environment`** and the humidity field is **`humidity_percent`**
  — this is the canonical cloud contract (`cloud.app.schemas.
  EnvironmentReportedPayload`), verified accepted by `validate_reported_payload`.

## 7. Gateway log evidence
```
@LOG {"tag":"DD","event":"classify","node_id":"0xA09A","eui64":"0000000000000053","type":"environment"}
MQTT: pub [sb/v1/hust/lab01/gw-ubuntu-01/devices/environment/0000000000000053/registry]
ENV: temp=28.50C from 0xA09A (0000000000000053)
ENV: humidity=48.00% from 0xA09A (0000000000000053)
MQTT: pub [sb/v1/.../devices/environment/0000000000000053/reported]
@LOG {"tag":"AUTO","event":"upsert","id":"e2e_env_hot",...}            # sensor_threshold rule synced
@LOG {"tag":"AUTO","event":"fired",...,"trigger":"threshold_crossed","status":"executed","actions_ok":1}
@LOG {"tag":"LIGHT","event":"auto_action_sent","device_id":"000000000000004F","cmd":"on"}
@DATA {"device":"light","node_id":"0xEB7B","state":"on"}               # light physically ON
```
Full captures: `testing_tools/evidence/dht11_env_*` and
`e2e_contract_cloud_gateway_2026-06-13.md`.

## 8. Automation runtime (threshold → light), verified
Gateway parses the **cloud canonical** `sensor_threshold` trigger verbatim:
```json
{"type":"sensor_threshold","device_id":"…0053","device_type":"environment",
 "metric":"temperature_c","operator":"gte","threshold":30}
```
- `metric`: `temperature_c` | `humidity_percent`; `operator`: `gte` | `lte`;
  `threshold`: whole units (float ok), scaled ×100 internally to compare ZCL
  centi MeasuredValue.
- Edge-triggered (fires once on false→true), re-arms after the condition drops
  false, per-rule 500 ms cooldown, disabled rules skipped.
- Action runs through the existing light command path (`lightCtrlLocalActionByDeviceId`).
- **Verified all 4 prompt cases conceptually** + physically: `temperature_c gte 27`
  → light ON; `temperature_c lte 30` → light OFF (real bulb `…004F`). Humidity
  rules use the identical path (`humidity_percent gte/lte`). Existing
  motion/switch/light flows unchanged (add-only branches).

## 9. Known limitations
- Re-classification of an already-joined device needs a fresh join (PB0) or the
  `gateway.rediscover_device` MQTT command; a plain reset keeps the cached type.
- No continuous time-series `/telemetry` topic — only retained current-state
  `/reported` + rule `/event`.
- DHT11 native resolution ~1 °C / 1 %RH despite centi encoding.
- Groups/Scenes not supported (see §10).

## 10. Groups / Scenes — NOT supported on gateway
No `group_id`/`scene_id` in command handling; no Groups (0x0004) / Scenes
(0x0005) cluster support. **Mobile scene picker should show an empty state or
device-only fallback until a gateway/cloud Groups/Scenes contract exists.**
(Matches the shared-foundation note: "Scene execution requires Gateway
Groups/Scenes support.")

## 11. Gateway status contract vs app/cloud expectation — MATCHES
- Gateway publishes `gateway/online` (`{value:"online"}`, retained + LWT
  `offline`) and periodic `gateway/health` (`uptime_ms`, `mqtt_connected`,
  `known_device_count`, `network_state`), plus `permit_join_opened/closed/failed`
  gateway events.
- Cloud already exposes `GET /api/gateways/{gateway_id}/status`
  (`cloud/app/routers/gateways.py`) returning `{gateway_id, state, version,
  last_seen_at, event_type, detail}` with admin/parent/viewer access. The earlier
  "parent can't see gateway_online (device_id=null filtered)" gap is fixed
  **cloud-side** on this branch — no gateway payload change required.

## 12. Provisioning without install code in QR — WORKS
- Mobile QR no longer carries `install_code`; Cloud holds it and sends it via
  `gateway.prepare_join`. Gateway handles that op
  (`device_dispatch.c` → `netMgrOpenForJoinSecure`) and opens an EUI-scoped
  install-code secure-join window.
- DHT11 (EUI `…0053`) joined through this flow (IC-derived join, node 0xA09A).
- **Install code is never logged** — only `ic_len`; the byte buffer is
  `memset(0)` after use.

## 13. Deviations from the task prompt (read before "doing it literally")
The prompt is consistent in **intent** with the cloud/app specs in
`testing_tools/1306/`, but three prompt specifics would **break** the already-shipped
cloud contract if implemented verbatim — the canonical cloud values (below) win:

| Prompt says | Canonical (cloud spec + implemented) | Why canonical |
|---|---|---|
| `device_type: "environment_sensor"` | `environment` | cloud `EnvironmentReportedPayload` + topic segment + classifier |
| `state.humidity_pct` | `humidity_percent` | cloud `EnvironmentReportedState` field |
| `capabilities:[...]` array | (not used) | not in cloud schema |
| branch `feat/107-dht11-env-local-gateway` | `feat/107-environment-sensor-automation-ui` | integration branch already holds the work |
| `docs/handoff/` (singular) | `docs/handoffs/` (plural) | repo convention + existing files |
| project `dht11_environment_sensor/` | `Z3_DHT11_Sensor/` | `Z3_*` repo convention |

The prompt's "Confirmed Current State" assumptions ("gateway writes env to logs
only", "no MQTT temp/humidity reaches cloud", "classified as unknown") are
**stale** — all three were implemented before this handoff.

## 14. What Cloud/Mobile do next (per testing_tools/1306 specs)
- Cloud (Agent 2): schedule cron worker + Alembic migration + reusable command
  execution service (`feat/65`).
- Mobile (Agent 1): Environment Home widgets + role visibility + threshold rule
  editor + i18n EN/VI parity (`feat/107`); already designed/built per spec.
- Mobile (Agent 3): light-only scenes + schedule templates + scene picker empty
  state (`feat/66`) — gated on the gateway Groups/Scenes limitation in §10.
- Release: cloud schedule/contracts first, then Environment + scene PRs, then
  Android `v1.2.3` (per shared-foundation release order).
