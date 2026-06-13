"""Tests for the gateway commissioning router (open / close)."""
from __future__ import annotations

from datetime import datetime

import pytest

from cloud.app.config import settings
from cloud.app.models import Event
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


async def _viewer_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )
    return await login_headers(client, "viewer", "viewer-pass")


@pytest.mark.asyncio
async def test_gateway_status_is_visible_to_authenticated_roles(
    client, db_session_factory
):
    async with db_session_factory() as session:
        session.add_all(
            [
                Event(
                    device_id=None,
                    event_type="gateway_online",
                    payload={"value": "online", "gateway_id": GW, "source": "gateway"},
                    occurred_at=datetime(2026, 6, 13, 7, 0),
                ),
                Event(
                    device_id=None,
                    event_type="gateway_online",
                    payload={"value": "offline", "gateway_id": GW, "source": "gateway"},
                    occurred_at=datetime(2026, 6, 13, 8, 0),
                ),
            ]
        )
        await session.commit()

    no_token = await client.get(f"/api/gateways/{GW}/status")
    assert no_token.status_code == 401

    headers_by_role = [
        await _admin_headers(client, db_session_factory),
        await _parent_headers(client, db_session_factory),
        await _viewer_headers(client, db_session_factory),
    ]
    for headers in headers_by_role:
        response = await client.get(f"/api/gateways/{GW}/status", headers=headers)
        assert response.status_code == 200, response.text
        assert response.json() == {
            "gateway_id": GW,
            "status": "offline",
            "event_type": "gateway_online",
            "occurred_at": "08:00 06/13/2026",
        }


@pytest.mark.asyncio
async def test_gateway_status_is_unknown_without_gateway_event(
    client, db_session_factory
):
    headers = await _viewer_headers(client, db_session_factory)

    response = await client.get(f"/api/gateways/{GW}/status", headers=headers)

    assert response.status_code == 200, response.text
    assert response.json() == {
        "gateway_id": GW,
        "status": "unknown",
        "event_type": None,
        "occurred_at": None,
    }


@pytest.mark.asyncio
async def test_commissioning_requires_admin_role(
    client, db_session_factory, fake_mqtt
):
    await create_auth_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )

    no_token = await client.post(f"/api/gateways/{GW}/commissioning/open", json={})
    assert no_token.status_code == 401

    viewer_headers = await login_headers(client, "viewer", "viewer-pass")
    viewer_forbidden = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={}, headers=viewer_headers
    )
    assert viewer_forbidden.status_code == 403
    assert fake_mqtt.published == []

    parent_headers = await _parent_headers(client, db_session_factory)
    parent_open = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={}, headers=parent_headers
    )
    assert parent_open.status_code == 403, parent_open.text

    parent_close = await client.post(
        f"/api/gateways/{GW}/commissioning/close", json={}, headers=parent_headers
    )
    assert parent_close.status_code == 403, parent_close.text

    admin_headers = await _admin_headers(client, db_session_factory)
    admin_open = await client.post(
        f"/api/gateways/{GW}/commissioning/open", json={}, headers=admin_headers
    )
    assert admin_open.status_code == 201, admin_open.text


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
