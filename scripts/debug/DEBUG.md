# TEMP DEBUG — Two-bug investigation

**Status: short-term debug instrumentation only. All edits are reversible.**

Scope:

- BUG 1 — opening the gateway terminal on Ubuntu stops cloud control
- BUG 2 — toggling the switch too fast makes the light snap back

Official MQTT contract, topics, and architecture are untouched.

---

## 1. What was added

### Gated debug logging (env var `SB_DEBUG_VERBOSE=1`)

Default behavior is unchanged. With the flag set, the gateway emits extra
`@DBG ...` lines that cover every question below.

| File | Added |
|---|---|
| `gateway/Z3Gateway/Z3GatewayHost/app/app_mqtt.c` | TTY-on-stdio probe, CONNACK rc + text, **SUBACK** callback with granted QoS, rx payload preview, disconnect strerror, per-tick queue-depth heartbeat, silenced libmosquitto log spam by default |
| `gateway/Z3Gateway/Z3GatewayHost/app/rule_engine.c` | Entry tick, cooldown-hit elapsed vs threshold, dispatch pre/post tick and duration |
| `gateway/Z3Gateway/Z3GatewayHost/app/light_ctrl.c` | `@DBG LIGHT local_toggle_sent` with tick, exposes `gLightLastLocalToggleMs` |
| `gateway/Z3Gateway/Z3GatewayHost/app/telemetry_rx.c` | Snap-back elapsed-since-local-toggle on every On/Off report, rapid-duplicate ZCL command detector (`@DBG SWITCH_FAST`) |

Every TEMP change is bracketed with:

```
/* TEMP DEBUG - REMOVE AFTER BUGFIX ... */
...
/* TEMP DEBUG end */
```

so `grep -n 'TEMP DEBUG' gateway/Z3Gateway/Z3GatewayHost/app/*.c` shows them all.

### Scripts (this directory)

- `mqtt-trace.sh` — read-only subscribe to every gateway-side topic using `monitor` creds.
- `mqtt-cmd.sh` — publish a cloud-format command directly to MQTT, bypassing the FastAPI layer. Hardcoded to `device_id=000000000000004F`, endpoint 1.

---

## 2. Build and run

Build path has not changed; it still goes through `v5_workspace/Z3GatewayHost2`
(see `feedback_z3gateway_build.md` memory). After copying the updated sources
over and producing the binary:

```bash
# 1. start the tracer (terminal A)
./scripts/debug/mqtt-trace.sh

# 2. start the gateway with verbose debug ON (terminal B)
cd gateway/Z3Gateway/Z3GatewayHost/build/debug
nohup env SB_DEBUG_VERBOSE=1 \
          SB_MQTT_HOST=localhost SB_MQTT_PORT=1883 \
          SB_MQTT_USERNAME=gateway SB_MQTT_PASSWORD=gateway123 \
     ./Z3Gateway -p /dev/ttyACM0 -b 115200 > /tmp/z3gw.log 2>&1 &

# 3. watch the gateway log (terminal C)
tail -f /tmp/z3gw.log | grep -E '@DBG|@DATA|@LOG|MQTT:|RULE:|LIGHT:|SWITCH'
```

To run WITHOUT the extra debug (baseline, original behavior), omit
`SB_DEBUG_VERBOSE`.

Quick non-gateway checks:

```bash
# Is the gateway actually subscribed? Ask mosquitto.
podman exec sb-mosquitto mosquitto_sub -u monitor -P monitor123 \
  -t '$SYS/broker/subscriptions/count' -C 1 -W 2

# Which fds does the running gateway hold? (BUG 1 hint)
ls -la /proc/$(pgrep -f 'Z3Gateway -p')/fd/{0,1,2}

# Is the gateway publishing online?
podman exec sb-mosquitto mosquitto_sub -u monitor -P monitor123 \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/gateway/online' -C 1 -W 3
```

---

## 3. BUG 1 — reproduction and what to look for

**Repro:**

1. Start gateway the normal background way:
   ```bash
   cd gateway/Z3Gateway/Z3GatewayHost/build/debug
   nohup env SB_DEBUG_VERBOSE=1 \
             SB_MQTT_HOST=localhost ... \
        ./Z3Gateway -p /dev/ttyACM0 -b 115200 > /tmp/z3gw.log 2>&1 &
   ```
   Send `./scripts/debug/mqtt-cmd.sh on` — verify light changes.
2. Now "open the gateway terminal" the way you normally do that reproduces the
   bug. (Usually: kill the backgrounded process and re-run `./Z3Gateway ...`
   in the foreground, stdin/stdout attached to the terminal.)
3. Send `./scripts/debug/mqtt-cmd.sh on` again. This is where the bug shows.

**Key lines to compare between the two runs:**

```
@DBG IO stdin_tty=? stdout_tty=? stderr_tty=?
@DBG MQTT onConnect rc=0 text="Connection Accepted."
@DBG MQTT SUBACK mid=1 idx=0 granted_qos=1
MQTT: subscribed to sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request
MQTT: rx [sb/v1/.../commands/<id>/request] (N bytes)
@DBG TICK mqtt_q_depth=0 tick_ms=...
```

Diagnosis map:

| Symptom | Likely cause |
|---|---|
| `stdin_tty=1` in the broken run, `=0` in the working run | Confirms "terminal-attached runtime" is the variable |
| No `@DBG MQTT onConnect` after opening terminal | Gateway didn't reach the broker — check serial/NCP grab, two instances fighting `/dev/ttyACM0` |
| `onConnect rc=0` but no `SUBACK` | Subscribe lost somewhere; was the mosquitto thread stalled? |
| `SUBACK granted_qos=128` | Broker denied the subscribe (ACL). Check `mqtt/config/acl.conf`. |
| `SUBACK granted_qos=1` received but `MQTT: rx ...` never prints | Broker-side delivery problem or ACL on publisher side |
| `@DBG TICK` stops printing | Main loop stalled — stdout write is blocking (TTY + slow terminal emulator) |
| `@DBG TICK` keeps printing but nothing arrives | Clear evidence: subscribe/broker path, not the main loop |
| Huge `MQTT-lib:` spam only when terminal is open | Strong hint: libmosquitto log callback writing synchronously to TTY stalls the mosquitto thread. The TEMP DEBUG gate turned that spam OFF by default — if the bug disappears when `SB_DEBUG_VERBOSE` is unset, this is the cause. |

---

## 4. BUG 2 — reproduction and what to look for

**Repro:**

1. Put the light into a known state (e.g., OFF).
2. Press the Z3Switch fast enough that the bug shows (< 3-4 s between
   presses).

**Key lines:**

```
@DBG PRE_CMD cluster=0x0006 cmd=0x02 src=0x???? dir=0          # each switch frame
@DBG SWITCH_FAST src=0x???? cmd=0x?? seq=N elapsed_ms=<200 same_seq=0|1
@DBG RULE entry switch=<eui64> tick_ms=...
@DBG RULE cooldown_hit switch=<eui64> elapsed_ms=... threshold_ms=500
RULE: switch ... -> toggle light ...
@DBG LIGHT local_toggle_sent node=0x???? ep=1 tick_ms=T0
@DBG ONOFF_REPORT node=0x???? state=on  tick_ms=T1 since_local_toggle_ms=(T1-T0)
@DBG ONOFF_REPORT node=0x???? state=off tick_ms=T2 since_local_toggle_ms=(T2-T0)
```

Diagnosis map:

| Pattern | Interpretation |
|---|---|
| Two `@DBG SWITCH_FAST` in < 200 ms with `same_seq=1` | Zigbee APS-level duplicate; ember stack should have filtered. Investigate stack dup-check. |
| Two `@DBG SWITCH_FAST` with `same_seq=0` and different `cmd` | The switch itself is emitting two distinct presses per physical click. Root cause is on Z3Switch, not the gateway. |
| One `PRE_CMD`, one `LIGHT local_toggle_sent`, **two** `ONOFF_REPORT` where the second flips back | The snap-back is not caused by the gateway sending a second toggle — it is the light reverting, OR the switch is directly bound to the light in parallel and is sending a second command straight to the bulb (bypassing the gateway). |
| `PRE_CMD` appears but no `RULE entry` | Switch filter at telemetry_rx rejected the frame (direction/command mismatch). |
| `RULE entry` but `RULE cooldown_hit` | The 500 ms rule cooldown fired; the 2nd press was ignored by the gateway. If the light still flipped twice, the switch is talking to the light directly. |
| `since_local_toggle_ms` of the *second* report is ~50-300 ms and the state flipped back | Classic duplicate ZCL: either stack-level or direct switch->light binding. |
| `since_local_toggle_ms` > 1000 ms on a revert | Revert is not caused by this toggle — look at cloud `desired` / retained messages. |

A way to prove "direct switch->light binding" without changing the light
firmware: run `mqtt-trace.sh` while toggling fast. You should see TWO
`reported` events but only ONE `event` (switch toggle) — or vice versa.
The counts tell you whose command actually reached the bulb.

---

## 5. Known safe mitigations (DO NOT APPLY YET)

Only consider these once logs actually justify them:

- If `@DBG SWITCH_FAST same_seq=1` keeps appearing: widen the ember
  APS duplicate-detection window or deduplicate at telemetry_rx on
  `(source, seqNum)` with a short window.
- If `same_seq=0` back-to-back presses reliably snap back: add a tiny
  debug-only hold-off in `lightCtrlLocalToggle` that rejects a second
  toggle within ~600 ms. Clearly mark TEMP DEBUG.

---

## 6. Reverting all TEMP DEBUG changes

One grep finds every inserted block:

```bash
grep -rn 'TEMP DEBUG' gateway/Z3Gateway/Z3GatewayHost/app/
```

Steps:

1. Remove or restore every `/* TEMP DEBUG - REMOVE AFTER BUGFIX ... */`
   block in the four files listed in section 1.
2. Remove the `<unistd.h>` and `<stdlib.h>` TEMP-DEBUG include comments
   (note: `stdlib.h` may already be pulled in transitively — safe to
   leave, but the inline-marked includes are TEMP DEBUG).
3. Delete `scripts/debug/` entirely:
   ```bash
   rm -rf scripts/debug/
   ```
4. Rebuild via the usual `v5_workspace/Z3GatewayHost2` flow.

No permanent code paths were added. No MQTT topic, auth, or identity
changed. No new dependencies.
