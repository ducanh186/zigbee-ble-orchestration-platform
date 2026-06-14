# DHT11 Environment Sensor — Local Firmware + Gateway Handoff

Date: 2026-06-12
Author: firmware/local-gateway side (Claude Code session, reviewed by chuphu2004)
Audience: Cloud/App teammate finishing the integration

## 1. Summary

A new Zigbee 3.0 end-device firmware project `end_devices/Z3_DHT11_Sensor/` was
created by recycling `end_devices/Z3_Occupancy_Sensor/` (same board, same join
flow, same QR-provisioning display). The PIR logic was removed and replaced by:

- `app/dht11.c|h` — bit-banged DHT11 driver on **PD8** (open-drain, pull-up to
  3V3, DWT-cycle-counter microsecond timing, hard timeouts on every wait, no
  infinite loops, checksum validation).
- `app/env_sensor.c|h` — scheduler/reporter: read every 5 s, report at least
  every 60 s, earlier on ≥1.0 °C or ≥5 %RH change; up to 2 quick retries on a
  failed read.

The device declares standard ZCL server clusters **Temperature Measurement
(0x0402)** and **Relative Humidity Measurement (0x0405)** on endpoint 1
(device id 0x0302) and sends ZCL *Report Attributes* frames (MeasuredValue
0x0000, centi-units) unicast to the coordinator. The local gateway
(`gateway/Z3GatewayHost`) got a **log-only** decoder for those two clusters in
`telemetry_rx.c` — it prints `ENV: temp=…` / `ENV: humidity=…` and emits
`@LOG {"tag":"ENV","event":"report",…}` lines. **No MQTT topics or payloads
were added or changed**; that is intentionally left to the Cloud/App side.

Status: firmware and gateway build clean; firmware flashed to kit 440121812
(EUI `…0053`), joined the local gateway via install-code secure join, and
real DHT11 readings were decoded in the gateway log (§8, §14). Local pipeline
verified end-to-end.

## 2. Changed files

New (untracked):

- `end_devices/Z3_DHT11_Sensor/` — full project (copy of Z3_Occupancy_Sensor
  with: `app/pir_sensor.*` removed; `app/dht11.*`, `app/env_sensor.*` added;
  `main.c`, `app.c`, `.slcp`, `autogen/zap-config.h` edited;
  `autogen/`+`config/` taken from the **workspace** Occupancy copy, which is
  newer than the repo copy — see §11 known limitation about drift).
- `artifact/Z3_DHT11_Sensor/Z3_DHT11_Sensor.s37` + `manifest.json`.
- `docs/handoff/dht11_environment_sensor_local_handoff.md` (this file).

Modified:

- `gateway/Z3GatewayHost/app/telemetry_rx.c` — log-only 0x0402/0x0405 report
  decoder in `emberAfReportAttributesCallback`.
- `gateway/Z3GatewayHost/build/debug/Z3Gateway` — rebuilt tracked binary.

Pre-existing uncommitted changes NOT from this task (do not mix into review):
`artifact/Z3Switch/Z3Switch.s37`, `end_devices/{Z3Light,Z3Switch,Z3_Occupancy_Sensor}/app/provisioning_qr.c`.

Off-repo build trees created (machine-local, not in git):

- `~/ss_v5/v5_workspace/Z3_DHT11_Sensor/` (source sync target)
- `~/SimplicityStudio/v5_workspace/Z3_DHT11_Sensor/GNU ARM v12.2.1 - Default/`
  (Studio-style makefile build dir, cloned from the Occupancy one with paths
  rewritten; `app/subdir.mk` + `makefile` link list updated for the two new
  source files).

## 3. Hardware wiring

```text
DHT11 VCC  -> kit 3V3 (EXP header pin 20 / any 3V3)
DHT11 GND  -> kit GND (EXP header pin 1)
DHT11 DATA -> PD8 (EXP header pin 3 wiring used by the old PIR OUT)
DATA pull-up -> 4.7kΩ–10kΩ to 3V3 (skip if the module has one on-board;
                the firmware also enables the MCU-internal pull-up)
```

3.3 V logic only. The MCU never drives the line high (open-drain wired-AND
mode for the start signal, input otherwise), and 5 V supply/logic must NOT be
used — EFR32 GPIO is not 5 V tolerant.

## 4. Selected GPIO pin

**PD8** (`gpioPortD`, pin 8) — defined in `end_devices/Z3_DHT11_Sensor/app/dht11.h`.
Chosen because it is the same EXP-header pin the Occupancy firmware used for
the PIR OUT on this exact board config (BRD4162A + BRD4001A), so it is proven
free of conflicts with VCOM UART (PA0/PA1), LEDs (PF4/PF5), BTN0 (PF6), the
memory-LCD/QR display pins, and PTI.

## 5. Build command

```bash
# one-time per source change: sync repo -> workspace
rsync -a end_devices/Z3_DHT11_Sensor/app end_devices/Z3_DHT11_Sensor/autogen \
        end_devices/Z3_DHT11_Sensor/config end_devices/Z3_DHT11_Sensor/main.c \
        end_devices/Z3_DHT11_Sensor/app.c ~/ss_v5/v5_workspace/Z3_DHT11_Sensor/

cd ~/SimplicityStudio/v5_workspace/Z3_DHT11_Sensor/'GNU ARM v12.2.1 - Default'
PATH="/home/phu/SimplicityStudio_v5/developer/toolchains/gnu_arm/12.2.rel1_2023.7/bin:$PATH" \
  make all -j$(nproc)
# output: Z3_DHT11_Sensor.s37 (copy to artifact/Z3_DHT11_Sensor/)
```

The 12.2.1 toolchain on PATH is mandatory — the system arm-none-eabi-gcc
10.3.1 ld rejects `--no-warn-rwx-segments`.

## 6. Flash command

```bash
commander flash artifact/Z3_DHT11_Sensor/Z3_DHT11_Sensor.s37 --serialno <kit-jlink>
# e.g. the Occupancy kit: --serialno 440121812
```

No `--masserase`: a plain app flash preserves the MFG custom-EUI +
install-code tokens and NVM3, so a previously-commissioned kit keeps its
identity (and rejoins on its own if it was already joined).

## 7. Gateway run command / log location

```bash
scripts/start-gateway.sh        # binary gateway/Z3GatewayHost/build/debug/Z3Gateway
tail -f /tmp/z3gw.log
```

Join staging (install-code secure join, codes per `testing_tools/BOARD_MAP.md`;
example for the Occupancy kit EUI `…0053`):

```bash
echo "pjoin-secure 120 0000000000000053 00000000000000535353535353535353CE2F" >> /tmp/z3gw_input
# then reset the kit within 120 s
```

## 8. Gateway log excerpts

Gateway rebuilt with the ENV decoder and verified up (2026-06-12):

```text
MQTT: subscribed to sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request
ezsp ver 0x0D stack type 0x02 stack ver. [7.5.1 GA build 0]
```

Live capture, kit 440121812 / EUI `0000000000000053` (full logs:
`testing_tools/evidence/dht11_env_sensor_2026-06-12.md`):

Join (staged install-code secure join; note the non-staged kit `0052` was
denied in the same window — the staging is EUI-specific):

```text
pjoin-secure: staged eui=0000000000000053 ttl=120s (ic_len=18)
@LOG {"tag":"NET","event":"tc_join","node_id":"0xA09A","eui64":"0000000000000053","status":1,"decision":0,"key_type":"IC_DERIVED","uptime":34u}
Device Announce: 0xA09A
@LOG {"tag":"NET","event":"tc_join","node_id":"0xC533","eui64":"0000000000000052","status":1,"decision":2,...}   <- denied
```

ZDO discovery / endpoint info:

```text
@LOG {"tag":"DD","event":"ep_clusters","node_id":"0xA09A","ep":1,"in":3,"out":0,"profile":"0x0104","device":"0x0302"}
@LOG {"tag":"DD","event":"classify","node_id":"0xA09A","eui64":"0000000000000053","type":"unknown",...}
@LOG {"tag":"REG","event":"paired","eui64":"0000000000000053","node_id":"0xA09A","ep":1,"type":"unknown"}
```

Decoded temperature/humidity reports (first report on join, second ~60 s
later on the periodic timer):

```text
@DBG REPORT clusterId=0x0402 bufLen=5 sender=0xA09A
ENV: temp=28.50C from 0xA09A (0000000000000053)
@LOG {"tag":"ENV","event":"report","device_id":"0000000000000053","node_id":"0xA09A","temperature_c_x100":2850}
ENV: humidity=48.00% from 0xA09A (0000000000000053)
@LOG {"tag":"ENV","event":"report","device_id":"0000000000000053","node_id":"0xA09A","humidity_pct_x100":4800}
ENV: temp=28.30C from 0xA09A (0000000000000053)
ENV: humidity=46.00% from 0xA09A (0000000000000053)
```

Device-side VCOM log (`/dev/ttyACM1`):

```text
DHT11 init: selected GPIO = PD8 (EXP3), read=5000ms report<=60000ms
DHT11 read OK: temp=28.5C humidity=48.0%
NWK Steering joining 0xCD53 on channel 25
EMBER_NETWORK_UP 0xA09A
NET: joined
Zigbee report sent: temp=28.5C humidity=48.0% (tx 0x00/0x00)
Zigbee report sent: temp=28.3C humidity=46.0% (tx 0x00/0x00)
```

Disconnected-sensor behavior was also exercised (before the DHT11 was wired):
`DHT11 timeout at stage=release bit=0` / `stage=resp_low` + `ENV: retry 1/2 in
1000ms` — bounded timeouts, no hang, Zigbee stack kept running and joined
while the sensor was absent.

## 9. Zigbee endpoint / cluster information

| Item | Value |
|---|---|
| Endpoint | 1 |
| Profile | 0x0104 (HA) |
| Device ID | 0x0302 (Temperature Sensor) |
| Server clusters | 0x0000 Basic, 0x0402 Temperature Measurement, 0x0405 Relative Humidity Measurement |
| 0x0402 attrs | 0x0000 MeasuredValue (int16s, 0.01 °C, invalid 0x8000), 0x0001 Min (0), 0x0002 Max (5000), 0xFFFD |
| 0x0405 attrs | 0x0000 MeasuredValue (uint16, 0.01 %RH, invalid 0xFFFF), 0x0001 Min (2000), 0x0002 Max (9000), 0xFFFD |
| Reporting | device-initiated ZCL Report Attributes (0x0A), unicast to coordinator ep1; the `zigbee_reporting` plugin's Configure-Reporting path is NOT relied on (same manual-report fallback the Occupancy firmware uses) |
| Scaling | 28 °C → 2800; 65 %RH → 6500 |
| Role | Router (always-on, same as Occupancy) |

## 10. MQTT / Gateway payload observed

- **Registry:** `devices/environment/0000000000000053/registry` (retained) once
  classified — see §10A.
- **Automation:** `automations/{id}/reported` (sync ack) and
  `automations/{id}/event` (`rule_fired` with the `threshold_crossed` trigger)
  on each fire — see §10A.
- **Reported state:** `devices/environment/<eui>/reported` (retained, QoS 1) on
  every measured-value report, e.g.
  `state:{"temperature_c":27.80,"humidity_percent":38.00,"reachable":true}`.
  A metric not yet observed this session is emitted as `null` (temp and
  humidity arrive in separate cluster reports). Verified live 2026-06-13.

## 10A. Environment → Light automation (DHT11 drives the light)

**Light behavior is now an intended feature, not a side effect.** The DHT11
firmware itself still emits ZERO On/Off and creates no binding — it only
reports 0x0402/0x0405. The bulb is driven entirely by a **gateway automation
rule**, edge-triggered on temperature/humidity thresholds, exactly like the
occupancy→light path. Users create/edit these rules from app/dashboard.

**Rule shape** (MQTT `automations/{id}/desired`, retained — same envelope as
occupancy, new `environment` trigger):

**The canonical trigger shape is the Cloud contract** (`cloud.app.schemas.
SensorThresholdTrigger`, see `docs/handoffs/gateway-environment-sensor-contract.md`).
The gateway parser was aligned to it on `feat/107`:

```json
{
  "op": "upsert", "version": 1, "name": "Bat den khi nong", "enabled": true,
  "trigger": {
    "type": "sensor_threshold",
    "device_id": "0000000000000053",
    "device_type": "environment",
    "metric": "temperature_c",    // temperature_c | humidity_percent
    "operator": "gte",            // gte (>=) | lte (<=)
    "threshold": 30               // whole units: 30 = 30 C, 65 = 65 %RH (float ok, e.g. 28.5)
  },
  "actions": [
    { "device_type": "light", "device_id": "000000000000004F", "command": "on" }
  ]
}
```

**Semantics:** fires once on the transition into "condition met" (edge-trigger),
not every report, plus the existing 500 ms per-rule cooldown. Use two rules with
offset thresholds (e.g. on ≥28 °C, off ≤27 °C) for hysteresis. The gateway
scales the whole-unit `threshold` ×100 internally to compare against the ZCL
centi-unit MeasuredValue (`30` → `3000`; `28.5` → `2850`).

> Note: an earlier local-only draft of this firmware used
> `event:"threshold_crossed"` / `comparator` / centi-unit `threshold`. That was
> superseded by the Cloud contract above when integrating on `feat/107`; the
> gateway now parses the Cloud shape.

**Why the light turned on during earlier testing (the original Phase-6
question):** it was NOT the DHT11 device. On a shared demo network, light
`…004F` (node 0xEB7B) + pre-existing switch/cloud automation rules drive the
On/Off cluster. The DHT11 sensor (node 0xA09A) is architecturally incapable of
sending On/Off. With this feature, the *intended* way for the sensor to affect
the light is the environment rule above — observable as `LIGHT auto_action_sent`
+ `AUTO fired ... "trigger":"threshold_crossed"` in the gateway log.

### Occupancy vs DHT11 comparison

| Item | Occupancy firmware | DHT11 env sensor | Status |
|---|---|---|---|
| Sensor driver | `pir_sensor.c` (digital poll 200 ms) | `dht11.c` (1-wire, DWT µs timing, hard timeouts) | replaced |
| ZCL cluster | 0x0406 Occupancy | 0x0402 Temp + 0x0405 Humidity | replaced |
| Report path | manual Report Attrs to bindings | manual Report Attrs unicast to coordinator | reused pattern |
| Net / join / buttons / QR | `net_mgr` / `buttons` / `display_qr` | identical | reused |
| Gateway classify | `motion` | `environment` (new) | added |
| Automation trigger | `occupancy_changed` | `threshold_crossed` (metric/comparator/threshold) | added |
| Light control | rule action on/off/toggle | rule action on/off | reused |
| Device emits On/Off? | no | no | unchanged (rule decides) |

### Demo checklist (verified 2026-06-13, kit 440121812 / EUI …0053, light …004F)

| # | Test | Result | Evidence |
|---|---|---|---|
| 1 | Firmware build | PASS | `Z3_DHT11_Sensor.s37` 780,996 B, zero warnings |
| 2 | Device boot + sensor read | PASS | `DHT11 init: PD8`; `DHT11 read OK: temp=…` on VCOM |
| 3 | Zigbee join | PASS | IC-derived join node 0xA09A; classify `type:"environment"` |
| 4 | Temp/humidity report at gateway | PASS | `ENV: temp=28.00C` / `ENV: humidity=45.00%` + `@LOG ENV report` |
| 5 | No unintended occupancy behavior | PASS | device sends only 0x0402/0x0405; no 0x0406, no On/Off |
| 6 | Light driven by rule (intended) | PASS | rule `gte 2750`→`AUTO fired`→`auto_action_sent on`→light `@DATA state:"on"`; rule `lte 2800`→light off |

Raw log: `testing_tools/evidence/dht11_env_automation_2026-06-13.md`.
(Physical heating wasn't possible in the autonomous run, so demo thresholds were
set around ambient ~27.8 °C to exercise both crossings with real sensor reports;
the rule logic and light actuation are genuinely end-to-end.)

## 11. Known limitations

1. ~~Gateway classification gap~~ **RESOLVED (2026-06-13):** `device_discovery.c`
   now classifies 0x0402/0x0405 → `environment`; registry publishes
   `devices/environment/<eui>/registry`. Note: re-classification of an
   already-joined device needs a fresh join (PB0 leave/rejoin) OR the
   `gateway.rediscover_device` MQTT command — a plain reset keeps the cached
   type. **Cloud must accept device_type `environment`.**
2. ~~No continuous MQTT telemetry~~ **RESOLVED (2026-06-13):** every report now
   publishes retained `devices/environment/<eui>/reported` with
   `state:{temperature_c, humidity_percent, reachable}` (centi-precision
   decimals; `null` for a metric not yet seen this session). A dedicated
   high-rate `/telemetry` history stream (vs current-state `/reported`) is
   still optional future work if the cloud wants time-series.
3. ~~ZAP source-of-truth drift~~ **MITIGATED (2026-06-13):**
   `config/zcl/zcl_config.zap` was hand-edited to match `zap-config.h`
   (device 770; Temperature 1026 + Relative Humidity 1029 clusters; occupancy
   removed). **CAVEAT:** this build flow has no ZAP/slc generator to validate
   the edited `.zap`, and the build does NOT regenerate from it (hand-maintained
   `zap-config.h` + Studio makefile). If you ever regenerate in Simplicity
   Studio, diff the result against `zap-config.h` before trusting it. Flagged in
   the `zap-config.h` header comment.
4. **DHT11 decimal bytes**: genuine DHT11 sends integer-only values (decimal
   bytes 0) — effective resolution 1 °C / 1 %RH despite centi-unit encoding.
5. **Bit-39 edge case**: if a clone module releases the bus without the final
   50 µs low, the last bit is assumed `1` and the checksum is the arbiter.
6. **~6 ms critical section** per read (every 5 s) while clocking the 40-bit
   frame; radio IRQs are deferred for that window. Acceptable for a router in
   this app; revisit if it ever hosts latency-critical traffic.
7. **Reporting plugin defaults**: zap-config carries reporting-default entries
   for both MeasuredValues (mirroring the occupancy pattern), but reports are
   actually emitted manually; gateway Configure-Reporting is not required.

## 12. Required next work (Cloud/App teammate)

1. Gateway: classify 0x0402/0x0405 `inClusterList` → device type
   `"environment"` in `device_discovery.c` (and registry/MQTT announce path).
2. Gateway: publish telemetry — extend the new `telemetry_rx.c` ENV branches
   to `appMqttPublishDeviceReported…` with a state payload (suggested shape in
   §13); document the topic in `docs/MQTT_CONTRACT.md`.
3. Cloud: accept/store the new device type + state fields; factory_devices
   registry entry for the env kit (QR `device_type:"environment"`,
   model `EFR32MG12_ENV_KIT`).
4. App/Dashboard: display temperature/humidity tile for `environment` devices.
5. Optional firmware follow-up: real Configure-Reporting support if/when the
   reporting plugin path is fixed platform-wide.

## 13. Suggested Cloud/App state fields

```json
{
  "temperature_c": 28.5,
  "humidity_percent": 65,
  "sensor": "dht11",
  "reachable": true
}
```

(Gateway-side raw values are `temperature_c_x100` / `humidity_pct_x100`
integers; divide by 100 at the edge you prefer.)

## 14. Test evidence and final status

| Step | Status | Evidence |
|---|---|---|
| New project builds | DONE | `Z3_DHT11_Sensor.s37` (780,996 B) built 2026-06-12, zero warnings in new sources |
| Occupancy not broken | DONE | `Z3_Occupancy_Sensor` re-linked clean after all changes; its sources/build untouched |
| Gateway builds + runs | DONE | `make -f Z3Gateway.Makefile debug` exit 0; `/tmp/z3gw.log` shows `ezsp ver 0x0D …` + `MQTT: subscribed` |
| Flash to kit | DONE | `commander flash … --serialno 440121812` → "Flashing completed successfully!" (no masserase; EUI/IC tokens kept) |
| Sensor reads on hardware | DONE | `DHT11 read OK: temp=28.5C humidity=48.0%` on VCOM; disconnected case = bounded `timeout at stage=…` + retries, no hang |
| Join local gateway | DONE | IC-derived secure join as node 0xA09A (EUI 0053); non-staged kit denied in same window |
| ENV reports in gateway log | DONE | `ENV: temp=28.50C` / `ENV: humidity=48.00%` + `@LOG ENV report` lines, repeated on the 60 s cadence |

Full raw excerpts: `testing_tools/evidence/dht11_env_sensor_2026-06-12.md`.

**Final status: local pipeline DHT11 → EFR32 → Zigbee → gateway log VERIFIED
end-to-end on hardware.** Remaining work is Cloud/App integration (§12).
