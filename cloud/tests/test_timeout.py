"""Tests for the command timeout sweeper."""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from cloud.app.command_timeout import sweep_once
from cloud.app.models import Command, Device


@pytest.mark.asyncio
async def test_sweep_marks_only_expired_nonterminal(db_session_factory):
    now = datetime.now(UTC).replace(tzinfo=None)
    async with db_session_factory() as s:
        s.add(Device(id="light-01", device_type="light", name="L1"))
        # Expired, pending: should become timeout
        s.add(
            Command(
                id="expired-pending",
                device_id="light-01",
                op="device.command",
                target={"command": "on"},
                status="accepted",
                timeout_ms=1000,
                expires_at=now - timedelta(seconds=2),
            )
        )
        # Expired but already terminal: should stay as-is
        s.add(
            Command(
                id="expired-done",
                device_id="light-01",
                op="device.command",
                target={"command": "on"},
                status="executed",
                timeout_ms=1000,
                expires_at=now - timedelta(seconds=2),
            )
        )
        # Not yet expired: should stay as-is
        s.add(
            Command(
                id="future",
                device_id="light-01",
                op="device.command",
                target={"command": "on"},
                status="accepted",
                timeout_ms=60000,
                expires_at=now + timedelta(seconds=60),
            )
        )
        await s.commit()

    count = await sweep_once(db_session_factory)
    assert count == 1

    from sqlalchemy import select

    async with db_session_factory() as s:
        r = await s.execute(select(Command))
        by_id = {c.id: c for c in r.scalars().all()}
        assert by_id["expired-pending"].status == "timeout"
        assert "timeout" in (by_id["expired-pending"].reason or "")
        assert by_id["expired-done"].status == "executed"
        assert by_id["future"].status == "accepted"


@pytest.mark.asyncio
async def test_sweep_noop_when_nothing_expired(db_session_factory):
    count = await sweep_once(db_session_factory)
    assert count == 0


@pytest.mark.asyncio
async def test_sweep_marks_provisioning_session_failed_on_prepare_join_timeout(
    db_session_factory,
):
    from cloud.app.models import Home, ProvisioningSession, Room

    now = datetime.now(UTC).replace(tzinfo=None)
    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            Command(
                id="prepare-timeout",
                device_id=None,
                target_kind="gateway",
                op="gateway.prepare_join",
                target={"eui64": "A8D417FEFF570B00"},
                status="accepted",
                timeout_ms=1000,
                expires_at=now - timedelta(seconds=2),
            )
        )
        s.add(
            ProvisioningSession(
                id="prov-timeout",
                gateway_id="gw-ubuntu-01",
                room_id="room-1",
                eui64="A8D417FEFF570B00",
                install_code="83FED3407A939723A5C639B26916D505C3B5",
                device_type="light",
                status="pending",
                command_id="prepare-timeout",
            )
        )
        await s.commit()

    count = await sweep_once(db_session_factory)
    assert count == 1

    async with db_session_factory() as s:
        session = await s.get(ProvisioningSession, "prov-timeout")
        command = await s.get(Command, "prepare-timeout")

    assert command.status == "timeout"
    assert session.status == "failed"
    assert "timeout" in session.reason
