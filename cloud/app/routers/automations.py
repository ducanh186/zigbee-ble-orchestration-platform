from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.automation_sync import mark_sync_pending
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import Automation, Device
from cloud.app.schemas import AutomationCreate, AutomationOut, AutomationUpdate

router = APIRouter(prefix="/api/automations", tags=["automations"])


def _require_string(payload: dict[str, Any], field: str) -> str:
    value = payload.get(field)
    if not isinstance(value, str) or not value:
        raise HTTPException(status_code=422, detail=f"{field} is required")
    return value


async def _require_device(
    db: AsyncSession,
    device_id: str,
    expected_type: str,
    role: str,
) -> Device:
    device = await db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=422, detail=f"{role} device not found")
    if device.device_type != expected_type:
        raise HTTPException(
            status_code=422,
            detail=f"{role} device must be a {expected_type} device",
        )
    return device


async def _validate_rule_template(
    db: AsyncSession,
    trigger: dict[str, Any],
    actions: list[dict[str, Any]],
) -> None:
    trigger_device_id = _require_string(trigger, "device_id")
    trigger_device_type = _require_string(trigger, "device_type")
    event = _require_string(trigger, "event")

    if trigger_device_type not in {"switch", "motion"}:
        raise HTTPException(status_code=422, detail="Unsupported trigger device_type")

    await _require_device(db, trigger_device_id, trigger_device_type, "Trigger")

    action_commands: list[str] = []
    for action in actions:
        action_device_id = _require_string(action, "device_id")
        action_device_type = _require_string(action, "device_type")
        command = _require_string(action, "command")
        if action_device_type != "light":
            raise HTTPException(status_code=422, detail="Action device_type must be light")
        if command not in {"on", "off", "toggle"}:
            raise HTTPException(status_code=422, detail="Unsupported light action command")
        await _require_device(db, action_device_id, "light", "Action")
        action_commands.append(command)

    if trigger_device_type == "switch":
        if event not in {"switch_toggle", "toggle"}:
            raise HTTPException(status_code=422, detail="Switch trigger must be toggle")
        state = trigger.get("state") or {}
        if not isinstance(state, dict) or state:
            raise HTTPException(status_code=422, detail="Switch trigger state is unsupported")
        if any(command != "toggle" for command in action_commands):
            raise HTTPException(
                status_code=422,
                detail="Switch toggle rules can only toggle light actions",
            )
        return

    if event != "occupancy_changed":
        raise HTTPException(status_code=422, detail="Motion trigger must use occupancy_changed")
    state = trigger.get("state")
    if not isinstance(state, dict):
        raise HTTPException(status_code=422, detail="Motion trigger state is required")
    occupancy = state.get("occupancy")
    if occupancy == "occupied":
        expected_command = "on"
    elif occupancy == "unoccupied":
        expected_command = "off"
    else:
        raise HTTPException(status_code=422, detail="Unsupported motion occupancy state")
    if any(command != expected_command for command in action_commands):
        raise HTTPException(
            status_code=422,
            detail=f"Motion {occupancy} rules can only use light {expected_command}",
        )


@router.get("", response_model=list[AutomationOut])
async def list_automations(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Automation).order_by(Automation.created_at.asc()))
    return result.scalars().all()


@router.get("/{automation_id}", response_model=AutomationOut)
async def get_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
):
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    return rule


@router.post(
    "",
    response_model=AutomationOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_automation(
    body: AutomationCreate,
    db: AsyncSession = Depends(get_db),
):
    await _validate_rule_template(db, body.trigger, body.actions)
    rule = Automation(
        id=uuid4().hex,
        name=body.name,
        enabled=body.enabled,
        tenant_id=settings.tenant_id,
        site_id=settings.site_id,
        gateway_id=settings.gateway_id,
        version=1,
        trigger=body.trigger,
        actions=body.actions,
        sync_status="pending",
        last_run_status="never_run",
        last_error=None,
    )
    mark_sync_pending(rule, "automation.upsert")
    db.add(rule)
    await db.commit()
    await db.refresh(rule)
    return rule


@router.put("/{automation_id}", response_model=AutomationOut)
async def update_automation(
    automation_id: str,
    body: AutomationUpdate,
    db: AsyncSession = Depends(get_db),
):
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    if body.version != rule.version:
        raise HTTPException(status_code=409, detail="Automation version conflict")

    await _validate_rule_template(db, body.trigger, body.actions)
    rule.name = body.name
    rule.enabled = body.enabled
    rule.version += 1
    rule.trigger = body.trigger
    rule.actions = body.actions
    rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
    mark_sync_pending(rule, "automation.upsert")
    await db.commit()
    await db.refresh(rule)
    return rule


async def _set_enabled(
    automation_id: str,
    enabled: bool,
    db: AsyncSession,
) -> Automation:
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    rule.enabled = enabled
    rule.version += 1
    rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
    mark_sync_pending(rule, "automation.enable" if enabled else "automation.disable")
    await db.commit()
    await db.refresh(rule)
    return rule


@router.post("/{automation_id}/enable", response_model=AutomationOut)
async def enable_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
):
    return await _set_enabled(automation_id, True, db)


@router.post("/{automation_id}/disable", response_model=AutomationOut)
async def disable_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
):
    return await _set_enabled(automation_id, False, db)


@router.delete("/{automation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
):
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    await db.delete(rule)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
