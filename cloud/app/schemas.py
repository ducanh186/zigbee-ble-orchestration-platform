from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


# ---------------------------------------------------------------------------
# Device-type specific validation (Phase 3.4)
# ---------------------------------------------------------------------------


class PowerState(str, Enum):
    on = "on"
    off = "off"


class LightReportedState(BaseModel):
    """Validates reported state payload for device_type=light.

    Per DEVICE_CAPABILITY_MATRIX.md v1: power, level, reachable are required.
    """

    power: PowerState
    level: int = Field(default=0, ge=0, le=254)
    reachable: bool


class SwitchReportedState(BaseModel):
    """Validates reported state payload for device_type=switch."""

    reachable: bool
    battery: int | None = Field(default=None, ge=0, le=100)


class LightReportedPayload(BaseModel):
    """Inner payload of a light reported MQTT message."""

    device_id: str
    device_type: Literal["light"]
    eui64: str | None = None
    nwk_addr: str | None = None
    state: LightReportedState


class SwitchEventPayload(BaseModel):
    """Inner payload of a switch event MQTT message.

    v1 only supports event='toggle'.
    """

    device_id: str
    device_type: Literal["switch"]
    event: Literal["toggle"]
    eui64: str | None = None
    nwk_addr: str | None = None


class LightCommandTarget(BaseModel):
    """Validates the target block of a command request aimed at a light.

    Per DEVICE_CAPABILITY_MATRIX: on, off, set_level via cluster 0x0006/0x0008.
    """

    endpoint: int = Field(ge=1, le=240)
    cluster_id: str  # "0x0006" or "0x0008"
    command: str  # "on", "off", "set_level"

    @model_validator(mode="after")
    def _validate_cluster_command(self):
        allowed = {
            "0x0006": {"on", "off"},
            "0x0008": {"set_level"},
        }
        cmds = allowed.get(self.cluster_id)
        if cmds is None:
            raise ValueError(
                f"cluster_id '{self.cluster_id}' not valid for light; "
                f"allowed: {sorted(allowed)}"
            )
        if self.command not in cmds:
            raise ValueError(
                f"command '{self.command}' not valid for cluster {self.cluster_id}; "
                f"allowed: {sorted(cmds)}"
            )
        return self


def validate_reported_payload(device_type: str, inner: dict) -> dict | None:
    """Validate an incoming reported payload by device_type.

    Returns validated dict on success, None on validation failure (logged upstream).
    """
    try:
        if device_type == "light":
            return LightReportedPayload(**inner).model_dump()
        # switch reported is optional but validate if state present
        if device_type == "switch" and "state" in inner:
            SwitchReportedState(**inner.get("state", {}))
        return inner
    except Exception:
        return None


def validate_event_payload(device_type: str, inner: dict) -> dict | None:
    """Validate an incoming event payload by device_type.

    Returns validated dict on success, None on validation failure (logged upstream).
    """
    try:
        if device_type == "switch":
            return SwitchEventPayload(**inner).model_dump()
        return inner
    except Exception:
        return None


# ---------------------------------------------------------------------------
# API response / request schemas (existing)
# ---------------------------------------------------------------------------


class DeviceOut(BaseModel):
    id: str
    device_type: str
    eui64: str | None
    room_id: str | None
    name: str | None
    is_online: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DeviceStateOut(BaseModel):
    id: int
    device_id: str
    state: dict[str, Any]
    reported_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CommandCreate(BaseModel):
    op: str
    target: dict[str, Any]
    timeout_ms: int | None = 5000


TERMINAL_STATUSES: frozenset[str] = frozenset({"executed", "failed", "timeout"})


class CommandOut(BaseModel):
    id: str
    device_id: str
    op: str
    target: dict[str, Any]
    status: str
    reason: str | None
    timeout_ms: int
    expires_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class EventOut(BaseModel):
    id: int
    device_id: str | None
    event_type: str
    payload: dict[str, Any]
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)


class HealthOut(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
