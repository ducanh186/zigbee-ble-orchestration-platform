from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.command_execution import (
    CommandExecutionError,
    execute_device_command,
)
from cloud.app.models import Automation, AutomationEvent


async def execute_automation_rule(
    db: AsyncSession,
    rule: Automation,
    *,
    scheduled_for: datetime,
) -> list[AutomationEvent]:
    events: list[AutomationEvent] = []
    failed_reason: str | None = None

    for action_index, action in enumerate(rule.actions):
        command_id: str | None = None
        reason: str | None = None
        try:
            if action.get("type", "device_command") != "device_command":
                raise CommandExecutionError(422, "unsupported_action")
            command = action.get("command")
            if command not in {"on", "off"}:
                raise CommandExecutionError(
                    422,
                    "scheduled actions support light on/off only",
                )
            created = await execute_device_command(
                db,
                device_id=action["device_id"],
                op="set",
                target={"power": command},
                timeout_ms=5000,
                current_user=None,
            )
            command_id = created.id
            event_type = "automation_executed"
            status = "executed"
        except (CommandExecutionError, KeyError) as exc:
            reason = (
                exc.detail
                if isinstance(exc, CommandExecutionError)
                else f"missing action field: {exc.args[0]}"
            )
            failed_reason = failed_reason or reason
            event_type = "automation_failed"
            status = "failed"

        event = AutomationEvent(
            automation_id=rule.id,
            event_type=event_type,
            status=status,
            reason=reason,
            payload={
                "scheduled_for": scheduled_for.isoformat(),
                "action_index": action_index,
                "command_id": command_id,
                "action": action,
            },
            occurred_at=scheduled_for,
        )
        db.add(event)
        events.append(event)

    rule.last_run_status = "failed" if failed_reason else "executed"
    rule.last_error = failed_reason
    rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
    await db.commit()
    return events
