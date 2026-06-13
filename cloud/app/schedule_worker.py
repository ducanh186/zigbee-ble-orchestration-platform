from __future__ import annotations

import asyncio
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from croniter import croniter
from sqlalchemy import select

from cloud.app.automation_execution import execute_automation_rule
from cloud.app.models import Automation

SCHEDULE_TIMEZONE = ZoneInfo("Asia/Ho_Chi_Minh")


def is_schedule_due(expression: str, local_minute: datetime) -> bool:
    slot = local_minute.replace(second=0, microsecond=0)
    return croniter.match(expression, slot)


class ScheduleWorker:
    def __init__(
        self,
        session_factory,
        *,
        executor=execute_automation_rule,
    ) -> None:
        self._session_factory = session_factory
        self._executor = executor
        self._last_slots: set[tuple[str, datetime]] = set()
        self.timezone = SCHEDULE_TIMEZONE

    async def run_once(self, now: datetime | None = None) -> None:
        local_now = (now or datetime.now(self.timezone)).astimezone(
            self.timezone
        )
        slot = local_now.replace(second=0, microsecond=0)
        cutoff = slot - timedelta(minutes=2)
        self._last_slots = {
            key for key in self._last_slots if key[1] >= cutoff
        }

        async with self._session_factory() as db:
            rules = (
                await db.execute(
                    select(Automation).where(
                        Automation.enabled.is_(True),
                        Automation.trigger_type == "schedule",
                    )
                )
            ).scalars().all()
            for rule in rules:
                key = (rule.id, slot)
                if key in self._last_slots:
                    continue
                if rule.schedule_cron and is_schedule_due(
                    rule.schedule_cron,
                    slot,
                ):
                    await self._executor(
                        db,
                        rule,
                        scheduled_for=slot.replace(tzinfo=None),
                    )
                    self._last_slots.add(key)

    async def run_forever(self, stop_event: asyncio.Event) -> None:
        while not stop_event.is_set():
            await self.run_once()
            now = datetime.now(self.timezone)
            delay = 60 - now.second - now.microsecond / 1_000_000
            try:
                await asyncio.wait_for(stop_event.wait(), timeout=delay)
            except asyncio.TimeoutError:
                pass


async def run_schedule_worker(session_factory, stop_event: asyncio.Event):
    await ScheduleWorker(session_factory).run_forever(stop_event)
