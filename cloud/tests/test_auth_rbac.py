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
    assert authmod.decode_access_token(token)["role"] == "parent"

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


async def _create_user(
    db_session_factory,
    *,
    user_id: str,
    username: str,
    role: str,
    password: str,
    home_id: str | None,
    display_name: str | None = None,
    must_change_password: bool = False,
    is_active: bool = True,
):
    from cloud.app.auth import hash_password
    from cloud.app.models import User

    async with db_session_factory() as session:
        if home_id is not None:
            await _ensure_home(session, home_id)
        session.add(
            User(
                id=user_id,
                username=username,
                display_name=display_name,
                role=role,
                password_hash=hash_password(password),
                home_id=home_id,
                must_change_password=must_change_password,
                is_active=is_active,
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
    from cloud.app.models import User

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
    assert body["username"] == "admin"
    assert body["role"] == "admin"
    assert body["home_id"] is None
    assert body["expires_at"]
    assert body["refresh_token"]
    assert body["refresh_expires_at"]
    async with db_session_factory() as session:
        user = (
            await session.execute(select(User).where(User.username == "admin"))
        ).scalar_one()
        assert user.last_login_at is not None
        assert user.last_login_at.tzinfo is None

    bad = await client.post(
        "/auth/login",
        json={"username": "admin", "password": "wrong"},
    )
    assert bad.status_code == 401


@pytest.mark.asyncio
async def test_inactive_user_cannot_login(client, db_session_factory):
    await _create_user(
        db_session_factory,
        user_id="inactive-1",
        username="inactive",
        role="parent",
        password="parent-pass",
        home_id="home-1",
        is_active=False,
    )

    response = await client.post(
        "/auth/login",
        json={"username": "inactive", "password": "parent-pass"},
    )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_refresh_rotates_token_and_rejects_reuse(client, db_session_factory):
    await _create_user(
        db_session_factory,
        user_id="refresh-1",
        username="refresh-parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )

    login_response = await client.post(
        "/auth/login",
        json={"username": "refresh-parent", "password": "parent-pass"},
    )
    assert login_response.status_code == 200
    first = login_response.json()

    refreshed_response = await client.post(
        "/auth/refresh",
        json={"refresh_token": first["refresh_token"]},
    )
    assert refreshed_response.status_code == 200
    refreshed = refreshed_response.json()
    assert refreshed["access_token"]
    assert refreshed["refresh_token"]
    assert refreshed["refresh_token"] != first["refresh_token"]

    me = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {refreshed['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["user_id"] == "refresh-1"

    reused = await client.post(
        "/auth/refresh",
        json={"refresh_token": first["refresh_token"]},
    )
    assert reused.status_code == 401


@pytest.mark.asyncio
async def test_expired_refresh_token_is_rejected(
    client,
    db_session_factory,
    monkeypatch,
):
    from cloud.app.config import settings

    monkeypatch.setattr(settings, "auth_refresh_token_ttl_seconds", -1)
    await _create_user(
        db_session_factory,
        user_id="refresh-expired-1",
        username="refresh-expired",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )

    login_response = await client.post(
        "/auth/login",
        json={"username": "refresh-expired", "password": "parent-pass"},
    )
    assert login_response.status_code == 200

    refreshed = await client.post(
        "/auth/refresh",
        json={"refresh_token": login_response.json()["refresh_token"]},
    )
    assert refreshed.status_code == 401


@pytest.mark.asyncio
async def test_logout_revokes_refresh_token(client, db_session_factory):
    await _create_user(
        db_session_factory,
        user_id="logout-refresh-1",
        username="logout-refresh",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )
    login_response = await client.post(
        "/auth/login",
        json={"username": "logout-refresh", "password": "parent-pass"},
    )
    refresh_token = login_response.json()["refresh_token"]

    logout = await client.post(
        "/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert logout.status_code == 204
    assert (await client.post("/auth/logout", json={})).status_code == 204
    assert (await client.post("/auth/logout")).status_code == 204

    refreshed = await client.post(
        "/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refreshed.status_code == 401


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("stored_role", "expected_role"),
    [
        ("operator", "parent"),
        ("user", "parent"),
        ("parent", "parent"),
        ("viewer", "viewer"),
        ("member", "viewer"),
    ],
)
async def test_login_returns_canonical_role_and_token(
    client,
    db_session_factory,
    stored_role,
    expected_role,
):
    username = f"{stored_role}-login"
    await _create_user(
        db_session_factory,
        user_id=f"{stored_role}-1",
        username=username,
        role=stored_role,
        password="role-pass",
        home_id="home-1",
    )

    response = await client.post(
        "/auth/login",
        json={"username": username, "password": "role-pass"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["role"] == expected_role

    from cloud.app.auth import decode_access_token

    assert decode_access_token(body["access_token"])["role"] == expected_role


@pytest.mark.asyncio
async def test_auth_me_requires_token_and_hides_password_hash(client, db_session_factory):
    await _create_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        display_name="Demo Parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )

    no_token = await client.get("/auth/me")
    assert no_token.status_code == 401

    token = await _login(client, "parent", "parent-pass")
    response = await client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "parent-1"
    assert body["username"] == "parent"
    assert body["display_name"] == "Demo Parent"
    assert body["role"] == "parent"
    assert body["home_id"] == "home-1"
    assert body["must_change_password"] is False
    assert "password_hash" not in body


@pytest.mark.asyncio
async def test_change_password_rotates_hash_and_requires_new_password(
    client,
    db_session_factory,
):
    from cloud.app.models import User

    await _create_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="old-pass",
        home_id="home-1",
        must_change_password=True,
    )

    login_response = await client.post(
        "/auth/login",
        json={"username": "parent", "password": "old-pass"},
    )
    assert login_response.status_code == 200
    login_body = login_response.json()
    token = login_body["access_token"]
    refresh_token = login_body["refresh_token"]
    changed = await client.post(
        "/auth/change-password",
        json={"old_password": "old-pass", "new_password": "new-pass"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert changed.status_code == 204
    assert (await client.post(
        "/auth/login",
        json={"username": "parent", "password": "old-pass"},
    )).status_code == 401
    new_login = await client.post(
        "/auth/login",
        json={"username": "parent", "password": "new-pass"},
    )
    assert new_login.status_code == 200
    assert new_login.json()["must_change_password"] is False
    revoked_refresh = await client.post(
        "/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert revoked_refresh.status_code == 401
    async with db_session_factory() as session:
        user = (
            await session.execute(select(User).where(User.username == "parent"))
        ).scalar_one()
        assert user.password_changed_at is not None
        assert user.password_changed_at.tzinfo is None


@pytest.mark.asyncio
async def test_seed_creates_login_ready_demo_roles(client, db_session_factory, monkeypatch):
    from cloud.app import seed as seedmod

    monkeypatch.setenv("SB_ADMIN_INITIAL_PASSWORD", "admin-seed-pass")
    monkeypatch.setenv("SB_PARENT_INITIAL_PASSWORD", "parent-seed-pass")
    monkeypatch.setenv("SB_VIEWER_INITIAL_PASSWORD", "viewer-seed-pass")
    monkeypatch.setattr(seedmod, "async_session", db_session_factory)

    async def _noop_init_db():
        return None

    monkeypatch.setattr(seedmod, "init_db", _noop_init_db)

    await seedmod.seed()

    for username, password, expected_role in [
        ("admin", "admin-seed-pass", "admin"),
        ("parent", "parent-seed-pass", "parent"),
        ("viewer", "viewer-seed-pass", "viewer"),
    ]:
        response = await client.post(
            "/auth/login",
            json={"username": username, "password": password},
        )
        assert response.status_code == 200
        assert response.json()["role"] == expected_role
        assert response.json()["home_id"] == "home-01"
        assert response.json()["must_change_password"] is True


@pytest.mark.asyncio
async def test_seed_assigns_unclaimed_devices_to_demo_room(
    db_session_factory,
    monkeypatch,
):
    from cloud.app import seed as seedmod
    from cloud.app.models import Device

    async with db_session_factory() as session:
        session.add(
            Device(
                id="00000000000000AA",
                device_type="light",
                eui64="00000000000000AA",
                room_id=None,
            )
        )
        await session.commit()

    monkeypatch.setattr(seedmod, "async_session", db_session_factory)

    async def _noop_init_db():
        return None

    monkeypatch.setattr(seedmod, "init_db", _noop_init_db)

    await seedmod.seed()

    async with db_session_factory() as session:
        device = await session.get(Device, "00000000000000AA")
        assert device.room_id == "room-01"


@pytest.mark.asyncio
async def test_seed_does_not_reset_existing_password_hash(
    client,
    db_session_factory,
    monkeypatch,
):
    from cloud.app import seed as seedmod

    await _create_user(
        db_session_factory,
        user_id="parent",
        username="parent",
        role="parent",
        password="changed-pass",
        home_id="home-01",
    )

    monkeypatch.setenv("SB_PARENT_INITIAL_PASSWORD", "seed-pass")
    monkeypatch.setattr(seedmod, "async_session", db_session_factory)

    async def _noop_init_db():
        return None

    monkeypatch.setattr(seedmod, "init_db", _noop_init_db)

    await seedmod.seed()

    old_password = await client.post(
        "/auth/login",
        json={"username": "parent", "password": "seed-pass"},
    )
    assert old_password.status_code == 401

    changed_password = await client.post(
        "/auth/login",
        json={"username": "parent", "password": "changed-pass"},
    )
    assert changed_password.status_code == 200


@pytest.mark.asyncio
async def test_legacy_seed_password_env_logs_sanitized_warning(
    db_session_factory,
    monkeypatch,
    capsys,
):
    from cloud.app import seed as seedmod

    monkeypatch.delenv("SB_PARENT_INITIAL_PASSWORD", raising=False)
    monkeypatch.setenv("SB_PARENT_PASSWORD", "do-not-print-this")
    monkeypatch.setattr(seedmod, "async_session", db_session_factory)

    async def _noop_init_db():
        return None

    monkeypatch.setattr(seedmod, "init_db", _noop_init_db)

    await seedmod.seed()

    output = capsys.readouterr().out
    assert "Deprecated env SB_PARENT_PASSWORD is set" in output
    assert "do-not-print-this" not in output


@pytest.mark.asyncio
async def test_seeded_parent_must_change_password_before_mutating(
    client,
    db_session_factory,
    seed_light,
):
    await _create_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
        must_change_password=True,
    )

    token = await _login(client, "parent", "parent-pass")
    blocked = await client.post(
        f"/api/devices/{seed_light}/command",
        json={"op": "device.command", "target": {"command": "on"}},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "password_change_required"


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
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )

    payload = {
        "eui64": "A8D417FEFF570B00",
        "device_type": "light",
        "model": "EFR32MG12_LIGHT_KIT",
    }

    unauthenticated = await client.post("/api/provisioning/labels", json=payload)
    assert unauthenticated.status_code == 401

    user_token = await _login(client, "parent", "parent-pass")
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
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )
    await _create_user(
        db_session_factory,
        user_id="parent-2",
        username="other",
        role="parent",
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

    user_token = await _login(client, "parent", "parent-pass")
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
async def test_parent_cannot_rename_unassigned_gateway_device(
    client,
    db_session_factory,
):
    from cloud.app.models import Device

    await _create_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
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

    user_token = await _login(client, "parent", "parent-pass")
    response = await client.patch(
        "/api/devices/0000000000000055",
        json={"name": "Lab Light"},
        headers={"Authorization": f"Bearer {user_token}"},
    )

    assert response.status_code == 403

    admin_token = await _login(client, "admin", "admin-pass")
    admin_response = await client.patch(
        "/api/devices/0000000000000055",
        json={"name": "Lab Light"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert admin_response.status_code == 200
    body = admin_response.json()
    assert body["id"] == "0000000000000055"
    assert body["eui64"] == "0000000000000055"
    assert body["room_id"] is None
    assert body["name"] == "Lab Light"
