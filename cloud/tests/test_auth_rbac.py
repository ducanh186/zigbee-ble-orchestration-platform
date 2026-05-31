from __future__ import annotations

import pytest
from fastapi import HTTPException
from sqlalchemy import select


def test_access_token_is_jwt_shaped_and_rejects_invalid_or_expired(monkeypatch):
    from cloud.app import auth as authmod
    from cloud.app.models import User

    user = User(
        id="jwt-1",
        username="jwt-user",
        role="operator",
        password_hash="unused",
        home_id="home-1",
    )

    token = authmod.create_access_token(user)
    assert token.count(".") == 2
    assert authmod.decode_access_token(token)["sub"] == "jwt-1"

    with pytest.raises(HTTPException) as invalid:
        authmod.decode_access_token("not-a-valid-token")
    assert invalid.value.status_code == 401

    monkeypatch.setattr(authmod.settings, "auth_token_ttl_seconds", -1)
    expired = authmod.create_access_token(user)
    with pytest.raises(HTTPException) as expired_error:
        authmod.decode_access_token(expired)
    assert expired_error.value.status_code == 401


async def _ensure_home(session, home_id: str) -> None:
    from cloud.app.models import Home

    if not (await session.execute(select(Home).where(Home.id == home_id))).scalar_one_or_none():
        session.add(Home(id=home_id, name=f"Home {home_id}"))


async def _create_user(db_session_factory, *, user_id: str, username: str, role: str, password: str, home_id: str | None):
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


async def _login(client, username: str, password: str) -> str:
    response = await client.post(
        "/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.mark.asyncio
async def test_login_returns_role_and_rejects_bad_password(client, db_session_factory):
    await _create_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )

    ok = await client.post(
        "/auth/login",
        json={"username": "admin", "password": "admin-pass"},
    )
    assert ok.status_code == 200
    body = ok.json()
    assert body["access_token"]
    assert body["user_id"] == "admin-1"
    assert body["role"] == "admin"
    assert body["home_id"] is None
    assert body["expires_at"]

    bad = await client.post(
        "/auth/login",
        json={"username": "admin", "password": "wrong"},
    )
    assert bad.status_code == 401


@pytest.mark.asyncio
async def test_provisioning_label_generation_requires_admin(client, db_session_factory):
    await _create_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )
    await _create_user(
        db_session_factory,
        user_id="user-1",
        username="customer",
        role="user",
        password="user-pass",
        home_id="home-1",
    )

    payload = {
        "eui64": "A8D417FEFF570B00",
        "device_type": "light",
        "model": "EFR32MG12_LIGHT_KIT",
    }

    unauthenticated = await client.post("/api/provisioning/labels", json=payload)
    assert unauthenticated.status_code == 401

    user_token = await _login(client, "customer", "user-pass")
    forbidden = await client.post(
        "/api/provisioning/labels",
        json=payload,
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert forbidden.status_code == 403

    admin_token = await _login(client, "admin", "admin-pass")
    allowed = await client.post(
        "/api/provisioning/labels",
        json=payload,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert allowed.status_code == 201
    assert allowed.json()["payload"]["eui64"] == payload["eui64"]


@pytest.mark.asyncio
async def test_device_label_rename_preserves_gateway_identity(
    client,
    db_session_factory,
    seed_light,
):
    await _create_user(
        db_session_factory,
        user_id="user-1",
        username="customer",
        role="user",
        password="user-pass",
        home_id="home-1",
    )
    await _create_user(
        db_session_factory,
        user_id="user-2",
        username="other",
        role="user",
        password="other-pass",
        home_id="home-2",
    )
    await _create_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )

    no_token = await client.patch(
        f"/api/devices/{seed_light}",
        json={"name": "Desk lamp"},
    )
    assert no_token.status_code == 401

    other_token = await _login(client, "other", "other-pass")
    forbidden = await client.patch(
        f"/api/devices/{seed_light}",
        json={"name": "Desk lamp"},
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert forbidden.status_code == 403

    user_token = await _login(client, "customer", "user-pass")
    renamed = await client.patch(
        f"/api/devices/{seed_light}",
        json={"name": "Desk lamp"},
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert renamed.status_code == 200
    body = renamed.json()
    assert body["id"] == seed_light
    assert body["eui64"] == "00124b0001aa22bb"
    assert body["name"] == "Desk lamp"

    admin_token = await _login(client, "admin", "admin-pass")
    admin_renamed = await client.patch(
        f"/api/devices/{seed_light}",
        json={"name": "Factory label"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert admin_renamed.status_code == 200
    assert admin_renamed.json()["name"] == "Factory label"


@pytest.mark.asyncio
async def test_user_can_rename_unassigned_gateway_device(
    client,
    db_session_factory,
):
    from cloud.app.models import Device

    await _create_user(
        db_session_factory,
        user_id="user-1",
        username="customer",
        role="user",
        password="user-pass",
        home_id="home-1",
    )
    async with db_session_factory() as session:
        session.add(
            Device(
                id="0000000000000055",
                device_type="light",
                eui64="0000000000000055",
                room_id=None,
                name="0000000000000055",
                is_online=True,
            )
        )
        await session.commit()

    user_token = await _login(client, "customer", "user-pass")
    response = await client.patch(
        "/api/devices/0000000000000055",
        json={"name": "Lab Light"},
        headers={"Authorization": f"Bearer {user_token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == "0000000000000055"
    assert body["eui64"] == "0000000000000055"
    assert body["room_id"] is None
    assert body["name"] == "Lab Light"
