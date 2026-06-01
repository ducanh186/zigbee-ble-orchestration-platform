from __future__ import annotations

from datetime import datetime
import importlib

import pytest
from sqlalchemy import select


async def _ensure_home(session, home_id: str) -> None:
    from cloud.app.models import Home

    if not (
        await session.execute(select(Home).where(Home.id == home_id))
    ).scalar_one_or_none():
        session.add(Home(id=home_id, name=f"Home {home_id}"))


async def _create_user(
    db_session_factory,
    *,
    user_id: str,
    username: str,
    role: str,
    password: str,
    home_id: str | None,
) -> None:
    from cloud.app.auth import hash_password
    from cloud.app.models import User

    async with db_session_factory() as session:
        if home_id is not None:
            await _ensure_home(session, home_id)
        session.add(
            User(
                id=user_id,
                username=username,
                role=role,
                password_hash=hash_password(password),
                home_id=home_id,
            )
        )
        await session.commit()


async def _login(client, username: str, password: str) -> dict[str, str]:
    response = await client.post(
        "/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def _seed_two_home_devices(db_session_factory) -> None:
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as session:
        session.add_all(
            [
                Home(id="home-1", name="Home 1"),
                Home(id="home-2", name="Home 2"),
                Room(id="room-1", home_id="home-1", name="Living"),
                Room(id="room-2", home_id="home-2", name="Other"),
                Device(
                    id="light-home-1",
                    device_type="light",
                    room_id="room-1",
                    name="Home 1 Light",
                    is_online=True,
                ),
                Device(
                    id="light-home-2",
                    device_type="light",
                    room_id="room-2",
                    name="Home 2 Light",
                    is_online=True,
                ),
                Device(
                    id="motion-home-1",
                    device_type="motion",
                    room_id="room-1",
                    name="Home 1 Motion",
                    is_online=True,
                ),
                Device(
                    id="unassigned-light",
                    device_type="light",
                    room_id=None,
                    name="Unassigned Light",
                    is_online=True,
                ),
            ]
        )
        await session.commit()


def _automation_body(light_id: str = "light-home-1") -> dict:
    return {
        "name": "Motion turns on a light",
        "enabled": True,
        "trigger": {
            "device_id": "motion-home-1",
            "device_type": "motion",
            "event": "occupancy_changed",
            "state": {"occupancy": "occupied"},
        },
        "actions": [
            {"device_id": light_id, "device_type": "light", "command": "on"},
        ],
    }


@pytest.mark.asyncio
async def test_read_endpoints_require_auth_and_scope_devices(
    client,
    db_session_factory,
):
    await _seed_two_home_devices(db_session_factory)
    await _create_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )

    no_token = await client.get("/api/devices/")
    assert no_token.status_code == 401

    headers = await _login(client, "viewer", "viewer-pass")
    listed = await client.get("/api/devices/", headers=headers)

    assert listed.status_code == 200
    ids = {device["id"] for device in listed.json()}
    assert {"light-home-1", "motion-home-1", "unassigned-light"} <= ids
    assert "light-home-2" not in ids

    same_home = await client.get("/api/devices/light-home-1", headers=headers)
    other_home = await client.get("/api/devices/light-home-2", headers=headers)

    assert same_home.status_code == 200
    assert other_home.status_code == 403


@pytest.mark.asyncio
async def test_event_read_endpoints_require_auth_and_scope_by_home(
    client,
    db_session_factory,
):
    from cloud.app.models import Automation, AutomationEvent, Event

    await _seed_two_home_devices(db_session_factory)
    await _create_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )

    async with db_session_factory() as session:
        session.add_all(
            [
                Event(
                    device_id="light-home-1",
                    event_type="device_reported",
                    payload={"device_id": "light-home-1"},
                    occurred_at=datetime(2026, 6, 1, 1, 0, 0),
                ),
                Event(
                    device_id="light-home-2",
                    event_type="device_reported",
                    payload={"device_id": "light-home-2"},
                    occurred_at=datetime(2026, 6, 1, 1, 1, 0),
                ),
                Event(
                    device_id="unassigned-light",
                    event_type="device_reported",
                    payload={"device_id": "unassigned-light"},
                    occurred_at=datetime(2026, 6, 1, 1, 2, 0),
                ),
                Automation(
                    id="rule-home-1",
                    name="Home 1 rule",
                    enabled=True,
                    tenant_id="hust",
                    site_id="lab01",
                    gateway_id="gw-ubuntu-01",
                    trigger={"device_id": "motion-home-1"},
                    actions=[{"device_id": "light-home-1"}],
                    version=1,
                    sync_status="pending",
                    last_run_status="never_run",
                ),
                Automation(
                    id="rule-home-2",
                    name="Home 2 rule",
                    enabled=True,
                    tenant_id="hust",
                    site_id="lab01",
                    gateway_id="gw-ubuntu-01",
                    trigger={"device_id": "light-home-2"},
                    actions=[{"device_id": "light-home-2"}],
                    version=1,
                    sync_status="pending",
                    last_run_status="never_run",
                ),
                AutomationEvent(
                    automation_id="rule-home-1",
                    event_type="automation_executed",
                    status="executed",
                    payload={},
                    occurred_at=datetime(2026, 6, 1, 1, 3, 0),
                ),
                AutomationEvent(
                    automation_id="rule-home-2",
                    event_type="automation_executed",
                    status="executed",
                    payload={},
                    occurred_at=datetime(2026, 6, 1, 1, 4, 0),
                ),
            ]
        )
        await session.commit()

    assert (await client.get("/api/events/")).status_code == 401
    assert (await client.get("/api/automation-events")).status_code == 401

    headers = await _login(client, "viewer", "viewer-pass")
    events = await client.get("/api/events/", headers=headers)
    automation_events = await client.get("/api/automation-events", headers=headers)

    assert events.status_code == 200
    assert {event["device_id"] for event in events.json()} == {
        "light-home-1",
        "unassigned-light",
    }
    assert automation_events.status_code == 200
    assert [event["automation_id"] for event in automation_events.json()] == [
        "rule-home-1"
    ]


@pytest.mark.asyncio
async def test_automation_writes_require_operator_and_same_home_devices(
    client,
    db_session_factory,
):
    await _seed_two_home_devices(db_session_factory)
    await _create_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )
    await _create_user(
        db_session_factory,
        user_id="operator-1",
        username="operator",
        role="operator",
        password="operator-pass",
        home_id="home-1",
    )

    no_token = await client.post("/api/automations", json=_automation_body())
    assert no_token.status_code == 401

    viewer_headers = await _login(client, "viewer", "viewer-pass")
    viewer_write = await client.post(
        "/api/automations",
        json=_automation_body(),
        headers=viewer_headers,
    )
    assert viewer_write.status_code == 403

    operator_headers = await _login(client, "operator", "operator-pass")
    cross_home_write = await client.post(
        "/api/automations",
        json=_automation_body("light-home-2"),
        headers=operator_headers,
    )
    assert cross_home_write.status_code == 403

    allowed = await client.post(
        "/api/automations",
        json=_automation_body(),
        headers=operator_headers,
    )
    assert allowed.status_code == 201


@pytest.mark.asyncio
async def test_provisioning_session_requires_operator_and_same_home_room(
    client,
    db_session_factory,
):
    from cloud.app.config import settings

    await _seed_two_home_devices(db_session_factory)
    await _create_user(
        db_session_factory,
        user_id="operator-1",
        username="operator",
        role="operator",
        password="operator-pass",
        home_id="home-1",
    )

    payload = {
        "gateway_id": settings.gateway_id,
        "room_id": "room-1",
        "device": {
            "eui64": "A8D417FEFF570B00",
            "install_code": "83FED3407A939723A5C639B26916D505C3B5",
            "device_type": "light",
            "model": "EFR32MG12_LIGHT_KIT",
        },
    }

    no_token = await client.post("/api/provisioning/sessions", json=payload)
    assert no_token.status_code == 401

    headers = await _login(client, "operator", "operator-pass")
    other_room = await client.post(
        "/api/provisioning/sessions",
        json=payload | {"room_id": "room-2"},
        headers=headers,
    )
    assert other_room.status_code == 403

    allowed = await client.post(
        "/api/provisioning/sessions",
        json=payload,
        headers=headers,
    )
    assert allowed.status_code == 201


@pytest.mark.asyncio
async def test_destructive_device_actions_are_admin_only(
    client,
    db_session_factory,
):
    await _seed_two_home_devices(db_session_factory)
    await _create_user(
        db_session_factory,
        user_id="operator-1",
        username="operator",
        role="operator",
        password="operator-pass",
        home_id="home-1",
    )
    await _create_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )

    operator_headers = await _login(client, "operator", "operator-pass")
    delete_forbidden = await client.delete(
        "/api/devices/light-home-1",
        headers=operator_headers,
    )
    rediscover_forbidden = await client.post(
        "/api/devices/light-home-1/rediscover",
        headers=operator_headers,
    )

    assert delete_forbidden.status_code == 403
    assert rediscover_forbidden.status_code == 403

    admin_headers = await _login(client, "admin", "admin-pass")
    rediscover_allowed = await client.post(
        "/api/devices/light-home-1/rediscover",
        headers=admin_headers,
    )
    assert rediscover_allowed.status_code == 201


def test_jwt_secret_accepts_legacy_env_alias(monkeypatch):
    import cloud.app.config as configmod

    monkeypatch.delenv("SB_AUTH_TOKEN_SECRET", raising=False)
    monkeypatch.setenv("SB_JWT_SECRET", "legacy-secret")
    assert configmod.Settings().auth_token_secret == "legacy-secret"

    monkeypatch.setenv("SB_AUTH_TOKEN_SECRET", "canonical-secret")
    assert configmod.Settings().auth_token_secret == "canonical-secret"

    reloaded = importlib.reload(configmod)
    assert reloaded.settings.auth_token_secret == "canonical-secret"
