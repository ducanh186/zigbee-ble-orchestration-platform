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
        self.client.username_pw_set(
            self.settings.mqtt_username, self.settings.mqtt_password
        )
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port)
        self.client.loop_start()

    def disconnect(self) -> None:
        self.client.loop_stop()
        self.client.disconnect()

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
        client.subscribe(f"{prefix}/commands/+/reply", qos=0)
        client.subscribe(f"{prefix}/gateway/online", qos=0)
        client.subscribe(f"{prefix}/gateway/health", qos=0)
        client.subscribe(f"{prefix}/gateway/event", qos=0)

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
            elif "/commands/" in topic and topic.endswith("/reply"):
                self._handle_command_reply(topic, payload)
            elif topic.endswith("/gateway/online"):
                self._handle_gateway_online(payload)
            elif topic.endswith("/gateway/health"):
                self._handle_gateway_health(payload)
            elif topic.endswith("/gateway/event"):
                self._handle_gateway_event(payload)
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

        # Validate payload by device_type (Phase 3.4)
        validated = validate_reported_payload(device_type, inner)
        if validated is None:
            logger.warning(
                "Reported payload validation failed for %s (type=%s): %s",
                device_id, device_type, inner,
            )
            # Still persist raw data but log the warning
            validated = inner

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
                if not device:
                    device = Device(
                        id=device_id,
                        device_type=inner.get("device_type", device_type),
                        eui64=inner.get("eui64"),
                        name=device_id,
                        is_online=True,
                    )
                    session.add(device)
                else:
                    device.is_online = True
                    if inner.get("eui64"):
                        device.eui64 = inner["eui64"]

                state_row = DeviceState(
                    device_id=device_id,
                    state=inner.get("state", inner),
                    reported_at=_ts_ms_to_naive_utc(envelope.get("ts")),
                )
                session.add(state_row)
                await session.commit()
                logger.info("Saved reported state for %s", device_id)

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
            from cloud.app.models import Device, Event
            from sqlalchemy import select

            async with self._db_session_factory() as session:
                # Auto-register device if not yet known (Phase 3.3)
                result = await session.execute(
                    select(Device).where(Device.id == device_id)
                )
                device = result.scalar_one_or_none()
                if not device:
                    device = Device(
                        id=device_id,
                        device_type=validated.get("device_type", device_type),
                        eui64=validated.get("eui64"),
                        name=device_id,
                        is_online=True,
                    )
                    session.add(device)
                    logger.info("Auto-registered device %s (type=%s) from event",
                                device_id, device_type)

                event = Event(
                    device_id=device_id,
                    event_type=validated.get(
                        "event", validated.get("event_type", "unknown")
                    ),
                    payload=validated,
                    occurred_at=_ts_ms_to_naive_utc(envelope.get("ts")),
                )
                session.add(event)
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
            from cloud.app.models import Command, Device, DeviceState
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
                if not device:
                    device = Device(
                        id=device_id,
                        device_type=inner.get("device_type", device_type),
                        eui64=inner.get("eui64"),
                        name=device_id,
                        is_online=True,
                    )
                    session.add(device)
                    logger.info(
                        "Registered device %s (type=%s) from registry",
                        device_id, device_type,
                    )
                else:
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
                    occurred_at=_ts_ms_to_naive_utc(envelope.get("ts")),
                )
                session.add(event)
                await session.commit()
                logger.info("Saved device_registry event for %s", device_id)

        self._run_async(_write)

    def _handle_gateway_event(self, envelope: dict) -> None:
        """Log gateway lifecycle events (e.g. permit_join_opened/closed/failed).

        v1: log only.  Persistence into the events table is intentionally
        deferred until we agree how to model gateway-level events without a
        device_id.
        """
        inner = envelope.get("payload", {})
        event = inner.get("event", "unknown")
        logger.info("Gateway event: %s payload=%s", event, inner)

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

    def publish_automation_rule(
        self,
        automation_id: str,
        payload: dict,
        *,
        deleted: bool = False,
    ) -> None:
        s = self.settings
        topic = f"{self.topic_prefix}/desired/automation/{automation_id}"
        envelope = {
            "schema": "sb.v1",
            "msg_id": uuid4().hex,
            "ts": _now_ms(),
            "tenant_id": s.tenant_id,
            "site_id": s.site_id,
            "gateway_id": s.gateway_id,
            "source": "cloud",
            "payload": payload | {"deleted": deleted},
        }
        self.client.publish(topic, json.dumps(envelope), qos=0, retain=True)
        logger.info(
            "Published automation %s deleted=%s", automation_id, deleted
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
