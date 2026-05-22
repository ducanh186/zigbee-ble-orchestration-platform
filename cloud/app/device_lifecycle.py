"""Background bookkeeping for device online/offline state.

Cloud MQTT handlers bump ``Device.last_seen_at`` on every reported/event/
registry message. This module owns the inverse direction: when no message
has arrived in a configurable window, the device is marked
``is_online=False`` so the dashboard / mobile app reflect reality.

A device that has never reported (``last_seen_at IS NULL``) is also marked
offline. This collapses two confusing dashboard states the audit found:

- Seed/probe rows (e.g. ``0xPROBE``) that were inserted manually and never
  receive MQTT traffic.
- Real hardware that was once online but has been silent for hours / days
  (e.g. the audited PIR ``0000000000000053``).
"""
from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import or_, select, update

from cloud.app.config import settings

logger = logging.getLogger(__name__)


def _utc_naive_now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


async def mark_stale_devices_offline(
    session_factory,
    threshold_seconds: int,
) -> int:
    """Flip ``is_online=False`` for devices that haven't reported recently.

    Returns the number of rows actually changed (i.e. previously ``True``).
    Idempotent: re-running with no new traffic is a no-op.
    """
    # Defer the model import so this module can be loaded before the DB
    # engine is initialized (e.g. when tests import lifespan helpers).
    from cloud.app.models import Device

    cutoff = _utc_naive_now() - timedelta(seconds=threshold_seconds)
    async with session_factory() as session:
        stmt = (
            update(Device)
            .where(
                Device.is_online.is_(True),
                or_(
                    Device.last_seen_at.is_(None),
                    Device.last_seen_at < cutoff,
                ),
            )
            .values(is_online=False)
        )
        result = await session.execute(stmt)
        await session.commit()
        changed = result.rowcount or 0
        if changed:
            logger.info(
                "Offline reaper: %d device(s) marked offline (cutoff=%s)",
                changed, cutoff,
            )
        return changed


async def run_offline_reaper(session_factory, stop_event: asyncio.Event) -> None:
    """Long-running task that periodically invokes the reaper.

    Hangs off the FastAPI lifespan. Interval and threshold come from
    ``settings.device_offline_*``.
    """
    interval = max(5, int(settings.device_offline_scan_interval_seconds))
    threshold = int(settings.device_offline_after_seconds)
    logger.info(
        "Offline reaper started: every %ss, threshold=%ss",
        interval, threshold,
    )
    while not stop_event.is_set():
        try:
            await mark_stale_devices_offline(session_factory, threshold)
        except Exception:
            logger.exception("Offline reaper iteration failed; continuing")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=interval)
            return
        except asyncio.TimeoutError:
            continue
