"""Smoke test for EC2 cloud -> local Zigbee light control.

This script uses the real cloud API and a real gateway. It does not fake
command replies. The gateway must already be running, connected to the EC2
MQTT broker, and have learned the target light EUI64.

Example:
    SB_API_URL=http://98.83.4.87:8000 \
    SB_MQTT_HOST=98.83.4.87 \
    SB_LIGHT_ID=0000000000000055 \
    SB_MOTION_ID=0000000000000053 \
    python -m cloud.scripts.cloud_to_zigbee_smoke
"""
from __future__ import annotations

import os
import sys
import time
from uuid import uuid4

import httpx
import paho.mqtt.client as mqtt

API_URL = os.environ.get("SB_API_URL", "http://98.83.4.87:8000").rstrip("/")
MQTT_HOST = os.environ.get("SB_MQTT_HOST", "98.83.4.87")
MQTT_PORT = int(os.environ.get("SB_MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("SB_MQTT_USERNAME", "monitor")
MQTT_PASS = os.environ.get("SB_MQTT_PASSWORD", "monitor123")
TENANT = os.environ.get("SB_TENANT_ID", "hust")
SITE = os.environ.get("SB_SITE_ID", "lab01")
GATEWAY = os.environ.get("SB_GATEWAY_ID", "gw-ubuntu-01")
LIGHT_ID = os.environ.get("SB_LIGHT_ID")
MOTION_ID = os.environ.get("SB_MOTION_ID")
COMMAND_TIMEOUT_MS = int(os.environ.get("SB_COMMAND_TIMEOUT_MS", "5000"))
COMMAND_WAIT_S = float(os.environ.get("SB_COMMAND_WAIT_S", "12"))
STATE_WAIT_S = float(os.environ.get("SB_STATE_WAIT_S", "8"))

TERMINAL_STATUSES = {"executed", "failed", "timeout"}


def topic_prefix() -> str:
    return f"sb/v1/{TENANT}/{SITE}/{GATEWAY}"


def require_light_id() -> str:
    if LIGHT_ID:
        return LIGHT_ID
    raise RuntimeError(
        "SB_LIGHT_ID is required. Use the real Light EUI64 shown in gateway "
        "logs or GET /api/devices/ after the light reports state."
    )


def check_mqtt() -> None:
    client = mqtt.Client(
        client_id=f"cloud-zigbee-smoke-{uuid4().hex[:8]}",
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    )
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.connect(MQTT_HOST, MQTT_PORT, keepalive=15)
    client.disconnect()
    print(f"  [ok] MQTT reachable: {MQTT_HOST}:{MQTT_PORT} user={MQTT_USER}")


def get_json(client: httpx.Client, path: str) -> tuple[int, dict | list]:
    response = client.get(f"{API_URL}{path}")
    if response.headers.get("content-type", "").startswith("application/json"):
        return response.status_code, response.json()
    return response.status_code, {"raw": response.text}


def ensure_device_exists(client: httpx.Client, device_id: str, label: str) -> None:
    status, body = get_json(client, f"/api/devices/{device_id}")
    if status == 200:
        print(f"  [ok] {label} device exists: {device_id}")
        return
    raise RuntimeError(
        f"{label} device {device_id} is not in cloud yet: HTTP {status} {body}. "
        "Let the node join and send one attribute report so the gateway can "
        "publish devices/<type>/<eui64>/reported to cloud."
    )


def post_power(client: httpx.Client, device_id: str, power: str) -> dict:
    response = client.post(
        f"{API_URL}/api/devices/{device_id}/command",
        json={
            "op": "set",
            "target": {"power": power},
            "timeout_ms": COMMAND_TIMEOUT_MS,
        },
    )
    response.raise_for_status()
    command = response.json()
    print(f"  [ok] POST {power.upper()} command id={command['id']}")
    return command


def wait_command(client: httpx.Client, command_id: str) -> dict:
    deadline = time.time() + COMMAND_WAIT_S
    last: dict = {}
    while time.time() < deadline:
        response = client.get(f"{API_URL}/api/commands/{command_id}")
        response.raise_for_status()
        last = response.json()
        status = last.get("status")
        if status in TERMINAL_STATUSES:
            print(f"  [ok] command {command_id} terminal status={status}")
            return last
        time.sleep(0.25)
    raise RuntimeError(
        f"Command {command_id} did not reach terminal status within "
        f"{COMMAND_WAIT_S:.1f}s; last={last}"
    )


def wait_light_state(client: httpx.Client, device_id: str, expected: str) -> dict:
    deadline = time.time() + STATE_WAIT_S
    last: dict = {}
    while time.time() < deadline:
        status, body = get_json(client, f"/api/devices/{device_id}/state")
        if status == 200:
            last = body
            state = body.get("state", {})
            if state.get("power") == expected:
                print(f"  [ok] light state power={expected}")
                return body
        else:
            last = {"status": status, "body": body}
        time.sleep(0.5)
    raise RuntimeError(
        f"Light state did not become power={expected!r} within "
        f"{STATE_WAIT_S:.1f}s; last={last}"
    )


def print_motion_context(client: httpx.Client) -> None:
    if not MOTION_ID:
        return
    status, body = get_json(client, f"/api/devices/{MOTION_ID}/state")
    if status == 200:
        print(f"  [ok] motion latest state: {body.get('state')}")
    else:
        print(f"  [warn] motion state unavailable: HTTP {status} {body}")

    status, body = get_json(
        client,
        f"/api/events/?device_id={MOTION_ID}&event_type=occupancy_changed&limit=3",
    )
    if status == 200:
        print(f"  [ok] recent motion occupancy events: {len(body)}")
    else:
        print(f"  [warn] motion events unavailable: HTTP {status} {body}")


def main() -> int:
    light_id = require_light_id()
    print(f"API   = {API_URL}")
    print(f"MQTT  = {MQTT_HOST}:{MQTT_PORT}")
    print(f"Light = {light_id}")
    if MOTION_ID:
        print(f"Motion = {MOTION_ID}")

    check_mqtt()

    with httpx.Client(timeout=5.0) as client:
        response = client.get(f"{API_URL}/health")
        response.raise_for_status()
        print(f"  [ok] /health -> {response.json()}")

        ensure_device_exists(client, light_id, "Light")
        if MOTION_ID:
            ensure_device_exists(client, MOTION_ID, "Motion")
            print_motion_context(client)

        off_error: Exception | None = None
        try:
            on_command = post_power(client, light_id, "on")
            on_result = wait_command(client, on_command["id"])
            if on_result["status"] != "executed":
                raise RuntimeError(f"ON command failed: {on_result}")
            wait_light_state(client, light_id, "on")
        finally:
            try:
                off_command = post_power(client, light_id, "off")
                off_result = wait_command(client, off_command["id"])
                if off_result["status"] != "executed":
                    raise RuntimeError(f"OFF command failed: {off_result}")
                wait_light_state(client, light_id, "off")
            except Exception as exc:
                off_error = exc

        if off_error:
            raise off_error

    print("\nCLOUD TO ZIGBEE SMOKE PASSED")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"\nCLOUD TO ZIGBEE SMOKE FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
