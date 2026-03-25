"""
Process wiring and runtime entrypoint for the bridge service.
"""

from __future__ import annotations

import argparse
import logging
import os
import signal
import threading
from typing import Any

import paho.mqtt.client as mqtt

from .bridge import GatewayBridge
from .config import BridgeSettings, load_settings
from .ipc import UnixSocketIPCServer
from .models import GatewayOnlinePayload


logger = logging.getLogger("gateway")


class GatewayService:
    """Own the paho MQTT client, IPC server, and runtime lifecycle."""

    def __init__(self, settings: BridgeSettings):
        self.settings = settings
        self._stop_event = threading.Event()

        self.ipc_server = UnixSocketIPCServer(
            settings.ipc_socket_path,
            on_record=self._on_ipc_record,
            on_connection_change=self._on_ipc_connection_change,
        )
        self.mqtt_client = mqtt.Client()
        self.bridge = GatewayBridge(settings, self.mqtt_client, self.ipc_server)

        self._mqtt_connected = False
        self._configure_mqtt_client()

    def start(self) -> None:
        """Start the IPC server and MQTT loop."""

        if os.name != "posix":
            raise RuntimeError("The bridge service supports Linux/POSIX runtimes only")

        self.bridge.start()
        self.ipc_server.start()
        self._install_signal_handlers()

        logger.info(
            "Starting bridge for namespace sb/v1/%s/%s/%s",
            self.settings.tenant_id,
            self.settings.site_id,
            self.settings.gateway_id,
        )
        self.mqtt_client.connect(self.settings.mqtt_host, self.settings.mqtt_port, keepalive=self.settings.mqtt_keepalive)
        self.mqtt_client.loop_start()
        self._stop_event.wait()

    def stop(self) -> None:
        """Stop the service and cleanly disconnect."""

        if self._stop_event.is_set():
            return

        self._stop_event.set()
        try:
            if self._mqtt_connected:
                self.bridge.publish_gateway_online("offline")
        except Exception:  # pragma: no cover - best effort shutdown path
            logger.exception("Failed to publish graceful offline state")
        finally:
            self.mqtt_client.loop_stop()
            try:
                self.mqtt_client.disconnect()
            except Exception:  # pragma: no cover - best effort shutdown path
                pass
            self.ipc_server.stop()
            self.bridge.stop()

    def _configure_mqtt_client(self) -> None:
        if self.settings.mqtt_auth_enabled:
            self.mqtt_client.username_pw_set(self.settings.mqtt_username, self.settings.mqtt_password)

        if self.settings.mqtt_tls_enabled:
            self.mqtt_client.tls_set(ca_certs=self.settings.mqtt_tls_ca_cert or None)
            self.mqtt_client.tls_insecure_set(self.settings.mqtt_tls_insecure)

        offline_envelope = self.bridge.build_envelope(
            source="gateway",
            payload=GatewayOnlinePayload(value="offline").model_dump(mode="json"),
        )
        self.mqtt_client.will_set(
            self.bridge.topics.gateway_online(),
            offline_envelope.model_dump_json(by_alias=True),
            qos=1,
            retain=True,
        )

        self.mqtt_client.on_connect = self._on_mqtt_connect
        self.mqtt_client.on_disconnect = self._on_mqtt_disconnect
        self.mqtt_client.on_message = self._on_mqtt_message

    def _install_signal_handlers(self) -> None:
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _signal_handler(self, signum: int, frame: Any) -> None:
        logger.info("Received signal %s, shutting down", signum)
        self.stop()

    def _on_mqtt_connect(self, client, userdata, flags, reason_code, properties=None):  # noqa: ANN001
        rc = int(reason_code)
        if rc != 0:
            raise RuntimeError(f"MQTT connection failed with code {rc}")

        self._mqtt_connected = True
        for topic_filter in self.bridge.topics.subscription_filters():
            client.subscribe(topic_filter, qos=1)
            logger.info("Subscribed to %s", topic_filter)

        self.bridge.publish_gateway_online("online")
        self.bridge.publish_gateway_health(
            {
                "status": "ready",
                "ipc_connected": self.ipc_server.is_connected,
                "ota_dir": str(self.settings.ota_dir),
            }
        )
        if self.ipc_server.is_connected:
            self.bridge.replay_cached_state()

    def _on_mqtt_disconnect(self, client, userdata, reason_code, properties=None):  # noqa: ANN001
        self._mqtt_connected = False
        logger.warning("MQTT disconnected with reason code %s", reason_code)

    def _on_mqtt_message(self, client, userdata, msg):  # noqa: ANN001
        try:
            payload = msg.payload.decode("utf-8")
            if msg.retain and "/commands/" in msg.topic and msg.topic.endswith("/request"):
                logger.info("Ignoring retained command request on %s", msg.topic)
                return
            self.bridge.handle_mqtt_message(msg.topic, payload)
        except Exception as exc:
            logger.exception("Failed to handle MQTT message on %s", msg.topic)
            if self._mqtt_connected:
                self.bridge.publish_gateway_log(
                    "mqtt_message_error",
                    str(exc),
                    level="ERROR",
                    details={"topic": msg.topic},
                )

    def _on_ipc_record(self, record) -> None:  # noqa: ANN001
        try:
            self.bridge.handle_ipc_record(record)
        except Exception as exc:
            logger.exception("Failed to handle IPC record %s", record.kind)
            if self._mqtt_connected:
                self.bridge.publish_gateway_log(
                    "ipc_record_error",
                    str(exc),
                    level="ERROR",
                    details={"kind": record.kind},
                )

    def _on_ipc_connection_change(self, connected: bool) -> None:
        logger.info("IPC adapter connection changed: connected=%s", connected)
        if not self._mqtt_connected:
            return

        self.bridge.publish_gateway_health(
            {
                "status": "ready" if connected else "degraded",
                "ipc_connected": connected,
                "ota_dir": str(self.settings.ota_dir),
            }
        )
        if connected:
            self.bridge.replay_cached_state()


def configure_logging(settings: BridgeSettings) -> None:
    """Configure console logging and optional file logging."""

    handlers: list[logging.Handler] = [logging.StreamHandler()]
    if settings.log_file:
        handlers.append(logging.FileHandler(settings.log_file, encoding="utf-8"))

    logging.basicConfig(
        level=getattr(logging, settings.log_level),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=handlers,
    )


def parse_args() -> argparse.Namespace:
    """Parse CLI options for the bridge service."""

    parser = argparse.ArgumentParser(description="Z3Gateway-native MQTT <-> IPC bridge")
    parser.add_argument("--env-file", type=str, help="Optional path to a .env file")
    return parser.parse_args()


def main() -> None:
    """CLI entrypoint."""

    args = parse_args()
    settings = load_settings(args.env_file)
    configure_logging(settings)

    service = GatewayService(settings)
    try:
        service.start()
    except KeyboardInterrupt:
        pass
    except Exception as exc:
        logger.error("Service error: %s", exc)
        raise SystemExit(1) from exc
    finally:
        service.stop()
