"""
Tests for MQTT topic building and parsing.
"""

from gateway.src.topics import GatewayTopics


def test_build_and_parse_topics():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")

    route = topics.parse(topics.device_desired("light-01"))
    assert route.kind == "device_desired"
    assert route.device_id == "light-01"

    route = topics.parse(topics.command_request("cmd-01"))
    assert route.kind == "command_request"
    assert route.command_id == "cmd-01"

    route = topics.parse(topics.ota_manifest("camp-01"))
    assert route.kind == "ota_manifest"
    assert route.campaign_id == "camp-01"


def test_topic_namespace_mismatch_raises():
    topics = GatewayTopics("hust", "lab01", "gw-ubuntu-01")

    try:
        topics.parse("sb/v1/other/lab01/gw-ubuntu-01/gateway/online")
    except ValueError as exc:
        assert "namespace" in str(exc)
    else:
        raise AssertionError("Expected namespace validation to fail")
