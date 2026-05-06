"""Tests for the gateway commissioning router (open / close)."""
from __future__ import annotations

import pytest

from cloud.app.config import settings


GW = settings.gateway_id  # "gw-ubuntu-01" by default


@pytest.mark.asyncio
async def test_open_default_duration(client, fake_mqtt):
    r = await client.post(f"/api/gateways/{GW}/commissioning/open", json={})
    assert r.status_code == 201, r.text
    cmd = r.json()
    assert cmd["op"] == "gateway.open_network"
    assert cmd["target_kind"] == "gateway"
    assert cmd["device_id"] is None
    assert cmd["target"] == {"duration_sec": 180}
    assert cmd["status"] == "accepted"
    assert cmd["timeout_ms"] == 5000
    assert cmd["expires_at"] is not None

    assert len(fake_mqtt.published) == 1
    pub = fake_mqtt.published[0]
    assert pub["op"] == "gateway.open_network"
    assert pub["device_id"] is None
    assert pub["target"] == {"duration_sec": 180}


@pytest.mark.asyncio
async def test_open_custom_duration(client, fake_mqtt):
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open",
        json={"duration_sec": 30, "timeout_ms": 3000},
    )
    assert r.status_code == 201, r.text
    cmd = r.json()
    assert cmd["target"] == {"duration_sec": 30}
    assert cmd["timeout_ms"] == 3000


@pytest.mark.asyncio
async def test_open_duration_too_small_422(client, fake_mqtt):
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={"duration_sec": 0}
    )
    assert r.status_code == 422
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_open_duration_too_big_422(client, fake_mqtt):
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={"duration_sec": 181}
    )
    assert r.status_code == 422
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_open_unknown_gateway_404(client, fake_mqtt):
    r = await client.post(
        "/api/gateways/some-other-gw/commissioning/open", json={}
    )
    assert r.status_code == 404
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_close(client, fake_mqtt):
    r = await client.post(f"/api/gateways/{GW}/commissioning/close", json={})
    assert r.status_code == 201, r.text
    cmd = r.json()
    assert cmd["op"] == "gateway.close_network"
    assert cmd["target_kind"] == "gateway"
    assert cmd["device_id"] is None
    assert cmd["target"] == {}
    assert cmd["status"] == "accepted"

    assert len(fake_mqtt.published) == 1
    pub = fake_mqtt.published[0]
    assert pub["op"] == "gateway.close_network"
    assert pub["device_id"] is None
    assert pub["target"] == {}


@pytest.mark.asyncio
async def test_open_then_get_command(client, fake_mqtt):
    r = await client.post(f"/api/gateways/{GW}/commissioning/open", json={})
    assert r.status_code == 201
    cmd_id = r.json()["id"]

    r2 = await client.get(f"/api/commands/{cmd_id}")
    assert r2.status_code == 200
    got = r2.json()
    assert got["id"] == cmd_id
    assert got["op"] == "gateway.open_network"
    assert got["target_kind"] == "gateway"
    assert got["device_id"] is None
