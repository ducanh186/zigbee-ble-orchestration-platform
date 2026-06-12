"""Tests for Phase 3.4 Pydantic validation schemas."""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from cloud.app.schemas import (
    AutomationCreate,
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
