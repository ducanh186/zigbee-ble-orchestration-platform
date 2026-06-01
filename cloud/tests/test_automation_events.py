"""Tests for the cloud automation event log."""
from __future__ import annotations

import asyncio
from datetime import datetime

import pytest

from cloud.tests.auth_helpers import create_auth_user, login_headers


async def _operator_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="operator-1",
        username="operator",
        role="operator",
        password="operator-pass",
        home_id="home-1",
    )
    return await login_headers(client, "operator", "operator-pass")


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


async def _seed_rule(db_session_factory) -> str:
    from cloud.app.models import Automation, Device, Home, Room

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add_all(
            [
                Device(
                    id="motion-01",
                    device_type="motion",
                    room_id="room-1",
                    name="Motion Sensor",
                    is_online=True,
                ),
                Device(
                    id="light-01",
                    device_type="light",
                    room_id="room-1",
                    name="Main Light",
                    is_online=True,
                ),
            ]
        )
        session.add(
            Automation(
                id="rule-evt-01",
                name="Motion turns on light",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                version=1,
                trigger={
                    "device_id": "motion-01",
                    "device_type": "motion",
                    "event": "occupancy_changed",
                    "state": {"occupancy": "occupied"},
                },
                actions=[
                    {
                        "device_id": "light-01",
                        "device_type": "light",
                        "command": "on",
                    }
                ],
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()
    return "rule-evt-01"


def _envelope(event: str, ts: int, **inner) -> dict:
    return {
        "schema": "sb.v1",
        "msg_id": f"gw-{event}-{ts}",
        "ts": ts,
        "tenant_id": "hust",
        "site_id": "lab01",
        "gateway_id": "gw-ubuntu-01",
        "source": "gateway",
        "payload": {"event": event, **inner},
    }


@pytest.mark.asyncio
async def test_automation_executed_event_persisted(db_session_factory):
    from sqlalchemy import select

    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import AutomationEvent

    rule_id = await _seed_rule(db_session_factory)

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    service._loop = asyncio.get_running_loop()

    tasks: list[asyncio.Task] = []
    service._run_async = lambda coro_func: tasks.append(  # type: ignore[assignment]
        asyncio.create_task(coro_func())
    )

    service._handle_gateway_event(
        _envelope("automation_synced", 1776064500000, rule_id=rule_id, version=1)
    )
    service._handle_gateway_event(
        _envelope(
            "automation_executed",
            1776064501000,
            rule_id=rule_id,
            version=1,
            result="ok",
            target_device_id="light-01",
        )
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as session:
        rows = (
            await session.execute(
                select(AutomationEvent).order_by(AutomationEvent.occurred_at.asc())
            )
        ).scalars().all()

    assert [row.event_type for row in rows] == [
        "automation_synced",
        "automation_executed",
    ]
    assert [row.status for row in rows] == ["synced", "executed"]
    assert all(row.automation_id == rule_id for row in rows)


@pytest.mark.asyncio
async def test_automation_executed_failure_records_reason(db_session_factory):
    from sqlalchemy import select

    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import AutomationEvent

    rule_id = await _seed_rule(db_session_factory)

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    service._loop = asyncio.get_running_loop()

    tasks: list[asyncio.Task] = []
    service._run_async = lambda coro_func: tasks.append(  # type: ignore[assignment]
        asyncio.create_task(coro_func())
    )

    service._handle_gateway_event(
        _envelope(
            "automation_executed",
            1776064502000,
            rule_id=rule_id,
            version=1,
            result="timeout",
            reason="target light unreachable",
        )
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as session:
        row = (
            await session.execute(
                select(AutomationEvent).where(
                    AutomationEvent.automation_id == rule_id
                )
            )
        ).scalar_one()

    assert row.status == "timeout"
    assert row.reason == "target light unreachable"


@pytest.mark.asyncio
async def test_get_automation_events_filters_by_rule(client, db_session_factory):
    from cloud.app.models import AutomationEvent

    await _seed_rule(db_session_factory)

    async with db_session_factory() as session:
        session.add_all(
            [
                AutomationEvent(
                    automation_id="rule-evt-01",
                    event_type="automation_executed",
                    status="executed",
                    reason=None,
                    payload={"result": "ok"},
                    occurred_at=datetime(2026, 5, 21, 10, 0, 0),
                ),
                AutomationEvent(
                    automation_id="rule-evt-01",
                    event_type="automation_executed",
                    status="failed",
                    reason="device offline",
                    payload={"result": "failed"},
                    occurred_at=datetime(2026, 5, 21, 11, 0, 0),
                ),
                AutomationEvent(
                    automation_id="other-rule",
                    event_type="automation_synced",
                    status="synced",
                    reason=None,
                    payload={},
                    occurred_at=datetime(2026, 5, 21, 12, 0, 0),
                ),
            ]
        )
        await session.commit()

    headers = await _operator_headers(client, db_session_factory)

    resp = await client.get(
        "/api/automation-events?automation_id=rule-evt-01",
        headers=headers,
    )

    assert resp.status_code == 200
    items = resp.json()
    assert len(items) == 2
    assert items[0]["status"] == "failed"
    assert items[0]["reason"] == "device offline"
    assert items[1]["status"] == "executed"


@pytest.mark.asyncio
async def test_get_automation_events_respects_limit_and_offset(
    client, db_session_factory
):
    from cloud.app.models import AutomationEvent

    async with db_session_factory() as session:
        for i in range(5):
            session.add(
                AutomationEvent(
                    automation_id="rule-x",
                    event_type="automation_executed",
                    status="executed",
                    reason=None,
                    payload={"i": i},
                    occurred_at=datetime(2026, 5, 21, 10, i, 0),
                )
            )
        await session.commit()

    headers = await _admin_headers(client, db_session_factory)

    page1 = await client.get(
        "/api/automation-events?automation_id=rule-x&limit=2&offset=0",
        headers=headers,
    )
    page2 = await client.get(
        "/api/automation-events?automation_id=rule-x&limit=2&offset=2",
        headers=headers,
    )

    assert page1.status_code == 200 and page2.status_code == 200
    assert len(page1.json()) == 2
    assert len(page2.json()) == 2
    assert {item["payload"]["i"] for item in page1.json()} == {4, 3}
    assert {item["payload"]["i"] for item in page2.json()} == {2, 1}
