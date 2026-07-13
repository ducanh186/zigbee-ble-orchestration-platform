from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from croniter import croniter
from sqlalchemy import select

from cloud.app.automation_execution import execute_automation_rule
from cloud.app.models import Automation

logger = logging.getLogger(__name__)

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
                if not (
                    rule.schedule_cron
                    and is_schedule_due(rule.schedule_cron, slot)
                ):
                    continue
                try:
                    await self._executor(
                        db,
                        rule,
                        # Store naive-UTC to match the rest of the system
                        # (device/command/event timestamps are all naive-UTC,
                        # and _fmt_ts converts UTC->local for display). `slot`
                        # is local (HCM) tz-aware, so convert before dropping
                        # tzinfo — otherwise occurred_at displays +7h off.
                        scheduled_for=slot.astimezone(UTC).replace(tzinfo=None),
                    )
                    self._last_slots.add(key)
                except Exception:
                    # One bad rule must not sink the batch or bubble out of
                    # run_once. Key is NOT added, so it retries next tick.
                    logger.exception(
                        "schedule rule %s failed to execute", rule.id
                    )

    async def run_forever(self, stop_event: asyncio.Event) -> None:
        logger.info("Schedule worker started (tz=%s)", self.timezone)
        while not stop_event.is_set():
            try:
                await self.run_once()
            except Exception:
                logger.exception("schedule run_once failed")
            now = datetime.now(self.timezone)
            delay = 60 - now.second - now.microsecond / 1_000_000
            try:
                await asyncio.wait_for(stop_event.wait(), timeout=delay)
            except asyncio.TimeoutError:
                pass
        logger.info("Schedule worker stopped")


async def run_schedule_worker(session_factory, stop_event: asyncio.Event):
    await ScheduleWorker(session_factory).run_forever(stop_event)
