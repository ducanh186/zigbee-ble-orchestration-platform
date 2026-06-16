from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import (
    ensure_automation_visible,
    ensure_device_visible,
    filter_visible_automations,
)
from cloud.app.auth import get_current_user, require_parent_or_admin
from cloud.app.automation_sync import mark_sync_pending
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.mqtt_client import mqtt_service
from cloud.app.models import Automation, AutomationEvent, Device, User
from cloud.app.schemas import AutomationCreate, AutomationOut, AutomationUpdate

router = APIRouter(prefix="/api/automations", tags=["automations"])


# ---- MVP caps (see docs/AUTOMATION_MQTT_CONTRACT.md §11) ----
MAX_AUTOMATIONS_PER_GATEWAY = 16
MAX_ACTIONS_PER_AUTOMATION = 4


def _publish_upsert(rule: Automation) -> None:
    """Publish retained desired upsert for an Automation row.

    Called after commit so the published payload matches DB state.
    """
    if not _syncs_to_gateway(rule):
        return
    mqtt_service.publish_automation_desired(
        automation_id=rule.id,
        op="upsert",
        version=rule.version,
        name=rule.name,
        enabled=rule.enabled,
        trigger=rule.trigger,
        actions=rule.actions,
    )


def _publish_delete(rule: Automation) -> None:
    """Publish retained desired tombstone for an Automation row."""
    mqtt_service.publish_automation_desired(
        automation_id=rule.id,
        op="delete",
        version=rule.version,
    )


def _syncs_to_gateway(rule: Automation) -> bool:
    """Only event rules are pushed to the gateway. Schedule rules execute
    entirely cloud-side (the gateway has no cron), so they are never synced."""
    return rule.trigger_type == "event"


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
    current_user: User,
) -> Device:
    device = await db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=422, detail=f"{role} device not found")
    if device.device_type != expected_type:
        raise HTTPException(
            status_code=422,
            detail=f"{role} device must be a {expected_type} device",
        )
    await ensure_device_visible(db, device, current_user)
    return device


def _normalize_trigger_event(trigger_device_type: str, event: str) -> str:
    """Map an inbound trigger event to its canonical wire value.

    The canonical names are defined in docs/AUTOMATION_MQTT_CONTRACT.md §4.3
    and enforced strictly by the gateway (`automation_rule.c`). Older mobile
    builds still emit the legacy `"toggle"` for switch triggers; we accept
    it once at the API boundary and rewrite it to `"switch_toggle"` so the
    value persisted in DB and published on `automations/{id}/desired` is
    always canonical. Without this, gateway publishes
    `last_error="unsupported_trigger"`.
    """
    if trigger_device_type == "switch":
        if event in {"switch_toggle", "toggle"}:
            return "switch_toggle"
        raise HTTPException(
            status_code=422, detail="Switch trigger must be switch_toggle"
        )
    # "sensor" is the device-model-v2 type for occupancy (kind 1); "motion" is
    # the legacy type kept for rules created before the migration. Both fire on
    # occupancy_changed.
    if trigger_device_type in {"motion", "sensor"}:
        if event == "occupancy_changed":
            return event
        raise HTTPException(
            status_code=422, detail="Motion trigger must use occupancy_changed"
        )
    raise HTTPException(status_code=422, detail="Unsupported trigger device_type")


async def _validate_rule_template(
    db: AsyncSession,
    trigger: dict[str, Any],
    actions: list[dict[str, Any]],
    current_user: User,
) -> None:
    if len(actions) > MAX_ACTIONS_PER_AUTOMATION:
        raise HTTPException(
            status_code=422,
            detail=(
                f"actions exceed MVP cap of {MAX_ACTIONS_PER_AUTOMATION} per automation"
            ),
        )
    trigger_type = trigger.get("type", "device_event")
    trigger_device_type: str | None = None
    event: str | None = None

    if trigger_type == "schedule":
        # Schedule triggers fire on a cron expression, not a device event, so
        # there is no trigger device or event to validate.
        pass
    else:
        trigger_device_id = _require_string(trigger, "device_id")
        trigger_device_type = _require_string(trigger, "device_type")

        if trigger_type == "sensor_threshold":
            # "sensor" (kind 2) is the v2 type; "environment" kept for legacy.
            if trigger_device_type not in {"environment", "sensor"}:
                raise HTTPException(
                    status_code=422,
                    detail="Sensor threshold trigger device_type must be environment or sensor",
                )
        elif trigger_type == "device_event":
            event = _require_string(trigger, "event")
            # "sensor" (kind 1 occupancy) is the v2 type; "motion" kept for legacy.
            if trigger_device_type not in {"switch", "motion", "sensor"}:
                raise HTTPException(
                    status_code=422,
                    detail="Unsupported trigger device_type",
                )
        else:
            raise HTTPException(status_code=422, detail="Unsupported trigger type")

        # _require_device matches the live DB row's device_type exactly. This is
        # by design under the device-model-v2 hard cutover: once the migration
        # has run, every sensor row is device_type="sensor", so a NEW rule must
        # use "sensor" (a stale client still sending "motion"/"environment" is
        # correctly rejected here). Legacy literals stay accepted upstream only
        # to keep the deploy window safe (code ships before the migration runs).
        # During that window the inverse can happen: a "sensor" trigger against a
        # not-yet-migrated "environment"/"motion" row returns a transient 422
        # here — expected until `alembic upgrade` completes, not a regression.
        await _require_device(
            db,
            trigger_device_id,
            trigger_device_type,
            "Trigger",
            current_user,
        )

    if trigger_type == "device_event":
        # Normalize event in-place so the caller's `trigger` dict — which is what
        # gets persisted to DB and published on MQTT — carries the canonical value.
        trigger["event"] = _normalize_trigger_event(trigger_device_type, event)
        event = trigger["event"]

    action_commands: list[str] = []
    for action in actions:
        action_type = action.get("type", "device_command")
        if action_type == "scene_activate":
            if trigger_type != "schedule":
                raise HTTPException(
                    status_code=422,
                    detail="Scene actions require a schedule trigger",
                )
            _require_string(action, "group_id")
            _require_string(action, "scene_id")
            continue

        action_device_id = _require_string(action, "device_id")
        action_device_type = _require_string(action, "device_type")
        command = _require_string(action, "command")
        if action_device_type != "light":
            raise HTTPException(status_code=422, detail="Action device_type must be light")
        if command not in {"on", "off", "toggle"}:
            raise HTTPException(status_code=422, detail="Unsupported light action command")
        await _require_device(db, action_device_id, "light", "Action", current_user)
        action_commands.append(command)

    if trigger_type in {"schedule", "sensor_threshold"}:
        return

    if trigger_device_type == "switch":
        # Event was already normalized to "switch_toggle" by
        # _normalize_trigger_event; reject any other value defensively here too.
        if event != "switch_toggle":
            raise HTTPException(
                status_code=422, detail="Switch trigger must be switch_toggle"
            )
        state = trigger.get("state") or {}
        if not isinstance(state, dict) or state:
            raise HTTPException(status_code=422, detail="Switch trigger state is unsupported")
        return

    if event != "occupancy_changed":
        raise HTTPException(status_code=422, detail="Motion trigger must use occupancy_changed")
    state = trigger.get("state")
    if not isinstance(state, dict):
        raise HTTPException(status_code=422, detail="Motion trigger state is required")
    occupancy = state.get("occupancy")
    if occupancy not in {"occupied", "unoccupied"}:
        raise HTTPException(status_code=422, detail="Unsupported motion occupancy state")


@router.get("", response_model=list[AutomationOut])
async def list_automations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Automation).order_by(Automation.created_at.asc()))
    rules = result.scalars().all()
    return await filter_visible_automations(db, list(rules), current_user)


@router.get("/{automation_id}", response_model=AutomationOut)
async def get_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    await ensure_automation_visible(db, rule, current_user)
    return rule


@router.post(
    "",
    response_model=AutomationOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_automation(
    body: AutomationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    await _validate_rule_template(db, body.trigger, body.actions, current_user)
    # MVP cap: contract §11.
    enabled_count = await db.execute(
        select(Automation).where(
            Automation.tenant_id == settings.tenant_id,
            Automation.site_id == settings.site_id,
            Automation.gateway_id == settings.gateway_id,
        )
    )
    if len(enabled_count.scalars().all()) >= MAX_AUTOMATIONS_PER_GATEWAY:
        raise HTTPException(
            status_code=409,
            detail=(
                f"automation count would exceed MVP cap of "
                f"{MAX_AUTOMATIONS_PER_GATEWAY} per gateway"
            ),
        )
    rule = Automation(
        id=f"auto_{uuid4().hex[:12]}",
        name=body.name,
        enabled=body.enabled,
        tenant_id=settings.tenant_id,
        site_id=settings.site_id,
        gateway_id=settings.gateway_id,
        version=1,
        trigger_type=body.trigger_type,
        schedule_cron=body.schedule_cron,
        trigger=body.trigger,
        actions=body.actions,
        sync_status="pending",
        last_run_status="never_run",
        last_error=None,
    )
    if _syncs_to_gateway(rule):
        mark_sync_pending(rule, "automation.upsert")
    else:
        rule.sync_status = "synced"
        rule.last_error = None
    db.add(rule)
    await db.commit()
    await db.refresh(rule)
    if _syncs_to_gateway(rule):
        _publish_upsert(rule)
    return rule


async def _set_enabled(
    automation_id: str,
    enabled: bool,
    db: AsyncSession,
    current_user: User,
) -> Automation:
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    await ensure_automation_visible(db, rule, current_user)
    rule.enabled = enabled
    rule.version = (rule.version or 0) + 1
    rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
    if _syncs_to_gateway(rule):
        mark_sync_pending(
            rule, "automation.enable" if enabled else "automation.disable"
        )
    else:
        rule.sync_status = "synced"
        rule.last_error = None
    await db.commit()
    await db.refresh(rule)
    if _syncs_to_gateway(rule):
        _publish_upsert(rule)
    return rule


@router.post("/{automation_id}/enable", response_model=AutomationOut)
async def enable_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    return await _set_enabled(automation_id, True, db, current_user)


@router.post("/{automation_id}/disable", response_model=AutomationOut)
async def disable_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    return await _set_enabled(automation_id, False, db, current_user)


@router.put("/{automation_id}", response_model=AutomationOut)
async def update_automation(
    automation_id: str,
    body: AutomationUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    await ensure_automation_visible(db, rule, current_user)
    if body.version is not None and body.version != rule.version:
        raise HTTPException(status_code=409, detail="Automation version conflict")

    was_syncing = _syncs_to_gateway(rule)

    # If trigger or actions change, re-validate the resulting rule body. We
    # validate against the *merged* values so partial updates still get the
    # same template guardrails as create.
    merged = AutomationCreate(
        name=body.name if body.name is not None else rule.name,
        enabled=body.enabled if body.enabled is not None else rule.enabled,
        trigger_type=(
            body.trigger_type
            if body.trigger_type is not None
            else rule.trigger_type
        ),
        schedule_cron=(
            body.schedule_cron
            if "schedule_cron" in body.model_fields_set
            else rule.schedule_cron
        ),
        trigger=body.trigger if body.trigger is not None else rule.trigger,
        actions=body.actions if body.actions is not None else rule.actions,
    )
    await _validate_rule_template(
        db,
        merged.trigger,
        merged.actions,
        current_user,
    )

    if body.name is not None:
        rule.name = body.name
    if body.enabled is not None:
        rule.enabled = body.enabled
    if body.trigger_type is not None:
        rule.trigger_type = merged.trigger_type
    if "schedule_cron" in body.model_fields_set:
        rule.schedule_cron = merged.schedule_cron
    if body.trigger is not None:
        rule.trigger = merged.trigger
    if body.actions is not None:
        rule.actions = merged.actions

    rule.version = (rule.version or 0) + 1
    rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
    if _syncs_to_gateway(rule):
        mark_sync_pending(rule, "automation.update")
    else:
        rule.sync_status = "synced"
        rule.last_error = None
    await db.commit()
    await db.refresh(rule)
    if _syncs_to_gateway(rule):
        _publish_upsert(rule)
    elif was_syncing:
        # Converted event -> schedule: clear the stale retained desired so the
        # gateway stops executing the old event rule (cloud now owns execution).
        _publish_delete(rule)
    return rule


@router.delete("/{automation_id}", response_model=AutomationOut)
async def delete_automation(
    automation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    """Delete an automation; removed immediately, never waits on the gateway.

    Deleting is fully cloud-side and deterministic — the DB row (and its child
    automation_events) is hard-deleted right away, so the app sees it gone and
    delete never hangs on a gateway ack (the original "rule won't delete" bug).
    Event rules — the only ones the gateway knows about — additionally get a
    retained op=delete tombstone so the gateway drops them on its next sync,
    using the mechanism it already has (no firmware change). Schedule rules run
    cloud-side and are never synced, so they need no tombstone.
    """
    rule = await db.get(Automation, automation_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    await ensure_automation_visible(db, rule, current_user)

    # Tell the gateway to drop it — only event rules are synced there.
    if _syncs_to_gateway(rule):
        rule.version = (rule.version or 0) + 1
        rule.updated_at = datetime.now(UTC).replace(tzinfo=None)
        _publish_delete(rule)

    # Snapshot the response before the row is gone (expire_on_commit=False keeps
    # the instance readable, but a snapshot is explicit and safe).
    response = AutomationOut.model_validate(rule)

    # Hard-delete now regardless of any gateway ack. Remove FK-referencing audit
    # rows first (no ON DELETE cascade on automation_events.automation_id).
    await db.execute(
        delete(AutomationEvent).where(
            AutomationEvent.automation_id == automation_id
        )
    )
    await db.delete(rule)
    await db.commit()
    return response
