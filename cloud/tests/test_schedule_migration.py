from __future__ import annotations

import importlib.util
from pathlib import Path

from sqlalchemy import insert
from sqlalchemy.dialects.postgresql.asyncpg import PGDialect_asyncpg

from cloud.app.models import Automation


def test_automation_model_has_schedule_columns():
    columns = Automation.__table__.columns
    assert columns["trigger_type"].nullable is False
    assert columns["trigger_type"].server_default.arg == "event"
    assert columns["schedule_cron"].nullable is True


def test_automation_insert_uses_postgres_trigger_type_enum():
    statement = insert(Automation).values(
        id="auto_test",
        name="Test",
        enabled=True,
        tenant_id="tenant",
        site_id="site",
        gateway_id="gateway",
        version=1,
        trigger_type="event",
        schedule_cron=None,
        trigger={},
        actions=[],
        sync_status="pending",
        last_run_status="never_run",
        last_error=None,
    )

    compiled = str(statement.compile(dialect=PGDialect_asyncpg()))

    assert "$8::automation_trigger_type" in compiled


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


def test_cloud_image_exposes_package_root_to_alembic():
    dockerfile = Path(__file__).parents[1] / "Dockerfile"
    assert "ENV PYTHONPATH=/app" in dockerfile.read_text(encoding="utf-8")
