"""
Tests for MQTT topic building and parsing.
"""

from gateway.src.topics import GatewayTopics


def test_build_and_parse_device_topics_with_type():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")

    route = topics.parse(topics.device_desired("light-01", "light"))
    assert route.kind == "device_desired"
    assert route.device_id == "light-01"
    assert route.device_type == "light"

    route = topics.parse(topics.device_reported("motion-01", "motion"))
    assert route.kind == "device_reported"
    assert route.device_id == "motion-01"
    assert route.device_type == "motion"

    route = topics.parse(topics.device_telemetry("sensor-01", "motion"))
    assert route.kind == "device_telemetry"
    assert route.device_id == "sensor-01"
    assert route.device_type == "motion"


def test_build_and_parse_command_and_ota_topics():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")

    route = topics.parse(topics.command_request("cmd-01"))
    assert route.kind == "command_request"
    assert route.command_id == "cmd-01"

    route = topics.parse(topics.ota_manifest("camp-01"))
    assert route.kind == "ota_manifest"
    assert route.campaign_id == "camp-01"


def test_build_and_parse_group_and_scene_topics():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")

    route = topics.parse(topics.group_desired("grp-01"))
    assert route.kind == "group_desired"
    assert route.group_id == "grp-01"

    route = topics.parse(topics.scene_event("scene-01"))
    assert route.kind == "scene_event"
    assert route.scene_id == "scene-01"


def test_topic_namespace_mismatch_raises():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")

    try:
        topics.parse("sb/v1/other/lab01/gw-ubuntu-01/gateway/online")
    except ValueError as exc:
        assert "namespace" in str(exc)
    else:
        raise AssertionError("Expected namespace validation to fail")


def test_subscription_filters_include_device_type_wildcard():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")
    filters = topics.subscription_filters()
    prefix = "sb/v1/hust/lab01/gw-ubuntu-01"
    assert f"{prefix}/devices/+/+/desired" in filters
    assert f"{prefix}/groups/+/desired" in filters
    assert f"{prefix}/scenes/+/desired" in filters
