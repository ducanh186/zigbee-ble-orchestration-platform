"""
Tests for command lifecycle transitions and timeout handling.
"""

from __future__ import annotations

import time

import pytest

from gateway.src.lifecycle import CommandLifecycleTracker


def test_lifecycle_valid_transition_sequence():
    timed_out = []
    tracker = CommandLifecycleTracker(1000, timed_out.append)
    tracker.start()
    try:
        assert tracker.transition("cmd-01", "accepted", device_id="light-01")
        assert tracker.transition("cmd-01", "queued", device_id="light-01")
        assert tracker.transition("cmd-01", "sent", device_id="light-01")
        assert tracker.transition("cmd-01", "executed", device_id="light-01")
        assert tracker.state_for("cmd-01") == "executed"
        assert timed_out == []
    finally:
        tracker.stop()


def test_lifecycle_timeout_callback_fires():
    timed_out = []
    tracker = CommandLifecycleTracker(50, timed_out.append)
    tracker.start()
    try:
        tracker.transition("cmd-02", "accepted", device_id="light-01")
        tracker.transition("cmd-02", "queued", device_id="light-01")
        tracker.transition("cmd-02", "sent", device_id="light-01")
        time.sleep(0.2)
        assert tracker.state_for("cmd-02") == "timeout"
        assert len(timed_out) == 1
        assert timed_out[0].command_id == "cmd-02"
    finally:
        tracker.stop()


def test_lifecycle_rejects_invalid_transition():
    tracker = CommandLifecycleTracker(1000, lambda pending: None)
    tracker.start()
    try:
        tracker.transition("cmd-03", "accepted", device_id="light-01")
        with pytest.raises(ValueError):
            tracker.transition("cmd-03", "executed", device_id="light-01")
    finally:
        tracker.stop()
