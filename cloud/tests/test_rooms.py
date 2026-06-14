"""Tests for the rooms router."""
from __future__ import annotations

import pytest

from cloud.tests.auth_helpers import create_auth_user, login_headers


async def _seed_rooms(db_session_factory) -> None:
    from cloud.app.models import Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="Test Home"))
        s.add(Home(id="home-2", name="Other Home"))
        s.add(Room(id="room-1", home_id="home-1", name="Living"))
        s.add(Room(id="room-2", home_id="home-1", name="Bedroom"))
        s.add(Room(id="room-other", home_id="home-2", name="Garage"))
        await s.commit()


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
