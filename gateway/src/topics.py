"""
Topic builders and parsers for the sb/v1 MQTT namespace.

Device topics include device_type as a routing level:
  sb/v1/{tenant}/{site}/{gateway}/devices/{device_type}/{device_id}/...

This enables wildcard subscriptions per device family, e.g.
  sb/v1/hust/lab01/gw-ubuntu-01/devices/light/+/reported
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class TopicMatch:
    """A parsed topic route."""

    kind: str
    device_id: str | None = None
    device_type: str | None = None
    command_id: str | None = None
    campaign_id: str | None = None
    group_id: str | None = None
    scene_id: str | None = None


@dataclass(frozen=True)
class PublishPolicy:
    """Retain and QoS defaults for a topic kind."""

    qos: int
    retain: bool


PUBLISH_POLICIES = {
    "gateway_online": PublishPolicy(qos=1, retain=True),
    "gateway_health": PublishPolicy(qos=1, retain=True),
    "gateway_log": PublishPolicy(qos=0, retain=False),
    "device_registry": PublishPolicy(qos=1, retain=True),
    "device_reported": PublishPolicy(qos=1, retain=True),
    "device_desired": PublishPolicy(qos=1, retain=True),
    "device_telemetry": PublishPolicy(qos=0, retain=False),
    "device_event": PublishPolicy(qos=1, retain=False),
    "command_request": PublishPolicy(qos=1, retain=False),
    "command_reply": PublishPolicy(qos=1, retain=False),
    "ota_manifest": PublishPolicy(qos=1, retain=True),
    "ota_desired": PublishPolicy(qos=1, retain=True),
    "ota_progress": PublishPolicy(qos=1, retain=True),
    "ota_event": PublishPolicy(qos=1, retain=False),
    "group_reported": PublishPolicy(qos=1, retain=True),
    "group_desired": PublishPolicy(qos=1, retain=False),
    "scene_desired": PublishPolicy(qos=1, retain=False),
    "scene_event": PublishPolicy(qos=1, retain=False),
}


class GatewayTopics:
    """Build and parse topics for a single gateway namespace."""

    def __init__(self, tenant_id: str, site_id: str, gateway_id: str):
        self.tenant_id = tenant_id
        self.site_id = site_id
        self.gateway_id = gateway_id

    @property
    def prefix(self) -> str:
        return f"sb/v1/{self.tenant_id}/{self.site_id}/{self.gateway_id}"

    # -- Gateway ----------------------------------------------------------

    def gateway_online(self) -> str:
        return f"{self.prefix}/gateway/online"

    def gateway_health(self) -> str:
        return f"{self.prefix}/gateway/health"

    def gateway_log(self) -> str:
        return f"{self.prefix}/gateway/log"

    # -- Devices (with device_type) ---------------------------------------

    def device_registry(self, device_id: str, device_type: str = "unknown") -> str:
        return f"{self.prefix}/devices/{device_type}/{device_id}/registry"

    def device_reported(self, device_id: str, device_type: str = "unknown") -> str:
        return f"{self.prefix}/devices/{device_type}/{device_id}/reported"

    def device_desired(self, device_id: str, device_type: str = "unknown") -> str:
        return f"{self.prefix}/devices/{device_type}/{device_id}/desired"

    def device_telemetry(self, device_id: str, device_type: str = "unknown") -> str:
        return f"{self.prefix}/devices/{device_type}/{device_id}/telemetry"

    def device_event(self, device_id: str, device_type: str = "unknown") -> str:
        return f"{self.prefix}/devices/{device_type}/{device_id}/event"

    # -- Commands ---------------------------------------------------------

    def command_request(self, command_id: str) -> str:
        return f"{self.prefix}/commands/{command_id}/request"

    def command_reply(self, command_id: str) -> str:
        return f"{self.prefix}/commands/{command_id}/reply"

    # -- OTA --------------------------------------------------------------

    def ota_manifest(self, campaign_id: str) -> str:
        return f"{self.prefix}/ota/campaigns/{campaign_id}/manifest"

    def ota_desired(self, device_id: str) -> str:
        return f"{self.prefix}/ota/devices/{device_id}/desired"

    def ota_progress(self, device_id: str) -> str:
        return f"{self.prefix}/ota/devices/{device_id}/progress"

    def ota_event(self, device_id: str) -> str:
        return f"{self.prefix}/ota/devices/{device_id}/event"

    # -- Groups -----------------------------------------------------------

    def group_reported(self, group_id: str) -> str:
        return f"{self.prefix}/groups/{group_id}/reported"

    def group_desired(self, group_id: str) -> str:
        return f"{self.prefix}/groups/{group_id}/desired"

    # -- Scenes -----------------------------------------------------------

    def scene_desired(self, scene_id: str) -> str:
        return f"{self.prefix}/scenes/{scene_id}/desired"

    def scene_event(self, scene_id: str) -> str:
        return f"{self.prefix}/scenes/{scene_id}/event"

    # -- Subscription filters ---------------------------------------------

    def subscription_filters(self) -> list[str]:
        return [
            f"{self.prefix}/devices/+/+/desired",
            f"{self.prefix}/commands/+/request",
            f"{self.prefix}/ota/campaigns/+/manifest",
            f"{self.prefix}/ota/devices/+/desired",
            f"{self.prefix}/groups/+/desired",
            f"{self.prefix}/scenes/+/desired",
        ]

    # -- Parser -----------------------------------------------------------

    def parse(self, topic: str) -> TopicMatch:
        parts = topic.split("/")
        if len(parts) < 7:
            raise ValueError(f"Invalid topic: {topic}")
        if parts[:2] != ["sb", "v1"]:
            raise ValueError(f"Invalid topic prefix: {topic}")
        expected = [self.tenant_id, self.site_id, self.gateway_id]
        if parts[2:5] != expected:
            raise ValueError(f"Topic outside current namespace: {topic}")

        tail = parts[5:]

        # Gateway topics: gateway/{channel}
        if tail == ["gateway", "online"]:
            return TopicMatch(kind="gateway_online")
        if tail == ["gateway", "health"]:
            return TopicMatch(kind="gateway_health")
        if tail == ["gateway", "log"]:
            return TopicMatch(kind="gateway_log")

        # Device topics: devices/{device_type}/{device_id}/{channel}
        _device_channels = {
            "registry": "device_registry",
            "reported": "device_reported",
            "desired": "device_desired",
            "telemetry": "device_telemetry",
            "event": "device_event",
        }
        if len(tail) == 4 and tail[0] == "devices" and tail[3] in _device_channels:
            return TopicMatch(
                kind=_device_channels[tail[3]],
                device_type=tail[1],
                device_id=tail[2],
            )

        # Command topics: commands/{command_id}/{channel}
        if len(tail) == 3 and tail[0] == "commands" and tail[2] == "request":
            return TopicMatch(kind="command_request", command_id=tail[1])
        if len(tail) == 3 and tail[0] == "commands" and tail[2] == "reply":
            return TopicMatch(kind="command_reply", command_id=tail[1])

        # OTA topics: ota/campaigns/{id}/manifest, ota/devices/{id}/{channel}
        if len(tail) == 4 and tail[:2] == ["ota", "campaigns"] and tail[3] == "manifest":
            return TopicMatch(kind="ota_manifest", campaign_id=tail[2])
        _ota_channels = {"desired": "ota_desired", "progress": "ota_progress", "event": "ota_event"}
        if len(tail) == 4 and tail[:2] == ["ota", "devices"] and tail[3] in _ota_channels:
            return TopicMatch(kind=_ota_channels[tail[3]], device_id=tail[2])

        # Group topics: groups/{group_id}/{channel}
        if len(tail) == 3 and tail[0] == "groups" and tail[2] == "reported":
            return TopicMatch(kind="group_reported", group_id=tail[1])
        if len(tail) == 3 and tail[0] == "groups" and tail[2] == "desired":
            return TopicMatch(kind="group_desired", group_id=tail[1])

        # Scene topics: scenes/{scene_id}/{channel}
        if len(tail) == 3 and tail[0] == "scenes" and tail[2] == "desired":
            return TopicMatch(kind="scene_desired", scene_id=tail[1])
        if len(tail) == 3 and tail[0] == "scenes" and tail[2] == "event":
            return TopicMatch(kind="scene_event", scene_id=tail[1])

        raise ValueError(f"Unsupported topic: {topic}")
