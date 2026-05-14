"""Seed the database with initial development data.

Usage:
    python -m cloud.app.seed
"""
from __future__ import annotations

import asyncio

from sqlalchemy import delete, select

from cloud.app.database import async_session, init_db
from cloud.app.models import Command, Device, DeviceState, Event, Home, Room, User

# Placeholder device IDs that were seeded before real MQTT registration existed.
# These have no EUI64 and clutter the dashboard alongside real devices.
_LEGACY_PLACEHOLDER_IDS = {"light-01", "light-02", "pir-01", "switch-01"}


async def _upsert(session, model, pk: str, **kwargs):
    """Insert a row if its primary key does not already exist."""
    existing = await session.get(model, pk)
    if existing is not None:
        for key, value in kwargs.items():
            setattr(existing, key, value)
        return existing
    obj = model(id=pk, **kwargs)
    session.add(obj)
    return obj


async def seed() -> None:
    await init_db()

    async with async_session() as session:
        async with session.begin():
            # Remove legacy placeholder devices (no EUI64, no real data)
            for pid in _LEGACY_PLACEHOLDER_IDS:
                existing = await session.get(Device, pid)
                if existing is not None:
                    await session.execute(
                        delete(Command).where(Command.device_id == pid)
                    )
                    await session.execute(
                        delete(Event).where(Event.device_id == pid)
                    )
                    await session.execute(
                        delete(DeviceState).where(DeviceState.device_id == pid)
                    )
                    await session.delete(existing)
                    print(f"Removed placeholder device: {pid}")

            # Home
            await _upsert(session, Home, "home-01", name="HUST Lab")

            # Rooms
            await _upsert(session, Room, "room-01", home_id="home-01", name="Lab 01")
            await _upsert(session, Room, "room-02", home_id="home-01", name="Lab 02")

            # No placeholder devices — real devices are auto-registered
            # via MQTT when the gateway discovers them (ZDO + registry).

            # User
            await _upsert(
                session, User, "admin", username="admin", home_id="home-01"
            )

    print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
