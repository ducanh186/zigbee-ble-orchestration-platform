"""End-to-end smoke test for the cloud API.

Exercises the light ON/OFF path without needing a real gateway:

  1. POST /api/devices/light-01/command  (body = samples/light_on.json)
  2. Fake gateway: publish `commands/{id}/reply` with status=executed
  3. Poll GET /api/commands/{id} → expect status == "executed"
  4. Fake gateway: publish `devices/light/light-01/reported` (power on)
  5. GET /api/devices/light-01/state → expect power == "on"
  6. Send OFF command with a tiny timeout, skip the reply, verify timeout.

Usage (against local dev stack):
    python -m cloud.scripts.smoke_test
Against EC2:
    SB_API_URL=http://<ec2-host>:8000 SB_MQTT_HOST=<ec2-host> \
    SB_MQTT_USERNAME=gateway SB_MQTT_PASSWORD=gateway123 \
    python -m cloud.scripts.smoke_test

Exit codes: 0 = pass, 1 = fail.
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
DEVICE_ID = "light-01"

SAMPLES = Path(__file__).parent / "samples"


def topic_prefix() -> str:
    return f"sb/v1/{TENANT}/{SITE}/{GATEWAY}"


def envelope(source: str, payload: dict, correlation_id: str | None = None) -> dict:
    env = {
        "schema": "sb.v1",
        "msg_id": uuid4().hex,
        "ts": int(datetime.now(UTC).timestamp() * 1000),
        "tenant_id": TENANT,
        "site_id": SITE,
        "gateway_id": GATEWAY,
        "source": source,
        "payload": payload,
    }
    if correlation_id:
        # Contract format: "cmd_" + command_id. Callers pass the raw command_id.
        env["correlation_id"] = (
            correlation_id
            if correlation_id.startswith("cmd_")
            else f"cmd_{correlation_id}"
        )
    return env


def connect_mqtt() -> mqtt.Client:
    client = mqtt.Client(
        client_id=f"smoke-{uuid4().hex[:8]}",
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    )
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.connect(MQTT_HOST, MQTT_PORT)
    client.loop_start()
    return client


def poll_command(client: httpx.Client, command_id: str, expect: str, timeout_s: float):
    deadline = time.time() + timeout_s
    last: dict = {}
    while time.time() < deadline:
        r = client.get(f"{API_URL}/api/commands/{command_id}")
        r.raise_for_status()
        last = r.json()
        if last.get("status") == expect:
            return last
        time.sleep(0.25)
    raise AssertionError(
        f"Command {command_id}: expected status={expect}, got {last.get('status')!r}"
    )


def seed_device_if_needed(client: httpx.Client) -> None:
    r = client.get(f"{API_URL}/api/devices/{DEVICE_ID}")
    if r.status_code == 200:
        return
    # Use MQTT "reported" to create device implicitly (auto-upsert in _handle_reported)
    # so this script doesn't depend on /api/devices POST endpoint.
    mq = connect_mqtt()
    try:
        payload = json.loads((SAMPLES / "reported_light.json").read_text("utf-8"))
        topic = f"{topic_prefix()}/devices/light/{DEVICE_ID}/reported"
        mq.publish(topic, json.dumps(payload), qos=0).wait_for_publish(timeout=2.0)
        time.sleep(0.5)
    finally:
        mq.loop_stop()
        mq.disconnect()


def main() -> int:
    print(f"API  = {API_URL}")
    print(f"MQTT = {MQTT_HOST}:{MQTT_PORT}")

    with httpx.Client(timeout=5.0) as http:
        # Health
        r = http.get(f"{API_URL}/health")
        r.raise_for_status()
        print(f"  [ok] /health → {r.json()}")

        # Ensure light-01 exists
        seed_device_if_needed(http)
        print(f"  [ok] device {DEVICE_ID} present")

        mq = connect_mqtt()
        try:
            # ---- 1) Light ON with reply -----------------------------------
            body = json.loads((SAMPLES / "light_on.json").read_text("utf-8"))
            r = http.post(f"{API_URL}/api/devices/{DEVICE_ID}/command", json=body)
            r.raise_for_status()
            cmd = r.json()
            cmd_id = cmd["id"]
            print(f"  [ok] POST command → id={cmd_id} status={cmd['status']}")
            assert cmd["status"] == "accepted"
            assert cmd["timeout_ms"] == body["timeout_ms"]

            reply = envelope(
                "gateway",
                {"status": "executed", "device_id": DEVICE_ID, "reason": None},
                correlation_id=cmd_id,
            )
            mq.publish(
                f"{topic_prefix()}/commands/{cmd_id}/reply",
                json.dumps(reply),
                qos=0,
            ).wait_for_publish(timeout=2.0)
            result = poll_command(http, cmd_id, expect="executed", timeout_s=5.0)
            print(f"  [ok] reply processed → status=executed (updated_at={result['updated_at']})")

            # ---- 2) Reported state shows up -------------------------------
            reported = envelope(
                "gateway",
                {
                    "device_id": DEVICE_ID,
                    "device_type": "light",
                    "eui64": "00124b0001aa22bb",
                    "state": {"power": "on", "reachable": True},
                },
            )
            mq.publish(
                f"{topic_prefix()}/devices/light/{DEVICE_ID}/reported",
                json.dumps(reported),
                qos=0,
            ).wait_for_publish(timeout=2.0)
            time.sleep(0.5)
            r = http.get(f"{API_URL}/api/devices/{DEVICE_ID}/state")
            r.raise_for_status()
            st = r.json()
            assert st["state"].get("power") == "on", st
            print(f"  [ok] reported state → {st['state']}")

            # ---- 3) Timeout path ----------------------------------------
            off = json.loads((SAMPLES / "light_off.json").read_text("utf-8"))
            off["timeout_ms"] = 1500
            r = http.post(f"{API_URL}/api/devices/{DEVICE_ID}/command", json=off)
            r.raise_for_status()
            off_id = r.json()["id"]
            print(f"  [..] sent OFF with timeout_ms=1500 (no reply) id={off_id}")
            result = poll_command(http, off_id, expect="timeout", timeout_s=8.0)
            assert "timeout" in (result.get("reason") or "").lower(), result
            print(f"  [ok] auto-timeout → status=timeout reason={result['reason']!r}")
        finally:
            mq.loop_stop()
            mq.disconnect()

    print("\nSMOKE TEST PASSED")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"\nSMOKE TEST FAILED: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"\nSMOKE TEST ERROR: {e!r}", file=sys.stderr)
        sys.exit(1)
