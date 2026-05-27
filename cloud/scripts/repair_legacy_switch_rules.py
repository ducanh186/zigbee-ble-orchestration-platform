"""Repair existing automation rows whose trigger.event is the legacy `"toggle"`.

Background:
- Mobile builds prior to 2026-05-21 emitted `trigger.event = "toggle"` for
  switch templates.
- Cloud accepted the legacy value, persisted it as-is, and forwarded it to
  the gateway. Gateway rejected with `last_error="unsupported_trigger"`.
- This script finds those rows, rewrites the trigger to canonical
  `"switch_toggle"`, bumps `version`, marks `sync_status="pending"`, and
  publishes a fresh retained `automations/{id}/desired` so the gateway can
  re-sync without app interaction.

Idempotent: rows already at canonical `"switch_toggle"` are skipped.

Usage (local dev with SB_DATABASE_URL pointing at the cloud DB):

    .venv/bin/python -m cloud.scripts.repair_legacy_switch_rules            # dry-run
    .venv/bin/python -m cloud.scripts.repair_legacy_switch_rules --apply    # mutate

Add `--no-publish` to skip the MQTT re-publish (DB-only repair).
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from datetime import UTC, datetime

from sqlalchemy import select

from cloud.app.database import async_session
from cloud.app.models import Automation

logger = logging.getLogger("repair_legacy_switch_rules")


def _is_legacy(rule: Automation) -> bool:
    trigger = rule.trigger or {}
    return (
        trigger.get("device_type") == "switch"
        and trigger.get("event") == "toggle"
    )


async def _repair(apply: bool, publish: bool) -> int:
    async with async_session() as session:
        result = await session.execute(select(Automation))
        rules = result.scalars().all()

    legacy = [r for r in rules if _is_legacy(r)]
    logger.info(
        "Scan complete: total=%d legacy=%d", len(rules), len(legacy),
    )

    if not legacy:
        return 0

    for rule in legacy:
        logger.info(
            "  legacy id=%s name=%r version=%s sync=%s last_error=%s",
            rule.id, rule.name, rule.version,
            rule.sync_status, rule.last_error,
        )

    if not apply:
        logger.info("Dry-run mode (no --apply); not mutating DB.")
        return 0

    mqtt_service = None
    if publish:
        from cloud.app.mqtt_client import mqtt_service as svc
        mqtt_service = svc
        try:
            mqtt_service.connect()
        except Exception:
            logger.exception("MQTT connect failed; aborting --apply to avoid drift")
            return 1

    try:
        async with async_session() as session:
            for stale in legacy:
                rule = await session.get(Automation, stale.id)
                if rule is None or not _is_legacy(rule):
                    continue
                new_trigger = dict(rule.trigger)
                new_trigger["event"] = "switch_toggle"
                rule.trigger = new_trigger
                rule.version = (rule.version or 0) + 1
                rule.sync_status = "pending"
                rule.last_error = None
                rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
                logger.info(
                    "Repaired id=%s -> trigger.event=switch_toggle, version=%s",
                    rule.id, rule.version,
                )
            await session.commit()

            if mqtt_service is not None:
                # Re-read so we publish committed state.
                refreshed = (await session.execute(select(Automation))).scalars().all()
                for rule in refreshed:
                    if rule.id not in {x.id for x in legacy}:
                        continue
                    mqtt_service.publish_automation_desired(
                        automation_id=rule.id,
                        op="upsert",
                        version=rule.version,
                        name=rule.name,
                        enabled=rule.enabled,
                        trigger=rule.trigger,
                        actions=rule.actions,
                    )
                    logger.info(
                        "Republished automations/%s/desired version=%s",
                        rule.id, rule.version,
                    )
    finally:
        if mqtt_service is not None:
            mqtt_service.disconnect()

    return 0


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--apply",
        action="store_true",
        help="Mutate the DB (default is dry-run).",
    )
    p.add_argument(
        "--no-publish",
        dest="publish",
        action="store_false",
        help="Skip MQTT re-publish when --apply is set.",
    )
    p.set_defaults(publish=True)
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    return asyncio.run(_repair(apply=args.apply, publish=args.publish))


if __name__ == "__main__":
    sys.exit(main())
