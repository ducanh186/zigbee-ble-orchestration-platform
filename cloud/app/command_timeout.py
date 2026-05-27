"""Background worker that auto-times out stale commands.

Runs as an asyncio task started by FastAPI lifespan. Every SCAN_INTERVAL_SEC
it finds commands whose status is still non-terminal past `expires_at` and
marks them `status='timeout'`.
"""
from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime

from sqlalchemy import select, update

from cloud.app.models import Command, ProvisioningSession
from cloud.app.schemas import TERMINAL_STATUSES

logger = logging.getLogger(__name__)

SCAN_INTERVAL_SEC = 1.0
PROVISIONING_TERMINAL_STATUSES = {"joined", "failed", "expired", "cancelled"}


async def sweep_once(session_factory) -> int:
    """Mark expired non-terminal commands as timeout. Returns count affected."""
    now = datetime.now(UTC).replace(tzinfo=None)
    async with session_factory() as session:
        stmt = select(Command).where(
            Command.status.notin_(list(TERMINAL_STATUSES)),
            Command.expires_at.is_not(None),
            Command.expires_at < now,
        )
        result = await session.execute(stmt)
        expired = result.scalars().all()
        if not expired:
            return 0
        ids = [c.id for c in expired]
        reason = "cloud-side timeout expired"
        await session.execute(
            update(Command)
            .where(Command.id.in_(ids))
            .values(status="timeout", reason=reason)
        )
        await session.execute(
            update(ProvisioningSession)
            .where(
                ProvisioningSession.command_id.in_(ids),
                ProvisioningSession.status.notin_(
                    list(PROVISIONING_TERMINAL_STATUSES)
                ),
            )
            .values(status="failed", reason=reason)
        )
        await session.commit()
        for c in expired:
            logger.warning("Command %s timed out (device=%s)", c.id, c.device_id)
        return len(ids)


async def run_timeout_worker(session_factory, stop_event: asyncio.Event) -> None:
    """Long-running loop; exits when stop_event is set."""
    logger.info("Command timeout worker started (interval=%.1fs)", SCAN_INTERVAL_SEC)
    while not stop_event.is_set():
        try:
            await sweep_once(session_factory)
        except Exception:
            logger.exception("sweep_once failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=SCAN_INTERVAL_SEC)
        except asyncio.TimeoutError:
            pass
    logger.info("Command timeout worker stopped")
