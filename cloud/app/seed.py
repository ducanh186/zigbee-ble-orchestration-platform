"""Seed the database with initial development data.

Usage:
    python -m cloud.app.seed
"""
from __future__ import annotations

import asyncio
import os

from sqlalchemy import delete, select, update

from cloud.app.auth import hash_password
from cloud.app.database import async_session, init_db
from cloud.app.models import (
    Command,
    Device,
    DeviceState,
    Event,
    FactoryDevice,
    Home,
    Room,
    User,
)

# Placeholder device IDs that were seeded before real MQTT registration existed.
# These have no EUI64 and clutter the dashboard alongside real devices.
#
# Also includes synthetic IDs from cloud/scripts/smoke_test.py and
# cloud/scripts/test_phase3_phase4.py — these scripts insert rows into the
# same Postgres as the live dashboard when run without SB_TEST_DATABASE_URL,
# and the rows persist until something deletes them. Seed sweeps them out so
# the dashboard always boots with only real MQTT-registered devices.
_LEGACY_PLACEHOLDER_IDS = {
    "light-01", "light-02", "pir-01", "switch-01",
    # smoke_test.py / test_phase3_phase4.py synthetic devices
    "light-00124b0001aa22bb",
    "switch-00124b0002cc33dd",
    "light-00124b0003ee44ff",
    # Manual curl probes left from ACL / contract testing
    "0xPROBE", "0xTEST", "0xPROBE2",
}

_SEEDED_USERS = [
    (
        "admin",
        "admin",
        "System Admin",
        "admin",
        "SB_ADMIN_INITIAL_PASSWORD",
        "SB_ADMIN_PASSWORD",
    ),
    (
        "parent",
        "parent",
        "Parent / Home Owner",
        "parent",
        "SB_PARENT_INITIAL_PASSWORD",
        "SB_PARENT_PASSWORD",
    ),
    (
        "viewer",
        "viewer",
        "Member",
        "viewer",
        "SB_VIEWER_INITIAL_PASSWORD",
        "SB_VIEWER_PASSWORD",
    ),
]

_PLACEHOLDER_FACTORY_DEVICES = [
    (
        "0000000000000053",
        "00112233445566778899AABBCCDDEEFF528F",
        "sensor",
        "EFR32MG12_ENV_KIT",
    ),
    (
        "0000000000000054",
        "102132435465768798A9BACBDCEDFE0F2D18",
        "light",
        "EFR32MG12_LIGHT_KIT",
    ),
    (
        "0000000000000055",
        "FFEEDDCCBBAA99887766554433221100520D",
        "light",
        "EFR32MG12_LIGHT_KIT",
    ),
]


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


def _initial_password(new_env: str, legacy_env: str) -> str | None:
    password = os.getenv(new_env)
    if password:
        return password
    legacy_password = os.getenv(legacy_env)
    if legacy_password:
        print(f"Deprecated env {legacy_env} is set. Use {new_env} instead.")
        return legacy_password
    return None


def _seeded_user_kwargs(
    username: str,
    display_name: str,
    role: str,
    new_password_env: str,
    legacy_password_env: str,
) -> dict:
    kwargs = {
        "username": username,
        "display_name": display_name,
        "role": role,
        "home_id": "home-01",
        "must_change_password": True,
        "is_active": True,
    }
    password = _initial_password(new_password_env, legacy_password_env)
    if password:
        kwargs["password_hash"] = hash_password(password)
    return kwargs


async def _seed_missing_user(
    session,
    user_id: str,
    username: str,
    display_name: str,
    role: str,
    new_password_env: str,
    legacy_password_env: str,
) -> None:
    existing = await session.get(User, user_id)
    if existing is not None:
        return
    session.add(
        User(
            id=user_id,
            **_seeded_user_kwargs(
                username,
                display_name,
                role,
                new_password_env,
                legacy_password_env,
            ),
        )
    )


async def _seed_missing_factory_device(
    session,
    eui64: str,
    install_code: str,
    device_type: str,
    model: str,
) -> None:
    existing = await session.get(FactoryDevice, eui64)
    if existing is not None:
        return
    session.add(
        FactoryDevice(
            eui64=eui64,
            install_code=install_code,
            device_type=device_type,
            model=model,
            is_active=True,
        )
    )


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
            await session.execute(
                update(Device)
                .where(Device.room_id.is_(None))
                .values(room_id="room-01")
            )

            for eui64, install_code, device_type, model in _PLACEHOLDER_FACTORY_DEVICES:
                await _seed_missing_factory_device(
                    session,
                    eui64,
                    install_code,
                    device_type,
                    model,
                )

            for (
                user_id,
                username,
                display_name,
                role,
                new_password_env,
                legacy_password_env,
            ) in _SEEDED_USERS:
                await _seed_missing_user(
                    session,
                    user_id,
                    username,
                    display_name,
                    role,
                    new_password_env,
                    legacy_password_env,
                )

    print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
