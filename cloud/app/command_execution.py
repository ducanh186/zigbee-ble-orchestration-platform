from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import ensure_device_manageable
from cloud.app.models import Command, Device, User
from cloud.app.mqtt_client import mqtt_service
from cloud.app.schemas import translate_command_for_gateway


class CommandExecutionError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


async def execute_device_command(
    db: AsyncSession,
    *,
    device_id: str,
    op: str,
    target: dict[str, Any],
    timeout_ms: int,
    current_user: User | None,
) -> Command:
    device = await db.get(Device, device_id)
    if device is None:
        raise CommandExecutionError(404, "Device not found")
    if current_user is not None:
        await ensure_device_manageable(db, device, current_user)

    try:
        mqtt_op, mqtt_target = translate_command_for_gateway(
            device.device_type,
            op,
            target,
        )
    except (ValueError, ValidationError) as exc:
        raise CommandExecutionError(422, str(exc)) from exc

    command_id = uuid4().hex
    command = Command(
        id=command_id,
        device_id=device_id,
        op=mqtt_op,
        target=mqtt_target,
        status="accepted",
        timeout_ms=timeout_ms,
        expires_at=datetime.now(UTC).replace(tzinfo=None)
        + timedelta(milliseconds=timeout_ms),
    )
    db.add(command)
    await db.commit()
    await db.refresh(command)

    mqtt_service.publish_command(
        command_id=command_id,
        device_id=device_id,
        op=mqtt_op,
        target=mqtt_target,
        timeout_ms=timeout_ms,
    )
    return command
