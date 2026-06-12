"""Tests for the command POST/GET router and MQTT publish."""
from __future__ import annotations

import importlib
import importlib.util

import pytest

from cloud.tests.auth_helpers import create_auth_user, login_headers


async def _parent_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )
    return await login_headers(client, "parent", "parent-pass")


@pytest.mark.asyncio
async def test_shared_command_service_persists_before_publish(
    db_session_factory, fake_mqtt, seed_light
):
    module_name = "cloud.app.command_execution"
    if importlib.util.find_spec(module_name) is None:
        pytest.fail("shared command execution service is missing")
    command_execution = importlib.import_module(module_name)

    async with db_session_factory() as db:
        command = await command_execution.execute_device_command(
            db,
            device_id=seed_light,
            op="set",
            target={"power": "on"},
            timeout_ms=5000,
            current_user=None,
        )

    assert command.device_id == seed_light
    assert command.status == "accepted"
    assert fake_mqtt.published[0]["command_id"] == command.id


@pytest.mark.asyncio
async def test_post_command_requires_authentication(client, fake_mqtt, seed_light):
    r = await client.post(
        f"/api/devices/{seed_light}/command",
        json={
            "op": "device.command",
            "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
        },
    )

    assert r.status_code == 401
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_post_command_rejects_viewer_role(
    client, db_session_factory, fake_mqtt, seed_light
):
    await create_auth_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )
    headers = await login_headers(client, "viewer", "viewer-pass")
    r = await client.post(
        f"/api/devices/{seed_light}/command",
        json={
            "op": "device.command",
            "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
        },
        headers=headers,
    )

    assert r.status_code == 403
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_post_command_publishes_and_persists(
    client, db_session_factory, fake_mqtt, seed_light
):
    headers = await _parent_headers(client, db_session_factory)
    body = {
        "op": "device.command",
        "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
        "timeout_ms": 5000,
    }
    r = await client.post(
        f"/api/devices/{seed_light}/command", json=body, headers=headers
    )
    assert r.status_code == 201, r.text
    cmd = r.json()
    assert cmd["device_id"] == seed_light
    assert cmd["status"] == "accepted"
    assert cmd["timeout_ms"] == 5000
    assert cmd["expires_at"] is not None

    # MQTT publish captured
    assert len(fake_mqtt.published) == 1
    pub = fake_mqtt.published[0]
    assert pub["command_id"] == cmd["id"]
    assert pub["op"] == "device.command"
    assert pub["target"]["command"] == "on"

    # GET returns same
    r2 = await client.get(f"/api/commands/{cmd['id']}", headers=headers)
    assert r2.status_code == 200
    assert r2.json()["id"] == cmd["id"]


@pytest.mark.asyncio
async def test_post_command_unknown_device_404(client, db_session_factory, fake_mqtt):
    headers = await _parent_headers(client, db_session_factory)
    r = await client.post(
        "/api/devices/nope/command",
        json={"op": "device.command", "target": {"command": "on"}},
        headers=headers,
    )
    assert r.status_code == 404
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_get_command_unknown_404(client, db_session_factory):
    headers = await _parent_headers(client, db_session_factory)

    r = await client.get("/api/commands/deadbeef", headers=headers)
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_post_command_default_timeout(
    client, db_session_factory, fake_mqtt, seed_light
):
    headers = await _parent_headers(client, db_session_factory)
    body = {
        "op": "device.command",
        "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "off"},
    }
    r = await client.post(
        f"/api/devices/{seed_light}/command", json=body, headers=headers
    )
    assert r.status_code == 201
    assert r.json()["timeout_ms"] == 5000


@pytest.mark.asyncio
async def test_post_command_user_friendly_power_on(
    client, db_session_factory, fake_mqtt, seed_light
):
    headers = await _parent_headers(client, db_session_factory)
    body = {"op": "set", "target": {"power": "on"}}
    r = await client.post(
        f"/api/devices/{seed_light}/command", json=body, headers=headers
    )
    assert r.status_code == 201, r.text
    cmd = r.json()
    # DB and response store the translated gateway format
    assert cmd["op"] == "device.command"
    assert cmd["target"] == {"endpoint": 1, "cluster_id": "0x0006", "command": "on"}

    # MQTT receives gateway format
    assert len(fake_mqtt.published) == 1
    pub = fake_mqtt.published[0]
    assert pub["op"] == "device.command"
    assert pub["target"]["command"] == "on"
    assert pub["target"]["cluster_id"] == "0x0006"


@pytest.mark.asyncio
async def test_post_command_user_friendly_power_off(
    client, db_session_factory, fake_mqtt, seed_light
):
    headers = await _parent_headers(client, db_session_factory)
    body = {"op": "set", "target": {"power": "off"}}
    r = await client.post(
        f"/api/devices/{seed_light}/command", json=body, headers=headers
    )
    assert r.status_code == 201
    assert r.json()["target"]["command"] == "off"
    assert fake_mqtt.published[0]["target"]["command"] == "off"


@pytest.mark.asyncio
async def test_post_command_user_friendly_invalid_target_422(
    client, db_session_factory, fake_mqtt, seed_light
):
    headers = await _parent_headers(client, db_session_factory)
    body = {"op": "set", "target": {"color": "red"}}
    r = await client.post(
        f"/api/devices/{seed_light}/command", json=body, headers=headers
    )
    assert r.status_code == 422
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_post_command_switch_rejects_422(
    client, db_session_factory, fake_mqtt, seed_switch
):
    headers = await _parent_headers(client, db_session_factory)
    body = {"op": "set", "target": {"power": "on"}}
    r = await client.post(
        f"/api/devices/{seed_switch}/command", json=body, headers=headers
    )
    assert r.status_code == 422
    assert "does not accept commands" in r.json()["detail"]
    assert fake_mqtt.published == []
