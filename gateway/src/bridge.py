"""
Bridge core for MQTT <-> IPC NDJSON routing.
"""

from __future__ import annotations

import logging
from typing import Any, Protocol

from .config import BridgeSettings
from .ipc import UnixSocketIPCServer
from .lifecycle import CommandLifecycleTracker, PendingCommand
from .models import (
    CommandReplyPayload,
    CommandRequestPayload,
    GatewayOnlinePayload,
    IPCRecord,
    MQTTEnvelope,
    OTACampaignManifestPayload,
    OTADeviceDesiredPayload,
)
from .ota import OTAArtifactManager, OTAStageError
from .topics import GatewayTopics, PUBLISH_POLICIES


logger = logging.getLogger(__name__)


class MQTTPublisher(Protocol):
    """Minimal publisher interface used by the bridge core."""

    def publish(self, topic: str, payload: str, qos: int = 0, retain: bool = False):  # pragma: no cover - protocol
        ...


class GatewayBridge:
    """Contract-aware bridge between MQTT and the local adapter IPC socket."""

    def __init__(
        self,
        settings: BridgeSettings,
        mqtt_publisher: MQTTPublisher,
        ipc_server: UnixSocketIPCServer,
    ):
        self.settings = settings
        self.mqtt_publisher = mqtt_publisher
        self.ipc_server = ipc_server
        self.topics = GatewayTopics(settings.tenant_id, settings.site_id, settings.gateway_id)
        self.ota_manager = OTAArtifactManager(settings.ota_dir)
        self.lifecycle = CommandLifecycleTracker(settings.command_timeout_ms, self._handle_command_timeout)

        self._cached_desired: dict[str, MQTTEnvelope] = {}
        self._cached_manifests: dict[str, OTACampaignManifestPayload] = {}

    def start(self) -> None:
        self.lifecycle.start()

    def stop(self) -> None:
        self.lifecycle.stop()

    def build_envelope(
        self,
        *,
        source: str,
        payload: dict[str, Any],
        correlation_id: str | None = None,
        trace_id: str | None = None,
    ) -> MQTTEnvelope:
        """Create a validated MQTT envelope in the configured namespace."""

        return MQTTEnvelope(
            tenant_id=self.settings.tenant_id,
            site_id=self.settings.site_id,
            gateway_id=self.settings.gateway_id,
            source=source,
            trace_id=trace_id,
            correlation_id=correlation_id,
            payload=payload,
        )

    def publish_message(
        self,
        topic: str,
        *,
        source: str,
        payload: dict[str, Any],
        kind: str,
        correlation_id: str | None = None,
        trace_id: str | None = None,
    ) -> None:
        """Publish a namespaced MQTT message using the topic policy table."""

        policy = PUBLISH_POLICIES[kind]
        envelope = self.build_envelope(
            source=source,
            payload=payload,
            correlation_id=correlation_id,
            trace_id=trace_id,
        )
        self.mqtt_publisher.publish(
            topic,
            envelope.model_dump_json(exclude_none=True, by_alias=True),
            qos=policy.qos,
            retain=policy.retain,
        )

    def publish_gateway_online(self, value: str) -> None:
        """Publish the retained gateway/online status."""

        payload = GatewayOnlinePayload(value=value).model_dump(mode="json")
        self.publish_message(
            self.topics.gateway_online(),
            source="gateway",
            payload=payload,
            kind="gateway_online",
        )

    def publish_gateway_health(self, payload: dict[str, Any]) -> None:
        """Publish retained gateway health information."""

        self.publish_message(
            self.topics.gateway_health(),
            source="gateway",
            payload=payload,
            kind="gateway_health",
        )

    def publish_gateway_log(self, event: str, message: str, *, level: str = "INFO", details: dict[str, Any] | None = None) -> None:
        """Publish a non-retained gateway log message."""

        payload: dict[str, Any] = {"event": event, "message": message, "level": level}
        if details:
            payload.update(details)
        self.publish_message(
            self.topics.gateway_log(),
            source="gateway",
            payload=payload,
            kind="gateway_log",
        )

    def handle_mqtt_message(self, topic: str, payload: str) -> None:
        """Route an inbound MQTT envelope to IPC or OTA staging logic."""

        route = self.topics.parse(topic)
        envelope = MQTTEnvelope.model_validate_json(payload)
        self._validate_envelope_namespace(envelope)

        if route.kind == "device_desired":
            self._handle_device_desired(route.device_id, envelope)
        elif route.kind == "command_request":
            self._handle_command_request(route.command_id, envelope)
        elif route.kind == "ota_manifest":
            self._handle_ota_manifest(route.campaign_id, envelope)
        elif route.kind == "ota_desired":
            self._handle_ota_device_desired(route.device_id, envelope)
        else:
            raise ValueError(f"Unsupported inbound MQTT topic kind: {route.kind}")

    def handle_ipc_record(self, record: IPCRecord) -> None:
        """Publish MQTT messages from adapter-originated IPC records."""

        if record.kind == "registry":
            self._publish_device_topic("device_registry", self.topics.device_registry, record)
        elif record.kind == "reported":
            self._publish_device_topic("device_reported", self.topics.device_reported, record)
        elif record.kind == "event":
            self._publish_device_topic("device_event", self.topics.device_event, record)
        elif record.kind == "gateway_health":
            self.publish_message(
                self.topics.gateway_health(),
                source=record.source,
                payload=record.payload,
                kind="gateway_health",
                correlation_id=record.correlation_id,
                trace_id=record.trace_id,
            )
        elif record.kind == "gateway_log":
            self.publish_message(
                self.topics.gateway_log(),
                source=record.source,
                payload=record.payload,
                kind="gateway_log",
                correlation_id=record.correlation_id,
                trace_id=record.trace_id,
            )
        elif record.kind == "command_reply":
            self._handle_command_reply(record)
        elif record.kind == "ota_progress":
            self._publish_ota_topic("ota_progress", self.topics.ota_progress, record)
        elif record.kind == "ota_event":
            self._publish_ota_topic("ota_event", self.topics.ota_event, record)
        else:
            raise ValueError(f"Unsupported adapter IPC kind: {record.kind}")

    def replay_cached_state(self) -> None:
        """Replay retained desired state and manifests to a newly connected adapter."""

        for envelope in self._cached_desired.values():
            self._send_ipc_record(
                IPCRecord(
                    kind="desired",
                    source=envelope.source,
                    trace_id=envelope.trace_id,
                    correlation_id=envelope.correlation_id,
                    device_id=envelope.payload.get("device_id"),
                    payload=envelope.payload,
                ),
                failure_reason="failed to replay desired state after adapter reconnect",
            )

        for manifest in self._cached_manifests.values():
            staged = self.ota_manager.get_staged(manifest.campaign_id)
            payload = manifest.model_dump(mode="json", exclude_none=True)
            if staged is not None:
                payload["local_artifact_path"] = str(staged.local_path)
            self._send_ipc_record(
                IPCRecord(
                    kind="ota_manifest",
                    source="gateway",
                    campaign_id=manifest.campaign_id,
                    payload=payload,
                ),
                failure_reason="failed to replay OTA manifest after adapter reconnect",
            )

    def _validate_envelope_namespace(self, envelope: MQTTEnvelope) -> None:
        expected = (self.settings.tenant_id, self.settings.site_id, self.settings.gateway_id)
        actual = (envelope.tenant_id, envelope.site_id, envelope.gateway_id)
        if actual != expected:
            raise ValueError(f"Envelope namespace mismatch: expected {expected}, got {actual}")

    def _publish_device_topic(self, kind: str, topic_builder, record: IPCRecord) -> None:
        device_id = record.device_id or record.payload.get("device_id")
        if not device_id:
            raise ValueError(f"{record.kind} IPC records must include device_id")
        payload = dict(record.payload)
        payload.setdefault("device_id", device_id)
        self.publish_message(
            topic_builder(device_id),
            source=record.source,
            payload=payload,
            kind=kind,
            correlation_id=record.correlation_id,
            trace_id=record.trace_id,
        )

    def _publish_ota_topic(self, kind: str, topic_builder, record: IPCRecord) -> None:
        device_id = record.device_id or record.payload.get("device_id")
        if not device_id:
            raise ValueError(f"{record.kind} IPC records must include device_id")
        payload = dict(record.payload)
        payload.setdefault("device_id", device_id)
        self.publish_message(
            topic_builder(device_id),
            source=record.source,
            payload=payload,
            kind=kind,
            correlation_id=record.correlation_id,
            trace_id=record.trace_id,
        )

    def _handle_device_desired(self, device_id: str | None, envelope: MQTTEnvelope) -> None:
        if not device_id:
            raise ValueError("Desired topic is missing device_id")
        payload = dict(envelope.payload)
        payload.setdefault("device_id", device_id)
        desired_envelope = envelope.model_copy(update={"payload": payload})
        self._cached_desired[device_id] = desired_envelope

        self._send_ipc_record(
            IPCRecord(
                kind="desired",
                source=envelope.source,
                trace_id=envelope.trace_id,
                correlation_id=envelope.correlation_id,
                device_id=device_id,
                payload=payload,
            ),
            failure_reason="failed to forward desired state to adapter",
        )

    def _handle_command_request(self, command_id: str | None, envelope: MQTTEnvelope) -> None:
        if not command_id:
            raise ValueError("Command topic is missing command_id")

        payload = CommandRequestPayload.model_validate(envelope.payload)
        timeout_ms = payload.timeout_ms or self.settings.command_timeout_ms

        self._publish_command_status(command_id, "accepted", payload.device_id, trace_id=envelope.trace_id)
        self._publish_command_status(command_id, "queued", payload.device_id, trace_id=envelope.trace_id)

        record = IPCRecord(
            kind="command_request",
            source=envelope.source,
            trace_id=envelope.trace_id,
            correlation_id=command_id,
            device_id=payload.device_id,
            command_id=command_id,
            payload=envelope.payload,
        )
        if not self.ipc_server.send(record):
            self._publish_command_status(
                command_id,
                "failed",
                payload.device_id,
                reason="adapter_unavailable",
                trace_id=envelope.trace_id,
            )
            return

        self._publish_command_status(
            command_id,
            "sent",
            payload.device_id,
            trace_id=envelope.trace_id,
            timeout_ms=timeout_ms,
        )

    def _handle_command_reply(self, record: IPCRecord) -> None:
        command_id = record.command_id or record.correlation_id
        if not command_id:
            raise ValueError("command_reply IPC records must include command_id")

        status = record.status or record.payload.get("status")
        if not status:
            raise ValueError("command_reply IPC records must include status")

        device_id = record.device_id or record.payload.get("device_id")
        changed = self.lifecycle.transition(command_id, status, device_id=device_id, trace_id=record.trace_id)
        if not changed:
            return

        payload = dict(record.payload)
        payload["status"] = status
        if device_id:
            payload.setdefault("device_id", device_id)

        self.publish_message(
            self.topics.command_reply(command_id),
            source=record.source,
            payload=payload,
            kind="command_reply",
            correlation_id=command_id,
            trace_id=record.trace_id,
        )

    def _handle_ota_manifest(self, campaign_id: str | None, envelope: MQTTEnvelope) -> None:
        if not campaign_id:
            raise ValueError("Manifest topic is missing campaign_id")

        manifest = OTACampaignManifestPayload.model_validate(envelope.payload)
        if manifest.campaign_id != campaign_id:
            raise ValueError("Campaign ID in topic and payload do not match")

        staged = self.ota_manager.stage_manifest(manifest)
        self._cached_manifests[campaign_id] = manifest

        payload = manifest.model_dump(mode="json", exclude_none=True)
        payload["local_artifact_path"] = str(staged.local_path)
        self._send_ipc_record(
            IPCRecord(
                kind="ota_manifest",
                source=envelope.source,
                trace_id=envelope.trace_id,
                correlation_id=envelope.correlation_id,
                campaign_id=campaign_id,
                payload=payload,
            ),
            failure_reason="failed to forward OTA manifest to adapter",
        )

    def _handle_ota_device_desired(self, device_id: str | None, envelope: MQTTEnvelope) -> None:
        if not device_id:
            raise ValueError("OTA desired topic is missing device_id")

        desired = OTADeviceDesiredPayload.model_validate(envelope.payload)
        manifest = self._cached_manifests.get(desired.campaign_id)
        if manifest is None:
            self.publish_message(
                self.topics.ota_event(device_id),
                source="gateway",
                payload={
                    "device_id": device_id,
                    "campaign_id": desired.campaign_id,
                    "event": "artifact_unavailable",
                    "reason": "campaign_manifest_missing",
                },
                kind="ota_event",
                correlation_id=desired.campaign_id,
                trace_id=envelope.trace_id,
            )
            return

        try:
            self.publish_message(
                self.topics.ota_progress(device_id),
                source="gateway",
                payload={
                    "device_id": device_id,
                    "campaign_id": desired.campaign_id,
                    "status": "staging",
                    "progress_pct": 0,
                },
                kind="ota_progress",
                correlation_id=desired.campaign_id,
                trace_id=envelope.trace_id,
            )
            staged = self.ota_manager.stage_manifest(manifest)
        except OTAStageError as exc:
            self.publish_message(
                self.topics.ota_event(device_id),
                source="gateway",
                payload={
                    "device_id": device_id,
                    "campaign_id": desired.campaign_id,
                    "event": "artifact_stage_failed",
                    "reason": str(exc),
                },
                kind="ota_event",
                correlation_id=desired.campaign_id,
                trace_id=envelope.trace_id,
            )
            return

        self.publish_message(
            self.topics.ota_progress(device_id),
            source="gateway",
            payload={
                "device_id": device_id,
                "campaign_id": desired.campaign_id,
                "status": "staged",
                "progress_pct": 100,
            },
            kind="ota_progress",
            correlation_id=desired.campaign_id,
            trace_id=envelope.trace_id,
        )

        payload = dict(envelope.payload)
        payload["device_id"] = device_id
        payload["local_artifact_path"] = str(staged.local_path)
        payload["manifest"] = manifest.model_dump(mode="json", exclude_none=True)

        self._send_ipc_record(
            IPCRecord(
                kind="ota_desired",
                source=envelope.source,
                trace_id=envelope.trace_id,
                correlation_id=desired.campaign_id,
                device_id=device_id,
                campaign_id=desired.campaign_id,
                payload=payload,
            ),
            failure_reason="failed to forward OTA desired state to adapter",
        )

    def _publish_command_status(
        self,
        command_id: str,
        status: str,
        device_id: str | None,
        *,
        reason: str | None = None,
        trace_id: str | None = None,
        timeout_ms: int | None = None,
    ) -> None:
        changed = self.lifecycle.transition(
            command_id,
            status,
            device_id=device_id,
            trace_id=trace_id,
            timeout_ms=timeout_ms,
        )
        if not changed:
            return

        payload = CommandReplyPayload(status=status, device_id=device_id, reason=reason).model_dump(
            mode="json",
            exclude_none=True,
        )
        self.publish_message(
            self.topics.command_reply(command_id),
            source="gateway",
            payload=payload,
            kind="command_reply",
            correlation_id=command_id,
            trace_id=trace_id,
        )

    def _handle_command_timeout(self, pending: PendingCommand) -> None:
        payload = CommandReplyPayload(
            status="timeout",
            device_id=pending.device_id,
            reason="adapter_timeout",
        ).model_dump(mode="json", exclude_none=True)
        self.publish_message(
            self.topics.command_reply(pending.command_id),
            source="gateway",
            payload=payload,
            kind="command_reply",
            correlation_id=pending.command_id,
            trace_id=pending.trace_id,
        )

    def _send_ipc_record(self, record: IPCRecord, *, failure_reason: str) -> None:
        if not self.ipc_server.send(record):
            self.publish_gateway_log(
                "ipc_dispatch_failed",
                failure_reason,
                level="ERROR",
                details={"kind": record.kind},
            )
