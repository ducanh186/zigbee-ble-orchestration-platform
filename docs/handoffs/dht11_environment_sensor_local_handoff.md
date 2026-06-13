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

None — by design. The gateway decoder is log-only (`ENV:` console lines and
`@LOG {"tag":"ENV",…}` entries in `/tmp/z3gw.log`). No `sb/v1/...` topic
carries temperature/humidity yet, and no MQTT contract was changed.

## 11. Known limitations

1. **Gateway classification gap**: `device_discovery.c` classifies by cluster
   (0x0406→motion, 0x0006→switch/light). 0x0402/0x0405 are unknown to it, so
   the device registers as `unknown` and `appMqttPublishDeviceRegistry` will
   announce it with that type. The QR payload says `device_type:"environment"`
   but gateway/cloud don't know that type yet.
2. **No MQTT telemetry**: temp/humidity never leaves the gateway host (log
   only).
3. **ZAP source-of-truth drift**: `autogen/zap-config.h` was hand-edited
   (clusters swapped); `config/zcl/zcl_config.zap` still describes the
   occupancy endpoint. Regenerating from the .zap (Studio/slc) would silently
   revert the clusters — update the .zap first if regeneration is ever needed.
   Header comment in `zap-config.h` flags this.
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
