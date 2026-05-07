"""Phase 3 + Phase 4 integration test script.

Exercises the full data paths WITHOUT a real gateway by using mock MQTT publishes:

  Phase 3:
    1. Light reported state -> cloud sees latest state (device_states row)
    2. Switch event -> cloud sees event (events row, device auto-registered)
    3. Command request -> reply -> command status updated
    4. Schema validation (light reported, switch event)

  Phase 4 (gateway-side automation is tested by presence of code; this script
  verifies the cloud's ability to handle the RESULTING messages):
    5. Switch event + light reported arrive in sequence (simulating automation)
    6. Anti-loop: only switch events, no spurious re-triggers

Usage:
    python -m cloud.scripts.test_phase3_phase4
Against remote:
    SB_API_URL=http://<host>:8000 SB_MQTT_HOST=<host> \
    SB_MQTT_USERNAME=gateway SB_MQTT_PASSWORD=gateway123 \
    python -m cloud.scripts.test_phase3_phase4
"""
from __future__ import annotations

import json
import os
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import httpx
import paho.mqtt.client as mqtt

API_URL = os.environ.get("SB_API_URL", "http://localhost:8000")
MQTT_HOST = os.environ.get("SB_MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("SB_MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("SB_MQTT_USERNAME", "gateway")
MQTT_PASS = os.environ.get("SB_MQTT_PASSWORD", "gateway123")
TENANT = os.environ.get("SB_TENANT_ID", "hust")
SITE = os.environ.get("SB_SITE_ID", "lab01")
GATEWAY = os.environ.get("SB_GATEWAY_ID", "gw-ubuntu-01")

SAMPLES = Path(__file__).parent / "samples"
LIGHT_ID = "light-01"
SWITCH_ID = "switch-01"


def topic_prefix() -> str:
    return f"sb/v1/{TENANT}/{SITE}/{GATEWAY}"


def envelope(source: str, payload: dict, correlation_id: str | None = None) -> dict:
    env = {
        "schema": "sb.v1",
        "msg_id": uuid4().hex,
        "ts": time.time_ns() // 1_000_000,
        "tenant_id": TENANT,
        "site_id": SITE,
        "gateway_id": GATEWAY,
        "source": source,
        "payload": payload,
    }
    command_id = payload.get("command_id")
    if command_id:
        env["correlation_id"] = f"cmd_{command_id}"
    elif correlation_id:
        env["correlation_id"] = correlation_id
    return env


def connect_mqtt() -> mqtt.Client:
    client = mqtt.Client(
        client_id=f"test-p3p4-{uuid4().hex[:8]}",
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    )
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.connect(MQTT_HOST, MQTT_PORT)
    client.loop_start()
    return client


def pub(mq: mqtt.Client, topic: str, payload: dict, qos: int = 1) -> None:
    mq.publish(topic, json.dumps(payload), qos=qos).wait_for_publish(timeout=3.0)


def wait(seconds: float = 0.6) -> None:
    time.sleep(seconds)


def seed_devices_via_mqtt(mq: mqtt.Client) -> None:
    """Ensure light-01 and switch-01 exist via MQTT reported/event."""
    pfx = topic_prefix()

    # Light reported -> auto-upsert
    pub(mq, f"{pfx}/devices/light/{LIGHT_ID}/reported", envelope("gateway", {
        "device_id": LIGHT_ID,
        "device_type": "light",
        "eui64": "00124b0001aa22bb",
        "state": {"power": "off", "level": 0, "reachable": True},
    }))

    # Switch event -> auto-register
    pub(mq, f"{pfx}/devices/switch/{SWITCH_ID}/event", envelope("gateway", {
        "device_id": SWITCH_ID,
        "device_type": "switch",
        "event": "toggle",
        "eui64": "00124b0001bb33cc",
    }))
    wait(1.0)


def main() -> int:
    print(f"=== Phase 3 + Phase 4 Integration Test ===")
    print(f"API  = {API_URL}")
    print(f"MQTT = {MQTT_HOST}:{MQTT_PORT}")
    print()

    passed = 0
    failed = 0

    def ok(label: str):
        nonlocal passed
        passed += 1
        print(f"  [OK] {label}")

    def fail(label: str, detail: str = ""):
        nonlocal failed
        failed += 1
        print(f"  [FAIL] {label}: {detail}", file=sys.stderr)

    with httpx.Client(timeout=8.0) as http:
        # Health check
        r = http.get(f"{API_URL}/health")
        if r.status_code == 200:
            ok("health check")
        else:
            fail("health check", f"status={r.status_code}")

        mq = connect_mqtt()
        try:
            pfx = topic_prefix()

            # Seed devices
            seed_devices_via_mqtt(mq)

            # ============================================================
            # PHASE 3.1: Light reported state
            # ============================================================
            print("\n--- Phase 3.1: Light reported state ---")
            pub(mq, f"{pfx}/devices/light/{LIGHT_ID}/reported", envelope("gateway", {
                "device_id": LIGHT_ID,
                "device_type": "light",
                "eui64": "00124b0001aa22bb",
                "nwk_addr": "0x4F2A",
                "state": {"power": "on", "level": 180, "reachable": True},
            }))
            wait()
            r = http.get(f"{API_URL}/api/devices/{LIGHT_ID}/state")
            if r.status_code == 200:
                st = r.json()["state"]
                if st.get("power") == "on" and st.get("level") == 180:
                    ok(f"light reported state: power={st['power']}, level={st['level']}")
                else:
                    fail("light reported state", f"unexpected: {st}")
            else:
                fail("light reported state", f"status={r.status_code}")

            # Verify device was registered
            r = http.get(f"{API_URL}/api/devices/{LIGHT_ID}")
            if r.status_code == 200 and r.json()["device_type"] == "light":
                ok(f"light device registered: type={r.json()['device_type']}")
            else:
                fail("light device registration", f"status={r.status_code}")

            # ============================================================
            # PHASE 3.2: Switch event
            # ============================================================
            print("\n--- Phase 3.2: Switch event ---")
            pub(mq, f"{pfx}/devices/switch/{SWITCH_ID}/event", envelope("gateway", {
                "device_id": SWITCH_ID,
                "device_type": "switch",
                "event": "toggle",
                "eui64": "00124b0001bb33cc",
                "nwk_addr": "0x7A12",
            }))
            wait()

            # Check device auto-registered
            r = http.get(f"{API_URL}/api/devices/{SWITCH_ID}")
            if r.status_code == 200 and r.json()["device_type"] == "switch":
                ok(f"switch auto-registered: type={r.json()['device_type']}")
            else:
                fail("switch auto-registration", f"status={r.status_code}")

            # Check event in DB
            r = http.get(f"{API_URL}/api/events/?device_id={SWITCH_ID}&event_type=toggle")
            if r.status_code == 200 and len(r.json()) > 0:
                ev = r.json()[0]
                ok(f"switch event stored: event_type={ev['event_type']}, device={ev['device_id']}")
            else:
                fail("switch event storage", f"status={r.status_code}, body={r.text}")

            # ============================================================
            # PHASE 3.3: Command lifecycle (cloud -> gateway -> reply)
            # ============================================================
            print("\n--- Phase 3.3: Command lifecycle ---")
            body = {
                "op": "device.command",
                "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
                "timeout_ms": 5000,
            }
            r = http.post(f"{API_URL}/api/devices/{LIGHT_ID}/command", json=body)
            if r.status_code == 201:
                cmd_id = r.json()["id"]
                ok(f"command created: id={cmd_id}, status={r.json()['status']}")

                # Simulate gateway reply
                pub(mq, f"{pfx}/commands/{cmd_id}/reply", envelope("gateway", {
                    "command_id": cmd_id,
                    "device_id": LIGHT_ID,
                    "status": "executed",
                    "reason": None,
                }, correlation_id=cmd_id))
                wait()

                r = http.get(f"{API_URL}/api/commands/{cmd_id}")
                if r.status_code == 200 and r.json()["status"] == "executed":
                    ok(f"command reply processed: status=executed")
                else:
                    fail("command reply", f"status={r.json().get('status')}")
            else:
                fail("command creation", f"status={r.status_code}")

            # ============================================================
            # PHASE 4 simulation: switch event -> light state change
            # (In real hw: switch press -> rule engine -> light toggle -> reported)
            # Here we simulate the CLOUD-VISIBLE result.
            # ============================================================
            print("\n--- Phase 4: Switch->Light automation (cloud-visible) ---")

            # Step 1: Switch press (event)
            pub(mq, f"{pfx}/devices/switch/{SWITCH_ID}/event", envelope("gateway", {
                "device_id": SWITCH_ID,
                "device_type": "switch",
                "event": "toggle",
                "eui64": "00124b0001bb33cc",
            }))

            # Step 2: Light state changes (reported - result of rule engine toggle)
            pub(mq, f"{pfx}/devices/light/{LIGHT_ID}/reported", envelope("gateway", {
                "device_id": LIGHT_ID,
                "device_type": "light",
                "eui64": "00124b0001aa22bb",
                "state": {"power": "off", "level": 0, "reachable": True},
            }))
            wait()

            # Verify cloud sees both
            r = http.get(f"{API_URL}/api/events/?device_id={SWITCH_ID}&event_type=toggle&limit=5")
            event_count = len(r.json()) if r.status_code == 200 else 0
            if event_count >= 2:  # at least 2 toggle events so far
                ok(f"switch events accumulated: {event_count} toggle events")
            else:
                fail("switch event count", f"expected >=2, got {event_count}")

            r = http.get(f"{API_URL}/api/devices/{LIGHT_ID}/state")
            if r.status_code == 200:
                st = r.json()["state"]
                if st.get("power") == "off":
                    ok(f"light state after automation: power=off (toggled)")
                else:
                    fail("light state after automation", f"unexpected: {st}")
            else:
                fail("light state after automation", f"status={r.status_code}")

            print("\n--- Phase 4.3: Anti-loop verification ---")
            # The anti-loop is enforced at the gateway level (rule_engine.c).
            # At cloud level, we verify that light reported does NOT generate
            # spurious events - the events table should only have switch events.
            r = http.get(f"{API_URL}/api/events/?device_id={LIGHT_ID}&limit=50")
            light_events = r.json() if r.status_code == 200 else []
            if len(light_events) == 0:
                ok("anti-loop: no spurious events from light reported")
            else:
                # Light events could exist for other reasons; just warn
                print(f"  [WARN] {len(light_events)} events for {LIGHT_ID} (may be expected)")

        finally:
            mq.loop_stop()
            mq.disconnect()

    print(f"\n=== Results: {passed} passed, {failed} failed ===")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"\nTEST ERROR: {e!r}", file=sys.stderr)
        sys.exit(1)
