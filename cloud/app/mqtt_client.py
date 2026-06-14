import asyncio
import json
import logging
from datetime import UTC, datetime
from uuid import uuid4

import paho.mqtt.client as mqtt

from cloud.app.config import settings as _settings
from cloud.app.schemas import (
    TERMINAL_STATUSES,
    validate_event_payload,
    validate_reported_payload,
)

logger = logging.getLogger(__name__)

PROVISIONING_TERMINAL_STATUSES = {"joined", "failed", "expired", "cancelled"}


def _now_ms() -> int:
    return int(datetime.now(UTC).timestamp() * 1000)


def _ts_ms_to_naive_utc(ts: object) -> datetime:
    """Parse MQTT envelope `ts` (epoch ms) into a naive UTC datetime for DB.

    Accepts int/float ms. If `ts` is missing or unparseable, falls back to now.
    """
    try:
        if isinstance(ts, (int, float)):
            return datetime.fromtimestamp(int(ts) / 1000.0, tz=UTC).replace(
                tzinfo=None
            )
    except (ValueError, OSError, OverflowError):
        pass
    return datetime.now(UTC).replace(tzinfo=None)


class MQTTService:
    """MQTT client service that connects the cloud backend to the gateway broker.

    Subscribes to device reported state, events, command replies, and gateway
    online status.  Provides ``publish_command`` for sending command requests.
    """

    def __init__(self) -> None:
        self.settings = _settings
        self.client = mqtt.Client(
            client_id=f"cloud-backend-{uuid4().hex[:8]}",
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        )
        self._db_session_factory = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._terminal_command_ids: set[str] = set()

    # ------------------------------------------------------------------
    # Configuration helpers
    # ------------------------------------------------------------------

    def set_db_session_factory(self, factory):
        """Set the async session factory for DB writes from MQTT callbacks."""
        self._db_session_factory = factory

    @property
    def topic_prefix(self) -> str:
        s = self.settings
        return f"sb/v1/{s.tenant_id}/{s.site_id}/{s.gateway_id}"

    # ------------------------------------------------------------------
    # Connection lifecycle
    # ------------------------------------------------------------------

    def connect(self) -> None:
        self._loop = asyncio.get_running_loop()
        if not getattr(self.settings, "mqtt_cert_identity_enabled", False):
            self.client.username_pw_set(
                self.settings.mqtt_username, self.settings.mqtt_password
            )
        self._configure_tls()
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port)
        self.client.loop_start()

    def disconnect(self) -> None:
        self.client.loop_stop()
        self.client.disconnect()

    def _configure_tls(self) -> None:
        certificate_identity_enabled = getattr(
            self.settings, "mqtt_cert_identity_enabled", False
        )
        if certificate_identity_enabled and (
            not self.settings.mqtt_tls_enabled
            or not self.settings.mqtt_mtls_enabled
        ):
            raise RuntimeError(
                "SB_MQTT_TLS_ENABLED and SB_MQTT_MTLS_ENABLED must be true "
                "when SB_MQTT_CERT_IDENTITY_ENABLED=true"
            )
        if not self.settings.mqtt_tls_enabled:
            return
        if not self.settings.mqtt_ca_cert_path:
            raise RuntimeError(
                "SB_MQTT_CA_CERT_PATH is required when SB_MQTT_TLS_ENABLED=true"
            )

        certfile = None
        keyfile = None
        if self.settings.mqtt_mtls_enabled:
            if (
                not self.settings.mqtt_client_cert_path
                or not self.settings.mqtt_client_key_path
            ):
                raise RuntimeError(
                    "SB_MQTT_CLIENT_CERT_PATH and SB_MQTT_CLIENT_KEY_PATH are "
                    "required when SB_MQTT_MTLS_ENABLED=true"
                )
            certfile = self.settings.mqtt_client_cert_path
            keyfile = self.settings.mqtt_client_key_path

        self.client.tls_set(
            ca_certs=self.settings.mqtt_ca_cert_path,
            certfile=certfile,
            keyfile=keyfile,
        )

    # ------------------------------------------------------------------
    # Callbacks
    # ------------------------------------------------------------------

    def _on_connect(self, client, userdata, flags, rc, properties=None):
        logger.info("MQTT connected with rc=%s", rc)
        # Demo deployment uses QoS 0 for all topics (see docs/MQTT_CONTRACT.md
        # "Retain và QoS" → "Demo vs production"). Production must raise to
        # the per-topic QoS defined in that table.
        prefix = self.topic_prefix
        client.subscribe(f"{prefix}/devices/+/+/reported", qos=0)
        client.subscribe(f"{prefix}/devices/+/+/telemetry", qos=0)
        client.subscribe(f"{prefix}/devices/+/+/event", qos=0)
        client.subscribe(f"{prefix}/devices/+/+/registry", qos=0)
        client.subscribe(f"{prefix}/devices/+/+/presence", qos=0)
        client.subscribe(f"{prefix}/commands/+/reply", qos=0)
        client.subscribe(f"{prefix}/gateway/online", qos=0)
        client.subscribe(f"{prefix}/gateway/health", qos=0)
        client.subscribe(f"{prefix}/gateway/event", qos=0)
        # Automation sync (see docs/AUTOMATION_MQTT_CONTRACT.md).
        client.subscribe(f"{prefix}/automations/+/reported", qos=0)
        client.subscribe(f"{prefix}/automations/+/event", qos=0)

    def _on_message(self, client, userdata, msg):
        """Route incoming MQTT messages to the appropriate handler."""
        try:
            logger.info("MQTT rx: %s (%d bytes)", msg.topic, len(msg.payload))
            # An empty retained payload is the broker-level "clear retained"
            # marker (gateway uses this to drop stale registry slots after
            # ZDO re-classification).  Nothing to parse, nothing to persist.
            if len(msg.payload) == 0:
                logger.debug(
                    "Empty payload on %s (retain-clear) -- skipping", msg.topic,
                )
                return
            payload = json.loads(msg.payload.decode("utf-8"))
            topic: str = msg.topic

            if "/devices/" in topic and topic.endswith("/reported"):
                self._handle_reported(topic, payload)
            elif "/devices/" in topic and topic.endswith("/telemetry"):
                self._handle_reported(topic, payload)
            elif "/devices/" in topic and topic.endswith("/event"):
                self._handle_event(topic, payload)
            elif "/devices/" in topic and topic.endswith("/registry"):
                self._handle_registry(topic, payload)
            elif "/devices/" in topic and topic.endswith("/presence"):
                self._handle_presence(topic, payload)
            elif "/commands/" in topic and topic.endswith("/reply"):
                self._handle_command_reply(topic, payload)
            elif topic.endswith("/gateway/online"):
                self._handle_gateway_online(payload)
            elif topic.endswith("/gateway/health"):
                self._handle_gateway_health(payload)
            elif topic.endswith("/gateway/event"):
                self._handle_gateway_event(payload)
            elif "/automations/" in topic and topic.endswith("/reported"):
                self._handle_automation_reported(topic, payload)
            elif "/automations/" in topic and topic.endswith("/event"):
                self._handle_automation_event(topic, payload)
            else:
                logger.debug("Unhandled topic: %s", topic)
        except Exception:
            logger.exception("Error processing message on %s", msg.topic)

    # ------------------------------------------------------------------
    # Message handlers
    # ------------------------------------------------------------------

    def _handle_reported(self, topic: str, envelope: dict) -> None:
        """Handle device reported state -- upsert device + insert state row."""
        parts = topic.split("/")
        # Topic: sb/v1/{t}/{s}/{g}/devices/{device_type}/{device_id}/reported|telemetry
        devices_idx = parts.index("devices")
        device_type = parts[devices_idx + 1]
        device_id = parts[devices_idx + 2]
        inner = envelope.get("payload", {})
        # Presence: gateway sets state.reachable=false when a device leaves the
        # network or a liveness probe fails, so online flips immediately instead
        # of waiting for the offline reaper. Absent => assume reachable (normal
        # state reports), preserving prior behaviour.
        # Validate payload by device_type (Phase 3.4)
        validated = validate_reported_payload(device_type, inner)
        if validated is None:
            logger.warning(
                "Reported payload validation failed for %s (type=%s): %s",
                device_id, device_type, inner,
            )
            # Still persist raw data but log the warning
            validated = inner
        normalized_inner = validated
        reachable = bool(
            (normalized_inner.get("state") or {}).get("reachable", True)
        )

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Device, DeviceState
            from sqlalchemy import select

            async with self._db_session_factory() as session:
                result = await session.execute(
                    select(Device).where(Device.id == device_id)
                )
                device = result.scalar_one_or_none()
                last_seen = _ts_ms_to_naive_utc(envelope.get("ts"))
                if not device:
                    device = Device(
                        id=device_id,
                        device_type=normalized_inner.get(
                            "device_type",
                            device_type,
                        ),
                        sensor_kind=normalized_inner.get("sensor_kind"),
                        eui64=normalized_inner.get("eui64"),
                        name=device_id,
                        is_online=reachable,
                        last_seen_at=last_seen,
                    )
                    session.add(device)
                else:
                    device.is_online = reachable
                    device.last_seen_at = last_seen
                    if normalized_inner.get("eui64"):
                        device.eui64 = normalized_inner["eui64"]
                    if normalized_inner.get("sensor_kind") is not None:
                        device.sensor_kind = normalized_inner["sensor_kind"]

                state = normalized_inner.get("state", normalized_inner)
                if device_type in {"environment", "sensor"}:
                    previous = (
                        await session.execute(
                            select(DeviceState)
                            .where(DeviceState.device_id == device_id)
                            .order_by(DeviceState.reported_at.desc())
                            .limit(1)
                        )
                    ).scalar_one_or_none()
                    state = {
                        **(previous.state if previous is not None else {}),
                        **state,
                    }
                state_row = DeviceState(
                    device_id=device_id,
                    state=state,
                    reported_at=last_seen,
                )
                session.add(state_row)
                await session.commit()
                logger.info("Saved reported state for %s", device_id)

        self._run_async(_write)

    def _handle_presence(self, topic: str, envelope: dict) -> None:
        """Handle device presence -- set is_online from reachable WITHOUT
        inserting a DeviceState row (so the last reported power/level is not
        clobbered). The gateway publishes reachable=false on leave / probe
        failure so offline reflects promptly; reachable=true heartbeats keep
        last_seen_at fresh so the offline reaper does not fire for idle devices.
        """
        parts = topic.split("/")
        devices_idx = parts.index("devices")
        device_id = parts[devices_idx + 2]
        inner = envelope.get("payload", {})
        reachable = bool((inner.get("state") or {}).get("reachable", True))

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Device
            from sqlalchemy import select

            async with self._db_session_factory() as session:
                device = (
                    await session.execute(
                        select(Device).where(Device.id == device_id)
                    )
                ).scalar_one_or_none()
                if device is None:
                    return  # presence for an unregistered device; ignore
                device.is_online = reachable
                device.last_seen_at = _ts_ms_to_naive_utc(envelope.get("ts"))
                await session.commit()
                logger.info("Presence %s online=%s", device_id, reachable)

        self._run_async(_write)

    def _handle_event(self, topic: str, envelope: dict) -> None:
        """Handle device event -- auto-register device + insert event row."""
        parts = topic.split("/")
        # Topic: sb/v1/{t}/{s}/{g}/devices/{device_type}/{device_id}/event
        devices_idx = parts.index("devices")
        device_type = parts[devices_idx + 1]
        device_id = parts[devices_idx + 2]
        inner = envelope.get("payload", {})

        # Validate payload by device_type (Phase 3.4)
        validated = validate_event_payload(device_type, inner)
        if validated is None:
            logger.warning(
                "Event payload validation failed for %s (type=%s): %s",
                device_id, device_type, inner,
            )
            validated = inner

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Device, DeviceState, Event
            from sqlalchemy import select

            async with self._db_session_factory() as session:
                # Auto-register device if not yet known (Phase 3.3)
                result = await session.execute(
                    select(Device).where(Device.id == device_id)
                )
                device = result.scalar_one_or_none()
                last_seen = _ts_ms_to_naive_utc(envelope.get("ts"))
                if not device:
                    device = Device(
                        id=device_id,
                        device_type=validated.get("device_type", device_type),
                        eui64=validated.get("eui64"),
                        name=device_id,
                        is_online=True,
                        last_seen_at=last_seen,
                    )
                    session.add(device)
                    logger.info("Auto-registered device %s (type=%s) from event",
                                device_id, device_type)
                else:
                    device.is_online = True
                    device.last_seen_at = last_seen

                event = Event(
                    device_id=device_id,
                    event_type=validated.get(
                        "event", validated.get("event_type", "unknown")
                    ),
                    payload=validated,
                    occurred_at=last_seen,
                )
                session.add(event)
                if (
                    device_type in {"motion", "sensor"}
                    and validated.get("event") == "occupancy_changed"
                    and validated.get("occupancy") in {"occupied", "unoccupied"}
                ):
                    session.add(
                        DeviceState(
                            device_id=device_id,
                            state={
                                "occupancy": validated["occupancy"],
                                "reachable": True,
                            },
                            reported_at=last_seen,
                        )
                    )
                await session.commit()
                logger.info("Saved event for %s (type=%s, event=%s)",
                            device_id, device_type, event.event_type)

        self._run_async(_write)

    def _handle_command_reply(self, topic: str, envelope: dict) -> None:
        """Handle command reply -- update command status and infer device state."""
        parts = topic.split("/")
        cmd_id_idx = parts.index("commands") + 1
        command_id = parts[cmd_id_idx]
        inner = envelope.get("payload", {})
        incoming_status = inner.get("status")
        if (
            command_id in self._terminal_command_ids
            and incoming_status not in TERMINAL_STATUSES
        ):
            logger.info(
                "Ignoring command %s status=%s after terminal callback",
                command_id,
                incoming_status,
            )
            return
        if incoming_status in TERMINAL_STATUSES:
            self._terminal_command_ids.add(command_id)

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import (
                Command,
                Device,
                DeviceState,
                ProvisioningSession,
            )
            from sqlalchemy import select, update

            async with self._db_session_factory() as session:
                result = await session.execute(
                    select(Command).where(Command.id == command_id)
                )
                cmd = result.scalar_one_or_none()
                if not cmd:
                    return
                new_status = inner.get("status", cmd.status)
                update_result = await session.execute(
                    update(Command)
                    .where(
                        Command.id == command_id,
                        Command.status.notin_(list(TERMINAL_STATUSES)),
                    )
                    .values(status=new_status, reason=inner.get("reason"))
                )
                if update_result.rowcount == 0:
                    logger.info(
                        "Ignoring non-authoritative command %s status=%s after terminal %s",
                        command_id,
                        new_status,
                        cmd.status,
                    )
                    return
                cmd.status = new_status
                cmd.reason = inner.get("reason")
                logger.info(
                    "Updated command %s status=%s", command_id, new_status
                )

                prov_result = await session.execute(
                    select(ProvisioningSession).where(
                        ProvisioningSession.command_id == command_id,
                        ProvisioningSession.status.notin_(
                            list(PROVISIONING_TERMINAL_STATUSES)
                        ),
                    )
                )
                prov = prov_result.scalar_one_or_none()
                if prov is not None and new_status in TERMINAL_STATUSES:
                    if new_status == "executed":
                        prov.status = "permit_open"
                        prov.reason = None
                    else:
                        prov.status = "failed"
                        prov.reason = inner.get("reason") or new_status

                # When a light command is executed, infer the new device state
                # so the dashboard can show updated status immediately.
                if (
                    new_status == "executed"
                    and cmd.device_id
                    and cmd.target_kind == "device"
                ):
                    dev_result = await session.execute(
                        select(Device).where(Device.id == cmd.device_id)
                    )
                    device = dev_result.scalar_one_or_none()
                    if device and device.device_type == "light":
                        inferred = self._infer_light_state(
                            session, device, cmd.target
                        )
                        if inferred is not None:
                            # Read current state to merge
                            latest_q = await session.execute(
                                select(DeviceState)
                                .where(DeviceState.device_id == device.id)
                                .order_by(DeviceState.reported_at.desc())
                                .limit(1)
                            )
                            latest = latest_q.scalar_one_or_none()
                            merged = dict(latest.state) if latest else {
                                "power": "off", "level": 0, "reachable": True,
                            }
                            merged.update(inferred)
                            now = datetime.now(UTC).replace(tzinfo=None)
                            session.add(DeviceState(
                                device_id=device.id,
                                state=merged,
                                reported_at=now,
                            ))
                            logger.info(
                                "Inferred light state for %s: %s",
                                device.id, merged,
                            )

                await session.commit()

        self._run_async(_write)

    @staticmethod
    def _infer_light_state(session, device, target: dict) -> dict | None:
        """Infer new light state fields from a command target."""
        cmd_name = target.get("command")
        if cmd_name == "on":
            return {"power": "on", "reachable": True}
        if cmd_name == "off":
            return {"power": "off", "reachable": True}
        if cmd_name == "set_level" and "level" in target:
            return {"level": target["level"], "reachable": True}
        return None

    def _handle_gateway_online(self, envelope: dict) -> None:
        inner = envelope.get("payload", {})
        status = inner.get("value", "unknown")
        logger.info("Gateway status: %s", status)

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Event

            payload = dict(inner)
            payload["gateway_id"] = envelope.get("gateway_id")
            payload["source"] = envelope.get("source")
            async with self._db_session_factory() as session:
                event = Event(
                    device_id=None,
                    event_type="gateway_online",
                    payload=payload,
                    occurred_at=_ts_ms_to_naive_utc(envelope.get("ts")),
                )
                session.add(event)
                await session.commit()

        self._run_async(_write)

    def _handle_registry(self, topic: str, envelope: dict) -> None:
        """Handle retained device registry snapshot -- upsert device + log event.

        Topic: .../devices/{device_type}/{device_id}/registry
        Payload carries the gateway's view of the device (eui64, endpoints,
        inferred clusters, metadata_source). Used for first-time device
        discovery on cloud reconnect.
        """
        parts = topic.split("/")
        devices_idx = parts.index("devices")
        device_type = parts[devices_idx + 1]
        device_id = parts[devices_idx + 2]
        inner = envelope.get("payload", {})

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Device, Event
            from sqlalchemy import select

            async with self._db_session_factory() as session:
                result = await session.execute(
                    select(Device).where(Device.id == device_id)
                )
                device = result.scalar_one_or_none()
                last_seen = _ts_ms_to_naive_utc(envelope.get("ts"))
                if not device:
                    device = Device(
                        id=device_id,
                        device_type=inner.get("device_type", device_type),
                        eui64=inner.get("eui64"),
                        name=device_id,
                        is_online=True,
                        last_seen_at=last_seen,
                    )
                    session.add(device)
                    logger.info(
                        "Registered device %s (type=%s) from registry",
                        device_id, device_type,
                    )
                else:
                    device.is_online = True
                    device.last_seen_at = last_seen
                    if inner.get("eui64"):
                        device.eui64 = inner["eui64"]
                    new_type = inner.get("device_type")
                    if new_type and new_type != device.device_type:
                        logger.warning(
                            "Registry type change for %s: %s -> %s "
                            "(gateway re-classified)",
                            device_id, device.device_type, new_type,
                        )
                        device.device_type = new_type

                event = Event(
                    device_id=device_id,
                    event_type="device_registry",
                    payload=inner,
                    occurred_at=last_seen,
                )
                session.add(event)
                await session.commit()
                logger.info("Saved device_registry event for %s", device_id)

        self._run_async(_write)

    def _handle_automation_reported(self, topic: str, envelope: dict) -> None:
        """Gateway acked a desired upsert/delete. Update Automation row.

        Topic: .../automations/{automation_id}/reported. Retained per contract.
        Payload carries automation_id, version, sync_status, last_error.

        sync_status="deleted" hard-deletes the row (matches the DELETE handler
        contract — keep row in pending state until gateway confirms).
        """
        parts = topic.split("/")
        try:
            idx = parts.index("automations")
            automation_id = parts[idx + 1]
        except (ValueError, IndexError):
            logger.warning("automation reported: bad topic %s", topic)
            return
        inner = envelope.get("payload") or {}
        if inner.get("automation_id") and inner["automation_id"] != automation_id:
            logger.warning(
                "automation reported: payload id %s != topic id %s; trusting topic",
                inner.get("automation_id"), automation_id,
            )
        sync_status = inner.get("sync_status")
        if sync_status not in {"synced", "failed", "deleted"}:
            logger.warning(
                "automation reported: invalid sync_status=%s for %s",
                sync_status, automation_id,
            )
            return
        gateway_version = inner.get("version")
        last_error = inner.get("last_error")

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Automation

            async with self._db_session_factory() as session:
                rule = await session.get(Automation, automation_id)
                if rule is None:
                    logger.info(
                        "automation reported for unknown id=%s (ignored)",
                        automation_id,
                    )
                    return
                if (
                    isinstance(gateway_version, int)
                    and gateway_version < (rule.version or 0)
                ):
                    # Stale ack from an earlier desired payload. Log and skip
                    # without mutating row — contract §7.
                    logger.info(
                        "automation reported stale: id=%s gateway_v=%s db_v=%s",
                        automation_id, gateway_version, rule.version,
                    )
                    return
                if sync_status == "deleted":
                    await session.delete(rule)
                    await session.commit()
                    logger.info(
                        "automation %s deleted (gateway ack)", automation_id,
                    )
                    return
                rule.sync_status = sync_status
                rule.last_error = last_error if sync_status == "failed" else None
                await session.commit()
                logger.info(
                    "automation %s sync_status=%s", automation_id, sync_status,
                )

        self._run_async(_write)

    def _handle_automation_event(self, topic: str, envelope: dict) -> None:
        """Gateway emitted an automation execution event (rule_fired etc.).

        Topic: .../automations/{automation_id}/event. Non-retained per contract.
        Inserts an `Event` row (event_type=automation_<event>) and updates the
        Automation row's last_run_status / last_error so the dashboard reflects
        the most recent execution.
        """
        parts = topic.split("/")
        try:
            idx = parts.index("automations")
            automation_id = parts[idx + 1]
        except (ValueError, IndexError):
            logger.warning("automation event: bad topic %s", topic)
            return
        inner = envelope.get("payload") or {}
        # `event` is the gateway-emitted kind (rule_fired, rule_skipped…); we
        # encode it into Event.event_type as automation_<event>.
        event_kind = inner.get("event", "rule_fired")
        status = inner.get("status", "executed")
        last_error = inner.get("last_error")
        occurred_at = _ts_ms_to_naive_utc(envelope.get("ts"))

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Automation, Event

            async with self._db_session_factory() as session:
                event_row = Event(
                    device_id=None,
                    event_type=f"automation_{event_kind}",
                    payload={"automation_id": automation_id, **inner},
                    occurred_at=occurred_at,
                )
                session.add(event_row)
                rule = await session.get(Automation, automation_id)
                # last_run_status / last_error are only mutated on **terminal**
                # statuses. Non-terminal (e.g. "skipped") still inserts an
                # Event row but leaves the rule's last-run summary untouched.
                if rule is not None and status in {"executed", "failed", "timeout"}:
                    rule.last_run_status = status
                    rule.last_error = (
                        last_error if status in {"failed", "timeout"} else None
                    )
                await session.commit()
                logger.info(
                    "automation %s event=%s status=%s saved",
                    automation_id, event_kind, status,
                )

        self._run_async(_write)

    def _handle_gateway_event(self, envelope: dict) -> None:
        """Persist gateway-level events and fold automation status updates."""
        inner = envelope.get("payload", {})
        event = inner.get("event", "unknown")
        logger.info("Gateway event: %s payload=%s", event, inner)

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import (
                Automation,
                AutomationEvent,
                Device,
                Event,
                ProvisioningSession,
            )
            from sqlalchemy import select

            payload = dict(inner)
            payload["gateway_id"] = envelope.get("gateway_id")
            payload["source"] = envelope.get("source")
            rule_id = payload.get("rule_id") or payload.get("automation_id")
            occurred_at = _ts_ms_to_naive_utc(envelope.get("ts"))

            async with self._db_session_factory() as session:
                session.add(
                    Event(
                        device_id=None,
                        event_type=event,
                        payload=payload,
                        occurred_at=occurred_at,
                    )
                )

                if event in ("provisioning_joined", "provisioning_failed"):
                    eui64 = payload.get("eui64")
                    gateway_id = envelope.get("gateway_id")
                    if isinstance(eui64, str) and isinstance(gateway_id, str):
                        prov_result = await session.execute(
                            select(ProvisioningSession)
                            .where(
                                ProvisioningSession.eui64 == eui64,
                                ProvisioningSession.gateway_id == gateway_id,
                                ProvisioningSession.status.notin_(
                                    list(PROVISIONING_TERMINAL_STATUSES)
                                ),
                            )
                            .order_by(ProvisioningSession.created_at.desc())
                            .limit(1)
                        )
                        prov = prov_result.scalar_one_or_none()
                        if prov is not None:
                            if event == "provisioning_joined":
                                device = await session.get(Device, eui64)
                                if device is None:
                                    device = Device(
                                        id=eui64,
                                        device_type=payload.get(
                                            "device_type", prov.device_type
                                        ),
                                        eui64=eui64,
                                        room_id=prov.room_id,
                                        name=prov.model or eui64,
                                        is_online=True,
                                        last_seen_at=occurred_at,
                                    )
                                    session.add(device)
                                else:
                                    device.device_type = payload.get(
                                        "device_type", device.device_type
                                    )
                                    device.eui64 = eui64
                                    device.room_id = prov.room_id
                                    device.is_online = True
                                    # Stamp last_seen so the offline reaper does
                                    # not immediately flip a just-joined device
                                    # back offline before its first report.
                                    device.last_seen_at = occurred_at
                                prov.status = "joined"
                                prov.reason = None
                                prov.install_code = ""
                            else:
                                prov.status = "failed"
                                prov.reason = payload.get("reason") or "failed"

                if isinstance(rule_id, str) and rule_id:
                    rule = await session.get(Automation, rule_id)
                    if rule is not None:
                        if event == "automation_synced":
                            rule.sync_status = "synced"
                            rule.last_error = None
                        elif event == "automation_sync_failed":
                            rule.sync_status = "failed"
                            rule.last_error = payload.get("reason")
                        elif event == "automation_executed":
                            result = payload.get("result")
                            if result == "ok":
                                rule.last_run_status = "executed"
                                rule.last_error = None
                            elif result == "timeout":
                                rule.last_run_status = "timeout"
                                rule.last_error = payload.get("reason")
                            else:
                                rule.last_run_status = "failed"
                                rule.last_error = payload.get("reason")

                        if event in (
                            "automation_synced",
                            "automation_sync_failed",
                            "automation_executed",
                        ):
                            status_value: str | None = None
                            reason = payload.get("reason")
                            if event == "automation_synced":
                                status_value = "synced"
                            elif event == "automation_sync_failed":
                                status_value = "failed"
                            elif event == "automation_executed":
                                result = payload.get("result")
                                if result == "ok":
                                    status_value = "executed"
                                elif result == "timeout":
                                    status_value = "timeout"
                                else:
                                    status_value = "failed"

                            session.add(
                                AutomationEvent(
                                    automation_id=rule_id if rule is not None else None,
                                    event_type=event,
                                    status=status_value,
                                    reason=reason,
                                    payload=payload,
                                    occurred_at=occurred_at,
                                )
                            )

                await session.commit()

        self._run_async(_write)

    def _handle_gateway_health(self, envelope: dict) -> None:
        """Persist a gateway health snapshot as an unattached event.

        Device_id is null because health belongs to the gateway itself,
        not any one device. occurred_at is the envelope ts.
        """
        inner = envelope.get("payload", {})
        logger.info(
            "Gateway health: uptime=%s ms, mqtt=%s, devices=%s, net=%s",
            inner.get("uptime_ms"),
            inner.get("mqtt_connected"),
            inner.get("known_device_count"),
            inner.get("network_state"),
        )

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Event

            async with self._db_session_factory() as session:
                event = Event(
                    device_id=None,
                    event_type="gateway_health",
                    payload=inner,
                    occurred_at=_ts_ms_to_naive_utc(envelope.get("ts")),
                )
                session.add(event)
                await session.commit()

        self._run_async(_write)

    # ------------------------------------------------------------------
    # Publishing
    # ------------------------------------------------------------------

    def publish_command(
        self,
        command_id: str,
        device_id: str,
        op: str,
        target: dict,
        timeout_ms: int | None = 5000,
    ) -> None:
        """Publish a command request envelope to MQTT."""
        s = self.settings
        topic = f"{self.topic_prefix}/commands/{command_id}/request"
        envelope = {
            "schema": "sb.v1",
            "msg_id": uuid4().hex,
            "ts": _now_ms(),
            "tenant_id": s.tenant_id,
            "site_id": s.site_id,
            "gateway_id": s.gateway_id,
            "source": "cloud",
            # Optional per contract; format is "cmd_" + command_id.
            "correlation_id": f"cmd_{command_id}",
            "payload": {
                "device_id": device_id,
                "op": op,
                "target": target,
                "timeout_ms": timeout_ms,
            },
        }
        # Demo: QoS 0. Production: QoS 1 per docs/MQTT_CONTRACT.md.
        self.client.publish(topic, json.dumps(envelope), qos=0)
        logger.info("Published command %s for %s", command_id, device_id)

    def publish_gateway_command(
        self,
        command_id: str,
        op: str,
        target: dict,
        timeout_ms: int | None = 5000,
    ) -> None:
        """Publish a gateway-targeted command request envelope to MQTT.

        Same topic shape as ``publish_command`` (``commands/{id}/request``) but
        the payload omits ``device_id`` because there is no device target
        (e.g. ``op=gateway.open_network``).  Gateway parser is responsible for
        accepting payload without ``device_id`` when ``op`` is gateway-scoped.
        """
        s = self.settings
        topic = f"{self.topic_prefix}/commands/{command_id}/request"
        envelope = {
            "schema": "sb.v1",
            "msg_id": uuid4().hex,
            "ts": _now_ms(),
            "tenant_id": s.tenant_id,
            "site_id": s.site_id,
            "gateway_id": s.gateway_id,
            "source": "cloud",
            "correlation_id": f"cmd_{command_id}",
            "payload": {
                "op": op,
                "target": target,
                "timeout_ms": timeout_ms,
            },
        }
        self.client.publish(topic, json.dumps(envelope), qos=0)
        logger.info("Published gateway command %s op=%s", command_id, op)

    def publish_automation_desired(
        self,
        automation_id: str,
        op: str,
        version: int,
        *,
        name: str | None = None,
        enabled: bool | None = None,
        trigger: dict | None = None,
        actions: list[dict] | None = None,
    ) -> None:
        """Publish a retained automation desired envelope.

        See docs/AUTOMATION_MQTT_CONTRACT.md §4. op must be "upsert" or
        "delete". For upsert, name/enabled/trigger/actions are required; for
        delete, the payload carries op=delete + deleted=true (tombstone).
        """
        if op not in {"upsert", "delete"}:
            raise ValueError(f"publish_automation_desired: bad op={op!r}")
        s = self.settings
        topic = f"{self.topic_prefix}/automations/{automation_id}/desired"
        payload: dict = {
            "automation_id": automation_id,
            "op": op,
            "version": version,
        }
        if op == "upsert":
            payload.update({
                "name": name,
                "enabled": bool(enabled),
                "trigger": trigger or {},
                "actions": actions or [],
            })
        else:
            payload["deleted"] = True
        envelope = {
            "schema": "sb.v1",
            "msg_id": uuid4().hex,
            "ts": _now_ms(),
            "tenant_id": s.tenant_id,
            "site_id": s.site_id,
            "gateway_id": s.gateway_id,
            "source": "cloud",
            "correlation_id": f"auto_{automation_id}",
            "payload": payload,
        }
        # Demo: QoS 0. Production: QoS 1 per docs/MQTT_CONTRACT.md.
        # Retained per contract §4 (both upsert and delete tombstone).
        self.client.publish(topic, json.dumps(envelope), qos=0, retain=True)
        logger.info(
            "Published automation %s op=%s version=%s", automation_id, op, version,
        )

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _run_async(self, coro_func) -> None:
        """Schedule an async coroutine from a synchronous paho callback thread."""

        async def _wrapped():
            try:
                await coro_func()
            except Exception:
                logger.exception("Async DB write failed")

        if self._loop and self._loop.is_running():
            asyncio.run_coroutine_threadsafe(_wrapped(), self._loop)
        else:
            asyncio.run(_wrapped())


# Module-level singleton used across the application.
mqtt_service = MQTTService()
