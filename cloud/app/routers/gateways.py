"""Gateway-targeted command routes (commissioning).

These commands are NOT bound to any device row; they target the gateway
itself.  We still persist them in the ``commands`` table (with
``device_id=NULL`` and ``target_kind='gateway'``) so the lifecycle, timeout
sweeper, and reply handler stay uniform.
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import get_manageable_device_or_404
from cloud.app.auth import require_admin, require_parent_or_admin
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import Command, User
from cloud.app.mqtt_client import mqtt_service
from cloud.app.schemas import (
    CommandOut,
    CommissioningCloseBody,
    CommissioningOpenBody,
)

router = APIRouter(prefix="/api/gateways", tags=["gateways"])


def _verify_gateway_id(gateway_id: str) -> None:
    """Reject mismatched gateway_id early; we only manage one gateway in v1."""
    if gateway_id != settings.gateway_id:
        raise HTTPException(
            status_code=404,
            detail=(
                f"unknown gateway_id '{gateway_id}'; "
                f"this cloud manages '{settings.gateway_id}'"
            ),
        )


def _insert_gateway_command(
    db: AsyncSession,
    op: str,
    target: dict,
    timeout_ms: int,
) -> Command:
    command_id = uuid4().hex
    expires_at = datetime.now(UTC).replace(tzinfo=None) + timedelta(
        milliseconds=timeout_ms
    )
    cmd = Command(
        id=command_id,
        device_id=None,
        target_kind="gateway",
        op=op,
        target=target,
        status="accepted",
        timeout_ms=timeout_ms,
        expires_at=expires_at,
    )
    db.add(cmd)
    return cmd


@router.post(
    "/{gateway_id}/commissioning/open",
    response_model=CommandOut,
    status_code=status.HTTP_201_CREATED,
)
async def commissioning_open(
    gateway_id: str,
    body: CommissioningOpenBody,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_admin),
):
    """Open the Zigbee network for joining (broadcast permit join).

    Cloud creates a Command, publishes ``op=gateway.open_network`` with
    ``target.duration_sec`` to the gateway, and returns immediately with
    ``status=accepted``.  Lifecycle progress arrives via MQTT replies.
    """
    _verify_gateway_id(gateway_id)

    timeout_ms = body.timeout_ms or 5000
    target = {"duration_sec": body.duration_sec}
    cmd = _insert_gateway_command(db, "gateway.open_network", target, timeout_ms)
    await db.commit()
    await db.refresh(cmd)

    mqtt_service.publish_gateway_command(
        command_id=cmd.id,
        op="gateway.open_network",
        target=target,
        timeout_ms=timeout_ms,
    )
    return cmd


@router.post(
    "/{gateway_id}/commissioning/close",
    response_model=CommandOut,
    status_code=status.HTTP_201_CREATED,
)
async def commissioning_close(
    gateway_id: str,
    body: CommissioningCloseBody,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_admin),
):
    """Close the Zigbee network (broadcast permit-join with duration=0)."""
    _verify_gateway_id(gateway_id)

    timeout_ms = body.timeout_ms or 5000
    target: dict = {}
    cmd = _insert_gateway_command(db, "gateway.close_network", target, timeout_ms)
    await db.commit()
    await db.refresh(cmd)

    mqtt_service.publish_gateway_command(
        command_id=cmd.id,
        op="gateway.close_network",
        target=target,
        timeout_ms=timeout_ms,
    )
    return cmd


# ---------------------------------------------------------------------------
# Per-device rediscovery (gateway.rediscover_device)
# ---------------------------------------------------------------------------
# Layer-2 on-demand classification: ask the gateway to ZDO-query a specific
# device by EUI64, regardless of whether it currently sits in the gateway's
# in-memory registry. Returns immediately after the gateway acknowledges; the
# actual classification result lands on the broker as a retained
# devices/{type}/{eui}/registry message a moment later, and the cloud's
# _handle_registry already persists it into the devices/events tables.

# Mounted under a separate router because the path is /api/devices/... not
# /api/gateways/...; FastAPI lets us register a second router from this same
# module so the related "commission + rediscover" set stays co-located.
devices_router = APIRouter(prefix="/api/devices", tags=["gateways"])


@devices_router.post(
    "/{device_id}/rediscover",
    response_model=CommandOut,
    status_code=status.HTTP_201_CREATED,
)
async def device_rediscover(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    """Trigger ZDO Simple Descriptor classification for `device_id`.

    No body required.  The gateway resolves the EUI64 to a current nodeId via
    its child table or stack address cache, then runs the same discovery flow
    used at join time.  Failure case (most common: device offline / not on
    network) returns ``status=failed reason=device_not_on_network`` on the
    command reply.
    """
    await get_manageable_device_or_404(db, device_id, current_user)

    timeout_ms = 5000
    command_id = uuid4().hex
    expires_at = datetime.now(UTC).replace(tzinfo=None) + timedelta(
        milliseconds=timeout_ms
    )
    cmd = Command(
        id=command_id,
        device_id=device_id,
        target_kind="device",
        op="gateway.rediscover_device",
        target={},
        status="accepted",
        timeout_ms=timeout_ms,
        expires_at=expires_at,
    )
    db.add(cmd)
    await db.commit()
    await db.refresh(cmd)

    mqtt_service.publish_command(
        command_id=command_id,
        device_id=device_id,
        op="gateway.rediscover_device",
        target={},
        timeout_ms=timeout_ms,
    )
    return cmd
