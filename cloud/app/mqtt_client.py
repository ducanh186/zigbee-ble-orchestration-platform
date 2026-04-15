import asyncio
import json
import logging
from datetime import UTC, datetime
from uuid import uuid4

import paho.mqtt.client as mqtt

from cloud.app.config import settings as _settings

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
    """MQTT client service that bridges the cloud backend to the gateway broker.

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
        client.subscribe(f"{prefix}/commands/+/reply", qos=0)
        client.subscribe(f"{prefix}/gateway/online", qos=0)

    def _on_message(self, client, userdata, msg):
        """Route incoming MQTT messages to the appropriate handler."""
        try:
            logger.info("MQTT rx: %s (%d bytes)", msg.topic, len(msg.payload))
            payload = json.loads(msg.payload.decode("utf-8"))
            topic: str = msg.topic

            if "/devices/" in topic and topic.endswith("/reported"):
                self._handle_reported(topic, payload)
            elif "/devices/" in topic and topic.endswith("/telemetry"):
                self._handle_reported(topic, payload)
            elif "/devices/" in topic and topic.endswith("/event"):
                self._handle_event(topic, payload)
            elif "/commands/" in topic and topic.endswith("/reply"):
                self._handle_command_reply(topic, payload)
            elif topic.endswith("/gateway/online"):
                self._handle_gateway_online(payload)
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
        """Handle device event -- insert event row."""
        parts = topic.split("/")
        # Topic: sb/v1/{t}/{s}/{g}/devices/{device_type}/{device_id}/event
        devices_idx = parts.index("devices")
        device_id = parts[devices_idx + 2]
        inner = envelope.get("payload", {})

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Event

            async with self._db_session_factory() as session:
                event = Event(
                    device_id=device_id,
                    event_type=inner.get(
                        "event", inner.get("event_type", "unknown")
                    ),
                    payload=inner,
                    occurred_at=_ts_ms_to_naive_utc(envelope.get("ts")),
                )
                session.add(event)
                await session.commit()
                logger.info("Saved event for %s", device_id)

        self._run_async(_write)

    def _handle_command_reply(self, topic: str, envelope: dict) -> None:
        """Handle command reply -- update command status."""
        parts = topic.split("/")
        cmd_id_idx = parts.index("commands") + 1
        command_id = parts[cmd_id_idx]
        inner = envelope.get("payload", {})

        async def _write():
            if not self._db_session_factory:
                return
            from cloud.app.models import Command
            from sqlalchemy import select

            async with self._db_session_factory() as session:
                result = await session.execute(
                    select(Command).where(Command.id == command_id)
                )
                cmd = result.scalar_one_or_none()
                if cmd:
                    cmd.status = inner.get("status", cmd.status)
                    cmd.reason = inner.get("reason")
                    await session.commit()
                    logger.info(
                        "Updated command %s status=%s", command_id, cmd.status
                    )

        self._run_async(_write)

    def _handle_gateway_online(self, envelope: dict) -> None:
        inner = envelope.get("payload", {})
        status = inner.get("value", "unknown")
        logger.info("Gateway status: %s", status)

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
