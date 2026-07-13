from __future__ import annotations

from datetime import datetime
from unittest.mock import AsyncMock
from zoneinfo import ZoneInfo

import pytest

from cloud.app.models import Automation


@pytest.mark.asyncio
async def test_worker_executes_due_rule_once_per_minute(db_session_factory):
    from cloud.app.schedule_worker import ScheduleWorker

    async with db_session_factory() as session:
        session.add(
            Automation(
                id="schedule-1",
                name="Weekday light",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger_type="schedule",
                schedule_cron="0 7 * * 1-5",
                trigger={"type": "schedule"},
                actions=[],
                sync_status="synced",
                last_run_status="never_run",
            )
        )
        await session.commit()

    executor = AsyncMock()
    worker = ScheduleWorker(db_session_factory, executor=executor)
    now = datetime(
        2026,
        6,
        15,
        7,
        0,
        5,
        tzinfo=ZoneInfo("Asia/Ho_Chi_Minh"),
    )

    await worker.run_once(now)
    await worker.run_once(now.replace(second=40))

    executor.assert_awaited_once()


@pytest.mark.asyncio
async def test_worker_skips_disabled_schedule_rule(db_session_factory):
    from cloud.app.schedule_worker import ScheduleWorker

    async with db_session_factory() as session:
        session.add(
            Automation(
                id="schedule-disabled",
                name="Disabled weekday light",
                enabled=False,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger_type="schedule",
                schedule_cron="0 7 * * 1-5",
                trigger={"type": "schedule"},
                actions=[],
                sync_status="synced",
                last_run_status="never_run",
            )
        )
        await session.commit()

    executor = AsyncMock()
    worker = ScheduleWorker(db_session_factory, executor=executor)
    await worker.run_once(
        datetime(
            2026,
            6,
            15,
            7,
            0,
            5,
            tzinfo=ZoneInfo("Asia/Ho_Chi_Minh"),
        )
    )

    executor.assert_not_awaited()


@pytest.mark.asyncio
async def test_worker_passes_utc_naive_scheduled_for(db_session_factory):
    from cloud.app.schedule_worker import ScheduleWorker

    async with db_session_factory() as session:
        session.add(
            Automation(
                id="schedule-utc",
                name="UTC scheduled_for",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger_type="schedule",
                schedule_cron="0 7 * * *",
                trigger={"type": "schedule"},
                actions=[],
                sync_status="synced",
                last_run_status="never_run",
            )
        )
        await session.commit()

    executor = AsyncMock()
    worker = ScheduleWorker(db_session_factory, executor=executor)
    # 07:00 Asia/Ho_Chi_Minh == 00:00 UTC the same day. scheduled_for must be
    # the naive-UTC instant so _fmt_ts renders occurred_at back to 07:00 local.
    await worker.run_once(
        datetime(2026, 6, 15, 7, 0, 5, tzinfo=ZoneInfo("Asia/Ho_Chi_Minh"))
    )

    executor.assert_awaited_once()
    scheduled_for = executor.await_args.kwargs["scheduled_for"]
    assert scheduled_for == datetime(2026, 6, 15, 0, 0)
    assert scheduled_for.tzinfo is None


@pytest.mark.asyncio
async def test_worker_survives_executor_error_and_runs_other_rules(
    db_session_factory,
):
    from cloud.app.schedule_worker import ScheduleWorker

    async with db_session_factory() as session:
        for rid in ("bad-rule", "good-rule"):
            session.add(
                Automation(
                    id=rid,
                    name=rid,
                    enabled=True,
                    tenant_id="hust",
                    site_id="lab01",
                    gateway_id="gw-ubuntu-01",
                    trigger_type="schedule",
                    schedule_cron="0 7 * * *",
                    trigger={"type": "schedule"},
                    actions=[],
                    sync_status="synced",
                    last_run_status="never_run",
                )
            )
        await session.commit()

    calls: list[str] = []

    async def flaky_executor(db, rule, *, scheduled_for):
        calls.append(rule.id)
        if rule.id == "bad-rule":
            raise RuntimeError("boom")

    worker = ScheduleWorker(db_session_factory, executor=flaky_executor)
    now = datetime(2026, 6, 15, 7, 0, 5, tzinfo=ZoneInfo("Asia/Ho_Chi_Minh"))

    # Must NOT raise, even though one rule's executor raises.
    await worker.run_once(now)

    assert set(calls) == {"bad-rule", "good-rule"}
