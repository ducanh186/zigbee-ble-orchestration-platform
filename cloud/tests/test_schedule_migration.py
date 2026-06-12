from __future__ import annotations

import importlib.util
from pathlib import Path

from cloud.app.models import Automation


def test_automation_model_has_schedule_columns():
    columns = Automation.__table__.columns
    assert columns["trigger_type"].nullable is False
    assert columns["trigger_type"].server_default.arg == "event"
    assert columns["schedule_cron"].nullable is True


def test_schedule_migration_defines_event_and_schedule_values():
    path = (
        Path(__file__).parents[1]
        / "alembic"
        / "versions"
        / "20260613_01_add_schedule_trigger.py"
    )
    spec = importlib.util.spec_from_file_location("schedule_migration", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert module.TRIGGER_TYPE_VALUES == ("event", "schedule")
