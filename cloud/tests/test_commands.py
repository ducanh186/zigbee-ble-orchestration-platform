"""Tests for the command POST/GET router and MQTT publish."""
from __future__ import annotations

import pytest


@pytest.mark.asyncio
async def test_post_command_publishes_and_persists(client, fake_mqtt, seed_light):
    body = {
        "op": "device.command",
        "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
        "timeout_ms": 5000,
    }
    r = await client.post(f"/api/devices/{seed_light}/command", json=body)
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
    r2 = await client.get(f"/api/commands/{cmd['id']}")
    assert r2.status_code == 200
    assert r2.json()["id"] == cmd["id"]


@pytest.mark.asyncio
async def test_post_command_unknown_device_404(client, fake_mqtt):
    r = await client.post(
        "/api/devices/nope/command",
        json={"op": "device.command", "target": {"command": "on"}},
    )
    assert r.status_code == 404
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_get_command_unknown_404(client):
    r = await client.get("/api/commands/deadbeef")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_post_command_default_timeout(client, fake_mqtt, seed_light):
    body = {
        "op": "device.command",
        "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "off"},
    }
    r = await client.post(f"/api/devices/{seed_light}/command", json=body)
    assert r.status_code == 201
    assert r.json()["timeout_ms"] == 5000


@pytest.mark.asyncio
async def test_post_command_user_friendly_power_on(client, fake_mqtt, seed_light):
    body = {"op": "set", "target": {"power": "on"}}
    r = await client.post(f"/api/devices/{seed_light}/command", json=body)
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
async def test_post_command_user_friendly_power_off(client, fake_mqtt, seed_light):
    body = {"op": "set", "target": {"power": "off"}}
    r = await client.post(f"/api/devices/{seed_light}/command", json=body)
    assert r.status_code == 201
    assert r.json()["target"]["command"] == "off"
    assert fake_mqtt.published[0]["target"]["command"] == "off"


@pytest.mark.asyncio
async def test_post_command_user_friendly_invalid_target_422(
    client, fake_mqtt, seed_light
):
    body = {"op": "set", "target": {"color": "red"}}
    r = await client.post(f"/api/devices/{seed_light}/command", json=body)
    assert r.status_code == 422
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_post_command_switch_rejects_422(
    client, fake_mqtt, seed_switch
):
    body = {"op": "set", "target": {"power": "on"}}
    r = await client.post(f"/api/devices/{seed_switch}/command", json=body)
    assert r.status_code == 422
    assert "does not accept commands" in r.json()["detail"]
    assert fake_mqtt.published == []
