"""Tests for the gateway commissioning router (open / close)."""
from __future__ import annotations

import pytest

from cloud.app.config import settings
from cloud.tests.auth_helpers import create_auth_user, login_headers


GW = settings.gateway_id  # "gw-ubuntu-01" by default


async def _admin_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )
    return await login_headers(client, "admin", "admin-pass")


@pytest.mark.asyncio
async def test_open_requires_admin_role(client, db_session_factory, fake_mqtt):
    await create_auth_user(
        db_session_factory,
        user_id="operator-1",
        username="operator",
        role="operator",
        password="operator-pass",
        home_id="home-1",
    )

    no_token = await client.post(f"/api/gateways/{GW}/commissioning/open", json={})
    assert no_token.status_code == 401

    headers = await login_headers(client, "operator", "operator-pass")
    non_admin = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={}, headers=headers
    )
    assert non_admin.status_code == 403
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_open_default_duration(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={}, headers=headers
    )
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
async def test_open_custom_duration(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open",
        json={"duration_sec": 30, "timeout_ms": 3000},
        headers=headers,
    )
    assert r.status_code == 201, r.text
    cmd = r.json()
    assert cmd["target"] == {"duration_sec": 30}
    assert cmd["timeout_ms"] == 3000


@pytest.mark.asyncio
async def test_open_duration_too_small_422(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open",
        json={"duration_sec": 0},
        headers=headers,
    )
    assert r.status_code == 422
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_open_duration_too_big_422(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open",
        json={"duration_sec": 181},
        headers=headers,
    )
    assert r.status_code == 422
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_open_unknown_gateway_404(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        "/api/gateways/some-other-gw/commissioning/open",
        json={},
        headers=headers,
    )
    assert r.status_code == 404
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_close(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/close", json={}, headers=headers
    )
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
async def test_open_then_get_command(client, db_session_factory, fake_mqtt):
    headers = await _admin_headers(client, db_session_factory)
    r = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={}, headers=headers
    )
    assert r.status_code == 201
    cmd_id = r.json()["id"]

    r2 = await client.get(f"/api/commands/{cmd_id}", headers=headers)
    assert r2.status_code == 200
    got = r2.json()
    assert got["id"] == cmd_id
    assert got["op"] == "gateway.open_network"
    assert got["target_kind"] == "gateway"
    assert got["device_id"] is None
