"""Tests for Phase 3.4 Pydantic validation schemas."""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from cloud.app.schemas import (
    AutomationCreate,
    EnvironmentReportedState,
    LightCommandTarget,
    LightReportedPayload,
    LightReportedState,
    SwitchEventPayload,
    SwitchReportedState,
    translate_command_for_gateway,
    validate_event_payload,
    validate_reported_payload,
)


# ---- Automation contracts ----

class TestAutomationContracts:
    def test_existing_event_rule_gets_canonical_discriminators(self):
        body = AutomationCreate(
            name="Motion turns on light",
            trigger={
                "device_id": "motion-1",
                "device_type": "motion",
                "event": "occupancy_changed",
                "state": {"occupancy": "occupied"},
            },
            actions=[
                {
                    "device_id": "light-1",
                    "device_type": "light",
                    "command": "on",
                }
            ],
        )

        assert body.trigger["type"] == "device_event"
        assert body.actions[0]["type"] == "device_command"

    def test_sensor_threshold_rejects_out_of_range_value(self):
        with pytest.raises(ValidationError, match="temperature_c threshold"):
            AutomationCreate(
                name="Invalid temperature",
                trigger={
                    "type": "sensor_threshold",
                    "device_id": "environment-1",
                    "device_type": "environment",
                    "metric": "temperature_c",
                    "operator": "gte",
                    "threshold": 100,
                },
                actions=[
                    {
                        "type": "device_command",
                        "device_id": "light-1",
                        "device_type": "light",
                        "command": "on",
                    }
                ],
            )

    def test_scene_action_accepts_light_scene_identity(self):
        body = AutomationCreate(
            name="Scheduled lab scene",
            trigger_type="schedule",
            schedule_cron="0 7 * * 1-5",
            trigger={"type": "schedule"},
            actions=[
                {
                    "type": "scene_activate",
                    "group_id": "group-lab",
                    "scene_id": "scene-all-on",
                }
            ],
        )

        assert body.actions[0] == {
            "type": "scene_activate",
            "group_id": "group-lab",
            "scene_id": "scene-all-on",
        }


class TestEnvironmentReportedState:
    def test_accepts_partial_temperature_report(self):
        state = EnvironmentReportedState(
            temperature_c=28.5,
            sensor="dht11",
            reachable=True,
        )
        assert state.temperature_c == 28.5
        assert state.humidity_percent is None

    def test_rejects_out_of_range_humidity(self):
        with pytest.raises(ValidationError):
            EnvironmentReportedState(
                humidity_percent=101,
                reachable=True,
            )


# ---- LightReportedState ----

class TestLightReportedState:
    def test_valid(self):
        s = LightReportedState(power="on", level=180, reachable=True)
        assert s.power.value == "on"
        assert s.level == 180

    def test_invalid_power(self):
        with pytest.raises(ValidationError):
            LightReportedState(power="blink", level=0, reachable=True)

    def test_level_out_of_range(self):
        with pytest.raises(ValidationError):
            LightReportedState(power="on", level=300, reachable=True)

    def test_missing_reachable(self):
        with pytest.raises(ValidationError):
            LightReportedState(power="on", level=0)


# ---- LightReportedPayload ----

class TestLightReportedPayload:
    def test_valid_full(self):
        p = LightReportedPayload(
            device_id="light-01",
            device_type="light",
            eui64="00124b0001aa22bb",
            nwk_addr="0x4F2A",
            state={"power": "on", "level": 180, "reachable": True},
        )
        assert p.device_type == "light"
        assert p.state.power.value == "on"

    def test_wrong_device_type(self):
        with pytest.raises(ValidationError):
            LightReportedPayload(
                device_id="light-01",
                device_type="switch",
                state={"power": "on", "level": 0, "reachable": True},
            )


# ---- SwitchEventPayload ----

class TestSwitchEventPayload:
    def test_valid(self):
        p = SwitchEventPayload(
            device_id="switch-01",
            device_type="switch",
            event="toggle",
            eui64="00124b0001bb33cc",
        )
        assert p.event == "toggle"

    def test_wrong_event(self):
        with pytest.raises(ValidationError):
            SwitchEventPayload(
                device_id="switch-01",
                device_type="switch",
                event="double_press",
            )

    def test_wrong_device_type(self):
        with pytest.raises(ValidationError):
            SwitchEventPayload(
                device_id="switch-01",
                device_type="light",
                event="toggle",
            )


# ---- SwitchReportedState ----

class TestSwitchReportedState:
    def test_valid_minimal(self):
        s = SwitchReportedState(reachable=True)
        assert s.battery is None

    def test_valid_with_battery(self):
        s = SwitchReportedState(reachable=True, battery=87)
        assert s.battery == 87

    def test_battery_out_of_range(self):
        with pytest.raises(ValidationError):
            SwitchReportedState(reachable=True, battery=150)


# ---- LightCommandTarget ----

class TestLightCommandTarget:
    def test_valid_on(self):
        t = LightCommandTarget(endpoint=1, cluster_id="0x0006", command="on")
        assert t.command == "on"

    def test_valid_off(self):
        t = LightCommandTarget(endpoint=1, cluster_id="0x0006", command="off")
        assert t.command == "off"

    def test_valid_set_level(self):
        t = LightCommandTarget(endpoint=1, cluster_id="0x0008", command="set_level")
        assert t.command == "set_level"

    def test_invalid_cluster(self):
        with pytest.raises(ValidationError):
            LightCommandTarget(endpoint=1, cluster_id="0x0406", command="on")

    def test_wrong_command_for_cluster(self):
        with pytest.raises(ValidationError):
            LightCommandTarget(endpoint=1, cluster_id="0x0008", command="on")


# ---- validate_reported_payload ----

class TestValidateReportedPayload:
    def test_light_valid(self):
        inner = {
            "device_id": "light-01",
            "device_type": "light",
            "state": {"power": "on", "level": 100, "reachable": True},
        }
        result = validate_reported_payload("light", inner)
        assert result is not None
        assert result["state"]["power"] == "on"

    def test_light_invalid_returns_none(self):
        inner = {
            "device_id": "light-01",
            "device_type": "light",
            "state": {"power": "blink"},
        }
        result = validate_reported_payload("light", inner)
        assert result is None

    def test_unknown_type_passthrough(self):
        inner = {"device_id": "x", "something": "else"}
        result = validate_reported_payload("lock", inner)
        assert result == inner


# ---- validate_event_payload ----

class TestValidateEventPayload:
    def test_switch_valid(self):
        inner = {
            "device_id": "switch-01",
            "device_type": "switch",
            "event": "toggle",
        }
        result = validate_event_payload("switch", inner)
        assert result is not None
        assert result["event"] == "toggle"

    def test_switch_invalid_returns_none(self):
        inner = {
            "device_id": "switch-01",
            "device_type": "switch",
            "event": "invalid_event",
        }
        result = validate_event_payload("switch", inner)
        assert result is None

    def test_unknown_type_passthrough(self):
        inner = {"device_id": "x", "event": "something"}
        result = validate_event_payload("motion", inner)
        assert result == inner


class TestValidateSensorPayloads:
    def test_validate_reported_payload_accepts_sensor_kind2(self):
        out = validate_reported_payload(
            "sensor",
            {
                "sensor_kind": 2,
                "sensor": "environment",
                "state": {"temperature_c": 28.5, "humidity_percent": 48},
            },
        )
        assert out is not None
        assert out["state"]["temperature_c"] == 28.5

    def test_validate_reported_payload_sensor_kind2_invalid_state_returns_none(self):
        # humidity_percent > 100 is invalid
        out = validate_reported_payload(
            "sensor",
            {
                "sensor_kind": 2,
                "sensor": "environment",
                "state": {"humidity_percent": 999},
            },
        )
        assert out is None

    def test_validate_event_payload_accepts_sensor_occupancy(self):
        out = validate_event_payload(
            "sensor",
            {"sensor_kind": 1, "event": "occupancy_changed", "occupancy": "occupied"},
        )
        assert out is not None

    def test_validate_reported_payload_sensor_unknown_kind_passthrough(self):
        inner = {"sensor_kind": 3, "state": {"flame": True}}
        out = validate_reported_payload("sensor", inner)
        assert out == inner

    def test_validate_reported_payload_sensor_kind2_missing_state_returns_none(self):
        # kind-2 with no `state` key must be rejected (malformed payload)
        out = validate_reported_payload("sensor", {"sensor_kind": 2})
        assert out is None


# ---- translate_command_for_gateway ----

class TestTranslateCommandForGateway:
    def test_raw_passthrough(self):
        target = {"endpoint": 1, "cluster_id": "0x0006", "command": "on"}
        op, t = translate_command_for_gateway("light", "device.command", target)
        assert op == "device.command"
        assert t is target

    def test_raw_invalid_target_raises(self):
        with pytest.raises((ValueError, ValidationError)):
            translate_command_for_gateway(
                "light", "device.command",
                {"endpoint": 1, "cluster_id": "0x9999", "command": "on"},
            )

    def test_user_friendly_power_on(self):
        op, t = translate_command_for_gateway("light", "set", {"power": "on"})
        assert op == "device.command"
        assert t == {"endpoint": 1, "cluster_id": "0x0006", "command": "on"}

    def test_user_friendly_power_off(self):
        op, t = translate_command_for_gateway("light", "set", {"power": "off"})
        assert op == "device.command"
        assert t == {"endpoint": 1, "cluster_id": "0x0006", "command": "off"}

    def test_user_friendly_level(self):
        op, t = translate_command_for_gateway("light", "set", {"level": 180})
        assert op == "device.command"
        assert t == {
            "endpoint": 1,
            "cluster_id": "0x0008",
            "command": "set_level",
            "level": 180,
        }

    def test_user_friendly_empty_target_raises(self):
        with pytest.raises((ValueError, ValidationError)):
            translate_command_for_gateway("light", "set", {})

    def test_switch_rejects_commands(self):
        with pytest.raises(ValueError, match="does not accept commands"):
            translate_command_for_gateway("switch", "set", {"power": "on"})

    def test_unknown_type_rejects(self):
        with pytest.raises(ValueError, match="does not accept commands"):
            translate_command_for_gateway("motion", "set", {"power": "on"})

    def test_set_room_sensor(self):
        op, t = translate_command_for_gateway(
            "sensor", "device.set_room", {"room_id": "room-2"}
        )
        assert op == "device.set_room"
        assert t == {"room_id": "room-2"}

    def test_set_room_light(self):
        op, t = translate_command_for_gateway(
            "light", "device.set_room", {"room_id": "room-2"}
        )
        assert op == "device.set_room"
        assert t == {"room_id": "room-2"}

    def test_set_room_switch(self):
        op, t = translate_command_for_gateway(
            "switch", "device.set_room", {"room_id": "room-2"}
        )
        assert op == "device.set_room"
        assert t == {"room_id": "room-2"}

    def test_set_room_missing_room_id_raises(self):
        with pytest.raises(ValueError):
            translate_command_for_gateway(
                "sensor", "device.set_room", {}
            )

    def test_set_room_empty_room_id_raises(self):
        with pytest.raises(ValueError):
            translate_command_for_gateway(
                "light", "device.set_room", {"room_id": ""}
            )


# ---- _fmt_ts timezone conversion ----

def test_fmt_ts_converts_naive_utc_to_local():
    from datetime import datetime

    from cloud.app.schemas import _fmt_ts

    # 18:55 UTC on 2026-07-12 == 01:55 (+07) on 2026-07-13.
    assert _fmt_ts(datetime(2026, 7, 12, 18, 55)) == "01:55 07/13/2026"


def test_fmt_ts_none_passthrough():
    from cloud.app.schemas import _fmt_ts

    assert _fmt_ts(None) is None
