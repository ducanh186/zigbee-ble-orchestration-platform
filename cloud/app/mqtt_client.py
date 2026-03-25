import asyncio
import json
import logging
from datetime import UTC, datetime
from uuid import uuid4

import paho.mqtt.client as mqtt

from cloud.app.config import settings as _settings

logger = logging.getLogger(__name__)


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
        prefix = self.topic_prefix
        client.subscribe(f"{prefix}/devices/+/reported", qos=1)
        client.subscribe(f"{prefix}/devices/+/event", qos=1)
        client.subscribe(f"{prefix}/commands/+/reply", qos=1)
        client.subscribe(f"{prefix}/gateway/online", qos=1)

    def _on_message(self, client, userdata, msg):
        """Route incoming MQTT messages to the appropriate handler."""
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
            topic: str = msg.topic

            if "/devices/" in topic and topic.endswith("/reported"):
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
        device_id_idx = parts.index("devices") + 1
        device_id = parts[device_id_idx]
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
                        device_type=inner.get("device_type", "unknown"),
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
                    reported_at=datetime.fromisoformat(
                        envelope.get("ts", datetime.now(UTC).isoformat())
                    ),
                )
                session.add(state_row)
                await session.commit()
                logger.info("Saved reported state for %s", device_id)

        self._run_async(_write)

    def _handle_event(self, topic: str, envelope: dict) -> None:
        """Handle device event -- insert event row."""
        parts = topic.split("/")
        device_id_idx = parts.index("devices") + 1
        device_id = parts[device_id_idx]
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
                    occurred_at=datetime.fromisoformat(
                        envelope.get("ts", datetime.now(UTC).isoformat())
                    ),
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
            "ts": datetime.now(UTC).replace(microsecond=0).isoformat(),
            "tenant_id": s.tenant_id,
            "site_id": s.site_id,
            "gateway_id": s.gateway_id,
            "source": "cloud",
            "correlation_id": command_id,
            "payload": {
                "device_id": device_id,
                "op": op,
                "target": target,
                "timeout_ms": timeout_ms,
            },
        }
        self.client.publish(topic, json.dumps(envelope), qos=1)
        logger.info("Published command %s for %s", command_id, device_id)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _run_async(coro_func) -> None:
        """Schedule an async coroutine from a synchronous paho callback."""
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.ensure_future(coro_func())
            else:
                loop.run_until_complete(coro_func())
        except RuntimeError:
            asyncio.run(coro_func())


# Module-level singleton used across the application.
mqtt_service = MQTTService()
