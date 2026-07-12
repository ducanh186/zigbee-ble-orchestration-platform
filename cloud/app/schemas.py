from __future__ import annotations

import re
from datetime import UTC, datetime
from enum import Enum
from typing import Annotated, Any, Literal
from zoneinfo import ZoneInfo

from croniter import croniter
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    TypeAdapter,
    field_serializer,
    field_validator,
    model_validator,
)

from cloud.app.provisioning_install_code import normalize_install_code

TS_DISPLAY_FORMAT = "%H:%M %m/%d/%Y"
DISPLAY_TIMEZONE = ZoneInfo("Asia/Ho_Chi_Minh")


def _fmt_ts(value: datetime | None) -> str | None:
    if value is None:
        return None
    aware = value.replace(tzinfo=UTC) if value.tzinfo is None else value
    return aware.astimezone(DISPLAY_TIMEZONE).strftime(TS_DISPLAY_FORMAT)


_HEX_RE = re.compile(r"^[0-9a-fA-F]+$")
_EUI64_RE = re.compile(r"^[0-9a-fA-F]{16}$")
_INSTALL_CODE_HEX_LENGTHS = {16, 20, 28, 36}


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


class EnvironmentReportedState(BaseModel):
    temperature_c: float | None = Field(default=None, ge=-20, le=80)
    humidity_percent: float | None = Field(default=None, ge=0, le=100)
    sensor: str | None = None
    reachable: bool

    @model_validator(mode="after")
    def require_measurement(self):
        if self.temperature_c is None and self.humidity_percent is None:
            raise ValueError(
                "environment state requires temperature_c or humidity_percent"
            )
        return self


class EnvironmentReportedPayload(BaseModel):
    device_id: str
    device_type: Literal["environment"]
    eui64: str | None = None
    nwk_addr: str | None = None
    state: EnvironmentReportedState


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

    # --- room assignment: valid for any device type ---
    if op == "device.set_room":
        room_id = target.get("room_id")
        if not room_id:
            raise ValueError("device.set_room requires a non-empty 'room_id' in target")
        return "device.set_room", {"room_id": room_id}

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
        if device_type == "environment":
            return EnvironmentReportedPayload(**inner).model_dump(
                exclude_none=True
            )
        # switch reported is optional but validate if state present
        if device_type == "switch" and "state" in inner:
            SwitchReportedState(**inner.get("state", {}))
        if device_type == "sensor" and inner.get("sensor_kind") == 2:
            if "state" not in inner:
                return None  # malformed kind-2 sensor report: state is required
            # Validate temp/humi ranges only; sensor v2 omits `reachable`, inject True
            # for the model. `inner` is returned unchanged — reachable extraction in
            # _handle_reported defaults to True when absent. (I1 clarification.)
            EnvironmentReportedState(**{**inner["state"], "reachable": True})
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
        # motion/sensor events (incl. kind-1 occupancy reserved) have no
        # kind-specific validation yet and pass through unchanged.
        return inner
    except Exception:
        return None


# ---------------------------------------------------------------------------
# API response / request schemas (existing)
# ---------------------------------------------------------------------------


class DeviceOut(BaseModel):
    id: str
    device_type: str
    sensor_kind: int | None = None
    eui64: str | None
    room_id: str | None
    name: str | None
    is_online: bool
    # Latest reported state inlined by `list_devices` so the app needs one
    # round-trip instead of an N+1 fan-out to /devices/{id}/state. Null when the
    # device has never reported.
    state: dict | None = None
    reported_at: datetime | None = None
    last_seen_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("reported_at", "last_seen_at", "created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class DeviceUpdate(BaseModel):
    # Both fields optional so a caller can rename, move room, or both. A
    # room-only move must not be forced to re-send the current name.
    name: str | None = Field(default=None, min_length=1, max_length=120)
    room_id: str | None = None

    @model_validator(mode="after")
    def _require_one_field(self):
        if self.name is None and self.room_id is None:
            raise ValueError("DeviceUpdate requires at least one of: name, room_id")
        return self


class RoomOut(BaseModel):
    id: str
    name: str

    model_config = ConfigDict(from_attributes=True)


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class RoomUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class AuthLogin(BaseModel):
    username: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=1)


class AuthChangePassword(BaseModel):
    old_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=256)


class AuthRefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class AuthLogout(BaseModel):
    refresh_token: str | None = Field(default=None, min_length=1)


class AuthUserOut(BaseModel):
    username: str
    user_id: str
    display_name: str | None = None
    role: Literal["admin", "parent", "viewer"]
    home_id: str | None = None
    must_change_password: bool


class AuthSessionOut(BaseModel):
    access_token: str
    refresh_token: str
    username: str
    user_id: str
    display_name: str | None = None
    role: Literal["admin", "parent", "viewer"]
    home_id: str | None = None
    must_change_password: bool
    expires_at: datetime
    refresh_expires_at: datetime

    @field_serializer("expires_at", "refresh_expires_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return v.isoformat() if v is not None else None


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
    device_id: str | None
    target_kind: str
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


class GatewayStatusOut(BaseModel):
    gateway_id: str
    status: Literal["online", "offline", "unknown"]
    event_type: str | None = None
    occurred_at: datetime | None = None

    @field_serializer("occurred_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


# ---------------------------------------------------------------------------
# Automation rules
# ---------------------------------------------------------------------------


class DeviceEventTrigger(BaseModel):
    type: Literal["device_event"] = "device_event"
    device_id: str = Field(min_length=1)
    # "sensor" is the v2 type (occupancy = sensor kind 1); "motion" kept for
    # legacy rules created/cached before the device-model-v2 migration.
    device_type: Literal["sensor", "motion", "switch"]
    event: Literal["occupancy_changed", "switch_toggle", "toggle"]
    state: dict[str, Any] = Field(default_factory=dict)


class SensorThresholdTrigger(BaseModel):
    type: Literal["sensor_threshold"]
    device_id: str = Field(min_length=1)
    # "sensor" is the v2 type (environment = sensor kind 2); "environment" kept
    # for legacy rules created/cached before the device-model-v2 migration.
    device_type: Literal["sensor", "environment"]
    metric: Literal["temperature_c", "humidity_percent"]
    operator: Literal["gte", "lte"]
    threshold: float

    @model_validator(mode="after")
    def validate_threshold_range(self):
        minimum, maximum = (
            (-20.0, 80.0)
            if self.metric == "temperature_c"
            else (0.0, 100.0)
        )
        if not minimum <= self.threshold <= maximum:
            raise ValueError(
                f"{self.metric} threshold must be between "
                f"{minimum:g} and {maximum:g}"
            )
        return self


class ScheduleTrigger(BaseModel):
    type: Literal["schedule"]


AutomationTrigger = Annotated[
    DeviceEventTrigger | SensorThresholdTrigger | ScheduleTrigger,
    Field(discriminator="type"),
]


class DeviceCommandAction(BaseModel):
    type: Literal["device_command"] = "device_command"
    device_id: str = Field(min_length=1)
    device_type: str = Field(min_length=1)
    command: Literal["on", "off", "toggle"]


class SceneActivateAction(BaseModel):
    type: Literal["scene_activate"]
    group_id: str = Field(min_length=1)
    scene_id: str = Field(min_length=1)


AutomationAction = Annotated[
    DeviceCommandAction | SceneActivateAction,
    Field(discriminator="type"),
]

_AUTOMATION_TRIGGER_ADAPTER = TypeAdapter(AutomationTrigger)
_AUTOMATION_ACTION_ADAPTER = TypeAdapter(AutomationAction)


def _validated_trigger(value: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(value)
    normalized.setdefault("type", "device_event")
    return _AUTOMATION_TRIGGER_ADAPTER.validate_python(normalized).model_dump()


def _validated_actions(
    values: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    normalized_actions = []
    for value in values:
        normalized = dict(value)
        normalized.setdefault("type", "device_command")
        normalized_actions.append(
            _AUTOMATION_ACTION_ADAPTER.validate_python(normalized).model_dump()
        )
    return normalized_actions


def validate_five_field_cron(value: str) -> str:
    normalized = value.strip()
    if len(normalized.split()) != 5 or not croniter.is_valid(normalized):
        raise ValueError(
            "schedule_cron must be a valid five-field cron expression"
        )
    return normalized


class AutomationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    enabled: bool = True
    trigger_type: Literal["event", "schedule"] = "event"
    schedule_cron: str | None = None
    trigger: dict[str, Any]
    actions: list[dict[str, Any]] = Field(min_length=1)

    @field_validator("trigger")
    @classmethod
    def validate_trigger(cls, value: dict[str, Any]) -> dict[str, Any]:
        return _validated_trigger(value)

    @field_validator("actions")
    @classmethod
    def validate_actions(
        cls,
        values: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        return _validated_actions(values)

    @model_validator(mode="after")
    def validate_trigger_contract(self):
        trigger_kind = self.trigger.get("type")
        if self.trigger_type == "schedule":
            if trigger_kind != "schedule":
                raise ValueError(
                    "schedule trigger_type requires trigger.type=schedule"
                )
            if self.schedule_cron is None:
                raise ValueError(
                    "schedule trigger_type requires schedule_cron"
                )
            self.schedule_cron = validate_five_field_cron(self.schedule_cron)
        else:
            if trigger_kind == "schedule":
                raise ValueError(
                    "event trigger_type cannot use trigger.type=schedule"
                )
            if self.schedule_cron is not None:
                raise ValueError(
                    "event trigger_type requires schedule_cron=null"
                )
        return self


class AutomationUpdate(BaseModel):
    """PUT body. All fields optional; only provided fields are mutated."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    enabled: bool | None = None
    version: int | None = Field(default=None, ge=1)
    trigger_type: Literal["event", "schedule"] | None = None
    schedule_cron: str | None = None
    trigger: dict[str, Any] | None = None
    actions: list[dict[str, Any]] | None = Field(default=None, min_length=1)

    @field_validator("trigger")
    @classmethod
    def validate_trigger(
        cls,
        value: dict[str, Any] | None,
    ) -> dict[str, Any] | None:
        return None if value is None else _validated_trigger(value)

    @field_validator("actions")
    @classmethod
    def validate_actions(
        cls,
        values: list[dict[str, Any]] | None,
    ) -> list[dict[str, Any]] | None:
        return None if values is None else _validated_actions(values)


class AutomationOut(BaseModel):
    id: str
    name: str
    enabled: bool
    tenant_id: str
    site_id: str
    gateway_id: str
    version: int
    trigger_type: Literal["event", "schedule"]
    schedule_cron: str | None
    trigger: dict[str, Any]
    actions: list[dict[str, Any]]
    sync_status: Literal["pending", "synced", "failed", "deleted"]
    last_run_status: Literal["never_run", "executed", "failed", "timeout"]
    last_error: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class AutomationEventOut(BaseModel):
    id: int
    automation_id: str | None
    event_type: str
    status: str | None
    reason: str | None
    payload: dict[str, Any]
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("occurred_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


# ---------------------------------------------------------------------------
# Provisioning sessions (secure install-code join)
# ---------------------------------------------------------------------------


class ProvisioningStatus(str, Enum):
    pending = "pending"
    permit_open = "permit_open"
    joining = "joining"
    joined = "joined"
    failed = "failed"
    expired = "expired"
    cancelled = "cancelled"


class ProvisioningErrorCode(str, Enum):
    INVALID_QR_PAYLOAD = "INVALID_QR_PAYLOAD"
    INVALID_EUI64 = "INVALID_EUI64"
    INVALID_INSTALL_CODE = "INVALID_INSTALL_CODE"
    UNSUPPORTED_DEVICE_TYPE = "UNSUPPORTED_DEVICE_TYPE"
    DEVICE_NOT_FACTORY_REGISTERED = "DEVICE_NOT_FACTORY_REGISTERED"
    GATEWAY_NOT_FOUND = "GATEWAY_NOT_FOUND"
    ROOM_NOT_FOUND = "ROOM_NOT_FOUND"
    SESSION_ALREADY_ACTIVE = "SESSION_ALREADY_ACTIVE"


class ProvisioningDevicePayload(BaseModel):
    eui64: str
    device_type: Literal["light", "switch", "motion", "sensor", "environment"]
    install_code: str | None = None

    @field_validator("eui64")
    @classmethod
    def _validate_eui64(cls, value: str) -> str:
        if not _EUI64_RE.fullmatch(value):
            raise ValueError("eui64 must be 16 hex characters")
        return value.upper()

    @field_validator("install_code")
    @classmethod
    def _validate_install_code(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            return normalize_install_code(value)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc


class ProvisioningLabelCreate(BaseModel):
    eui64: str
    device_type: Literal["light", "switch", "motion", "sensor"]

    @field_validator("eui64")
    @classmethod
    def _validate_eui64(cls, value: str) -> str:
        if not _EUI64_RE.fullmatch(value):
            raise ValueError("eui64 must be 16 hex characters")
        return value.upper()


class ProvisioningLabelOut(BaseModel):
    payload: dict[str, Any]
    payload_json: str
    qr_svg: str


class FactoryDeviceRegister(BaseModel):
    """Register a factory device + its install code into the factory registry.

    The install code is validated (Zigbee CRC) and stored, but is never echoed
    back in responses — see ``FactoryDeviceOut``.
    """

    eui64: str
    install_code: str
    device_type: Literal["light", "switch", "motion", "sensor"]
    model: str | None = None

    @field_validator("eui64")
    @classmethod
    def _validate_eui64(cls, value: str) -> str:
        if not _EUI64_RE.fullmatch(value):
            raise ValueError("eui64 must be 16 hex characters")
        return value.upper()

    @field_validator("install_code")
    @classmethod
    def _validate_install_code(cls, value: str) -> str:
        try:
            return normalize_install_code(value)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc


class FactoryDeviceOut(BaseModel):
    """Safe factory-device view. Never exposes the raw install code."""

    eui64: str
    device_type: str
    model: str | None = None
    is_active: bool
    has_install_code: bool


class ProvisioningSessionCreate(BaseModel):
    gateway_id: str = Field(min_length=1)
    room_id: str | None = Field(default=None, min_length=1)
    device: ProvisioningDevicePayload


class ProvisioningSessionRoomUpdate(BaseModel):
    room_id: str = Field(min_length=1)


class ProvisioningSessionOut(BaseModel):
    session_id: str = Field(validation_alias="id")
    status: ProvisioningStatus
    gateway_id: str
    room_id: str | None
    eui64: str
    device_type: Literal["light", "switch", "motion", "sensor"]
    model: str | None
    reason: str | None = None
    expires_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        use_enum_values=True,
    )

    @field_serializer("expires_at", "created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


# ---------------------------------------------------------------------------
# Gateway commissioning (open / close permit-join)
# ---------------------------------------------------------------------------


class CommissioningOpenBody(BaseModel):
    """Public body for POST /api/gateways/{id}/commissioning/open.

    `duration_sec` matches the gateway-side wire field exactly so the cloud
    forwards it untranslated.  Cap at 180 s (= OPEN_JOIN_MS in app_config.h).
    """

    duration_sec: int = Field(default=180, ge=1, le=180)
    timeout_ms: int | None = Field(default=5000, ge=100, le=60000)


class CommissioningCloseBody(BaseModel):
    """Public body for POST /api/gateways/{id}/commissioning/close."""

    timeout_ms: int | None = Field(default=5000, ge=100, le=60000)


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
