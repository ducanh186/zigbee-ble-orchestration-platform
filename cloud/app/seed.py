"""Seed the database with initial development data.

Usage:
    python -m cloud.app.seed
"""
from __future__ import annotations

import asyncio

from sqlalchemy import select

from cloud.app.database import async_session, init_db
from cloud.app.models import Device, Home, Room, User


async def _upsert(session, model, pk: str, **kwargs):
    """Insert a row if its primary key does not already exist."""
    existing = await session.get(model, pk)
    if existing is not None:
        return existing
    obj = model(id=pk, **kwargs)
    session.add(obj)
    return obj


async def seed() -> None:
    await init_db()

    async with async_session() as session:
        async with session.begin():
            # Home
            await _upsert(session, Home, "home-01", name="HUST Lab")

            # Rooms
            await _upsert(session, Room, "room-01", home_id="home-01", name="Lab 01")
            await _upsert(session, Room, "room-02", home_id="home-01", name="Lab 02")

            # Devices
            await _upsert(
                session,
                Device,
                "light-01",
                device_type="light",
                room_id="room-01",
                name="Light 01",
            )
            await _upsert(
                session,
                Device,
                "pir-01",
                device_type="occupancy_sensor",
                room_id="room-01",
                name="PIR Sensor 01",
            )
            await _upsert(
                session,
                Device,
                "light-02",
                device_type="light",
                room_id="room-02",
                name="Light 02",
            )

            # User
            await _upsert(
                session, User, "admin", username="admin", home_id="home-01"
            )

    print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
