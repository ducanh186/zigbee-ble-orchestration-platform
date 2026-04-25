from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer, model_validator

TS_DISPLAY_FORMAT = "%H:%M %m/%d/%Y"


def _fmt_ts(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.strftime(TS_DISPLAY_FORMAT)


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


class UserFriendlyLightTarget(BaseModel):
    """Validates user-friendly light command targets like {"power": "on"}."""

    power: PowerState | None = None
    level: int | None = Field(default=None, ge=0, le=254)

    @model_validator(mode="after")
    def _at_least_one(self):
        if self.power is None and self.level is None:
            raise ValueError("target must include 'power' and/or 'level'")
        return self


# Default Zigbee endpoint for lights (standard for most Zigbee HA devices).
_DEFAULT_LIGHT_ENDPOINT = 1


def translate_command_for_gateway(
    device_type: str, op: str, target: dict[str, Any]
) -> tuple[str, dict[str, Any]]:
    """Translate a REST command into the gateway MQTT wire format.

    If *op* is already ``"device.command"`` the target is validated and passed
    through unchanged.  Any other *op* value is treated as user-friendly
    shorthand and translated into the ``device.command`` + ZCL target format
    that the gateway expects.

    Returns ``(op, target)`` ready for MQTT publication.
    Raises ``ValueError`` on invalid input.
    """
    # --- raw gateway format: validate and passthrough ---
    if op == "device.command":
        if device_type == "light":
            LightCommandTarget(**target)  # raises on bad input
        return op, target

    # --- user-friendly translation ---
    if device_type == "light":
        friendly = UserFriendlyLightTarget(**target)
        if friendly.power is not None:
            return "device.command", {
                "endpoint": _DEFAULT_LIGHT_ENDPOINT,
                "cluster_id": "0x0006",
                "command": friendly.power.value,
            }
        # level-only (cluster 0x0008)
        return "device.command", {
            "endpoint": _DEFAULT_LIGHT_ENDPOINT,
            "cluster_id": "0x0008",
            "command": "set_level",
            "level": friendly.level,
        }

    raise ValueError(
        f"device type '{device_type}' does not accept commands in v1"
    )


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

    @field_serializer("created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class DeviceStateOut(BaseModel):
    id: int
    device_id: str
    state: dict[str, Any]
    reported_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("reported_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


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

    @field_serializer("expires_at", "created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class EventOut(BaseModel):
    id: int
    device_id: str | None
    event_type: str
    payload: dict[str, Any]
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("occurred_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class HealthOut(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
