from __future__ import annotations

from datetime import datetime

import pytest
from sqlalchemy import select

from cloud.app.models import Automation, AutomationEvent, Device, DeviceState, Home, Room


@pytest.mark.asyncio
async def test_schedule_execution_dispatches_command_and_writes_event(
    db_session_factory,
    fake_mqtt,
):
    from cloud.app.automation_execution import execute_automation_rule

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add(
            Device(
                id="light-01",
                device_type="light",
                room_id="room-1",
                name="Main Light",
                is_online=True,
            )
        )
        rule = Automation(
            id="schedule-1",
            name="Weekday light",
            enabled=True,
            tenant_id="hust",
            site_id="lab01",
            gateway_id="gw-ubuntu-01",
            trigger_type="schedule",
            schedule_cron="0 7 * * 1-5",
            trigger={"type": "schedule"},
            actions=[
                {
                    "type": "device_command",
                    "device_id": "light-01",
                    "device_type": "light",
                    "command": "on",
                }
            ],
            sync_status="synced",
            last_run_status="never_run",
        )
        session.add(rule)
        await session.commit()

        await execute_automation_rule(
            session,
            rule,
            scheduled_for=datetime(2026, 6, 15, 7, 0),
        )

        event = (
            await session.execute(
                select(AutomationEvent).where(
                    AutomationEvent.automation_id == rule.id
                )
            )
        ).scalar_one()

    assert fake_mqtt.published[0]["device_id"] == "light-01"
    assert event.event_type == "automation_executed"
    assert event.payload["scheduled_for"] == "2026-06-15T07:00:00"


@pytest.mark.asyncio
async def test_scheduled_toggle_sends_opposite_of_current_power(
    db_session_factory,
    fake_mqtt,
):
    from cloud.app.automation_execution import execute_automation_rule
    from cloud.app.models import DeviceState

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add(
            Device(
                id="light-01",
                device_type="light",
                room_id="room-1",
                name="Main Light",
                is_online=True,
            )
        )
        session.add(
            DeviceState(
                device_id="light-01",
                state={"power": "off"},
                reported_at=datetime(2026, 6, 15, 6, 0),
            )
        )
        rule = Automation(
            id="sch-toggle",
            name="Toggle light",
            enabled=True,
            tenant_id="hust",
            site_id="lab01",
            gateway_id="gw-ubuntu-01",
            trigger_type="schedule",
            schedule_cron="0 7 * * *",
            trigger={"type": "schedule"},
            actions=[
                {
                    "type": "device_command",
                    "device_id": "light-01",
                    "device_type": "light",
                    "command": "toggle",
                }
            ],
            sync_status="synced",
            last_run_status="never_run",
        )
        session.add(rule)
        await session.commit()

        await execute_automation_rule(
            session, rule, scheduled_for=datetime(2026, 6, 15, 7, 0)
        )

    assert fake_mqtt.published[-1]["target"]["command"] == "on"


@pytest.mark.asyncio
async def test_scheduled_toggle_without_state_fails_cleanly(
    db_session_factory,
    fake_mqtt,
):
    from cloud.app.automation_execution import execute_automation_rule

    async with db_session_factory() as session:
        session.add(Home(id="home-2", name="Test Home 2"))
        session.add(Room(id="room-2", home_id="home-2", name="Living"))
        session.add(
            Device(
                id="light-02",
                device_type="light",
                room_id="room-2",
                name="Stateless Light",
                is_online=True,
            )
        )
        rule = Automation(
            id="sch-toggle-nostate",
            name="Toggle no state",
            enabled=True,
            tenant_id="hust",
            site_id="lab01",
            gateway_id="gw-ubuntu-01",
            trigger_type="schedule",
            schedule_cron="0 7 * * *",
            trigger={"type": "schedule"},
            actions=[
                {
                    "type": "device_command",
                    "device_id": "light-02",
                    "device_type": "light",
                    "command": "toggle",
                }
            ],
            sync_status="synced",
            last_run_status="never_run",
        )
        session.add(rule)
        await session.commit()

        events = await execute_automation_rule(
            session, rule, scheduled_for=datetime(2026, 6, 15, 7, 0)
        )

    assert events[0].event_type == "automation_failed"
    assert events[0].reason == "toggle requires known device power state"
    assert fake_mqtt.published == []
