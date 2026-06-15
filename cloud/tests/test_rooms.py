"""Tests for the rooms router."""
from __future__ import annotations

import pytest

from cloud.tests.auth_helpers import create_auth_user, login_headers


async def _seed_rooms(db_session_factory) -> None:
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="Test Home"))
        s.add(Home(id="home-2", name="Other Home"))
        s.add(Room(id="room-1", home_id="home-1", name="Living"))
        s.add(Room(id="room-2", home_id="home-1", name="Bedroom"))
        s.add(Room(id="room-other", home_id="home-2", name="Garage"))
        s.add(Device(id="light-1", device_type="light", room_id="room-1"))
        await s.commit()


async def _headers(
    client,
    db_session_factory,
    *,
    user_id: str,
    username: str,
    role: str,
    home_id: str | None,
) -> dict[str, str]:
    password = f"{username}-pass"
    await create_auth_user(
        db_session_factory,
        user_id=user_id,
        username=username,
        role=role,
        password=password,
        home_id=home_id,
    )
    return await login_headers(client, username, password)


@pytest.mark.asyncio
async def test_list_rooms_scoped_to_user_home(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    await create_auth_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )
    headers = await login_headers(client, "parent", "parent-pass")

    r = await client.get("/api/rooms/", headers=headers)
    assert r.status_code == 200
    rooms = r.json()
    assert {room["id"] for room in rooms} == {"room-1", "room-2"}
    # names are present for display
    assert {room["name"] for room in rooms} == {"Living", "Bedroom"}


@pytest.mark.asyncio
async def test_list_rooms_admin_sees_all(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    await create_auth_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )
    headers = await login_headers(client, "admin", "admin-pass")

    r = await client.get("/api/rooms/", headers=headers)
    assert r.status_code == 200
    assert {room["id"] for room in r.json()} == {"room-1", "room-2", "room-other"}


@pytest.mark.asyncio
async def test_list_rooms_requires_auth(client, db_session_factory):
    r = await client.get("/api/rooms/")
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_create_room_uses_parent_home(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="parent-create",
        username="parent-create",
        role="parent",
        home_id="home-1",
    )

    r = await client.post("/api/rooms/", json={"name": "Kitchen"}, headers=headers)

    assert r.status_code == 200
    body = r.json()
    assert body["id"].startswith("room_")
    assert body["name"] == "Kitchen"

    rooms = await client.get("/api/rooms/", headers=headers)
    assert any(
        room["id"] == body["id"] and room["name"] == "Kitchen"
        for room in rooms.json()
    )


@pytest.mark.asyncio
async def test_create_room_requires_user_home(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="admin-create",
        username="admin-create",
        role="admin",
        home_id=None,
    )

    r = await client.post("/api/rooms/", json={"name": "Kitchen"}, headers=headers)

    assert r.status_code == 400


@pytest.mark.asyncio
async def test_rename_room(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="parent-rename",
        username="parent-rename",
        role="parent",
        home_id="home-1",
    )

    r = await client.patch(
        "/api/rooms/room-2",
        json={"name": "Sleep Lab"},
        headers=headers,
    )

    assert r.status_code == 200
    assert r.json() == {"id": "room-2", "name": "Sleep Lab"}


@pytest.mark.asyncio
async def test_delete_empty_room(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="parent-delete",
        username="parent-delete",
        role="parent",
        home_id="home-1",
    )

    r = await client.delete("/api/rooms/room-2", headers=headers)

    assert r.status_code == 200
    rooms = await client.get("/api/rooms/", headers=headers)
    assert {room["id"] for room in rooms.json()} == {"room-1"}


@pytest.mark.asyncio
async def test_delete_non_empty_room_is_blocked(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="parent-delete-full",
        username="parent-delete-full",
        role="parent",
        home_id="home-1",
    )

    r = await client.delete("/api/rooms/room-1", headers=headers)

    assert r.status_code == 409
    assert r.json()["detail"] == "Room not empty"


@pytest.mark.asyncio
async def test_viewer_cannot_mutate_rooms(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="viewer-rooms",
        username="viewer-rooms",
        role="viewer",
        home_id="home-1",
    )

    create = await client.post("/api/rooms/", json={"name": "Kitchen"}, headers=headers)
    rename = await client.patch(
        "/api/rooms/room-1", json={"name": "Kitchen"}, headers=headers
    )
    delete = await client.delete("/api/rooms/room-2", headers=headers)

    assert create.status_code == 403
    assert rename.status_code == 403
    assert delete.status_code == 403


@pytest.mark.asyncio
async def test_cross_home_room_mutation_is_forbidden(client, db_session_factory):
    await _seed_rooms(db_session_factory)
    headers = await _headers(
        client,
        db_session_factory,
        user_id="parent-cross-home",
        username="parent-cross-home",
        role="parent",
        home_id="home-1",
    )

    rename = await client.patch(
        "/api/rooms/room-other",
        json={"name": "Wrong Home"},
        headers=headers,
    )
    delete = await client.delete("/api/rooms/room-other", headers=headers)

    assert rename.status_code == 403
    assert delete.status_code == 403
