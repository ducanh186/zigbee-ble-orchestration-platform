"""Tests for the device model v2 migration helper (_cutover).

Uses a synchronous in-memory SQLite engine — no live Alembic context required.
Mirrors the pattern from test_schedule_migration.py (import spec + model-level
checks) but exercises the data-transform logic directly.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest
import sqlalchemy as sa
from sqlalchemy import create_engine, text

from cloud.app.models import Base


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_MIGRATION_PATH = (
    Path(__file__).parents[1]
    / "alembic"
    / "versions"
    / "20260614_01_device_model_v2_sensor_rooms.py"
)


def _load_migration():
    spec = importlib.util.spec_from_file_location("migration_v2", _MIGRATION_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------------------
# Structural / header checks
# ---------------------------------------------------------------------------


def test_migration_file_exists():
    assert _MIGRATION_PATH.exists(), f"Migration file not found: {_MIGRATION_PATH}"


def test_migration_revision_ids():
    m = _load_migration()
    assert m.revision == "20260614_01"
    assert m.down_revision == "20260613_01"


def test_retype_transforms_environment():
    m = _load_migration()
    obj = {"device_type": "environment", "foo": "bar"}
    assert m._retype(obj) == {"device_type": "sensor", "foo": "bar"}


def test_retype_transforms_motion():
    m = _load_migration()
    obj = {"device_type": "motion"}
    assert m._retype(obj) == {"device_type": "sensor"}


def test_retype_leaves_other_types_alone():
    m = _load_migration()
    for dt in ("light", "switch", "sensor"):
        obj = {"device_type": dt}
        assert m._retype(obj)["device_type"] == dt


def test_retype_recurses_into_list():
    m = _load_migration()
    lst = [{"device_type": "environment"}, {"device_type": "motion"}, {"device_type": "light"}]
    result = m._retype(lst)
    assert result[0]["device_type"] == "sensor"
    assert result[1]["device_type"] == "sensor"
    assert result[2]["device_type"] == "light"


# ---------------------------------------------------------------------------
# Data-transform (_cutover) against an in-memory SQLite DB
# ---------------------------------------------------------------------------


@pytest.fixture()
def sync_engine():
    """Fresh in-memory SQLite engine with the full schema."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()


def _insert_device(conn, id_, device_type, sensor_kind=None):
    conn.execute(
        text(
            "INSERT INTO devices (id, device_type, sensor_kind, is_online) "
            "VALUES (:id, :dt, :sk, 0)"
        ),
        {"id": id_, "dt": device_type, "sk": sensor_kind},
    )


def _insert_automation(conn, id_, trigger_obj, actions_obj):
    conn.execute(
        text(
            "INSERT INTO automations "
            "(id, name, enabled, tenant_id, site_id, gateway_id, version, "
            " trigger_type, schedule_cron, trigger, actions, "
            " sync_status, last_run_status) "
            "VALUES (:id, :name, 1, 'tenant', 'site', 'gw', 1, 'event', NULL, "
            "        :trig, :acts, 'pending', 'never_run')"
        ),
        {
            "id": id_,
            "name": "Test rule",
            "trig": json.dumps(trigger_obj),
            "acts": json.dumps(actions_obj),
        },
    )


def test_cutover_environment_becomes_sensor_kind2(sync_engine):
    m = _load_migration()
    with sync_engine.begin() as conn:
        _insert_device(conn, "env-01", "environment")
        m._cutover(conn)
        row = conn.execute(
            text("SELECT device_type, sensor_kind FROM devices WHERE id='env-01'")
        ).mappings().one()
    assert row["device_type"] == "sensor"
    assert row["sensor_kind"] == 2


def test_cutover_motion_becomes_sensor_kind1(sync_engine):
    m = _load_migration()
    with sync_engine.begin() as conn:
        _insert_device(conn, "mot-01", "motion")
        m._cutover(conn)
        row = conn.execute(
            text("SELECT device_type, sensor_kind FROM devices WHERE id='mot-01'")
        ).mappings().one()
    assert row["device_type"] == "sensor"
    assert row["sensor_kind"] == 1


def test_cutover_light_untouched(sync_engine):
    m = _load_migration()
    with sync_engine.begin() as conn:
        _insert_device(conn, "light-01", "light")
        m._cutover(conn)
        row = conn.execute(
            text("SELECT device_type, sensor_kind FROM devices WHERE id='light-01'")
        ).mappings().one()
    assert row["device_type"] == "light"
    assert row["sensor_kind"] is None


def test_cutover_automation_json_rewritten(sync_engine):
    m = _load_migration()
    trigger = {
        "type": "sensor_threshold",
        "device_id": "env-01",
        "device_type": "environment",
        "metric": "temperature_c",
        "operator": "gte",
        "threshold": 30,
    }
    actions = [
        {"type": "device_command", "device_id": "motion-01", "device_type": "motion", "command": "on"},
        {"type": "device_command", "device_id": "light-01", "device_type": "light", "command": "on"},
    ]
    with sync_engine.begin() as conn:
        _insert_automation(conn, "rule-1", trigger, actions)
        m._cutover(conn)
        row = conn.execute(
            text("SELECT trigger, actions FROM automations WHERE id='rule-1'")
        ).mappings().one()
    trig_out = json.loads(row["trigger"])
    acts_out = json.loads(row["actions"])
    assert trig_out["device_type"] == "sensor"
    assert acts_out[0]["device_type"] == "sensor"   # motion -> sensor
    assert acts_out[1]["device_type"] == "light"     # light unchanged


def test_retype_does_not_mutate_input():
    m = _load_migration()
    obj = {"device_type": "environment", "nested": {"device_type": "motion"}}
    result = m._retype(obj)
    # input is untouched (pure transform)
    assert obj == {"device_type": "environment", "nested": {"device_type": "motion"}}
    # output is fully rewritten, including nested dicts
    assert result == {"device_type": "sensor", "nested": {"device_type": "sensor"}}


def test_cutover_is_idempotent(sync_engine):
    m = _load_migration()
    with sync_engine.begin() as conn:
        _insert_device(conn, "env-01", "environment")
        _insert_automation(
            conn,
            "rule-1",
            {"type": "sensor_threshold", "device_type": "environment"},
            [{"type": "device_command", "device_type": "motion"}],
        )
        m._cutover(conn)
        m._cutover(conn)  # second run must be a no-op, not a re-corruption
        dev = conn.execute(
            text("SELECT device_type, sensor_kind FROM devices WHERE id='env-01'")
        ).mappings().one()
        trig = json.loads(
            conn.execute(
                text("SELECT trigger FROM automations WHERE id='rule-1'")
            ).scalar()
        )
        acts = json.loads(
            conn.execute(
                text("SELECT actions FROM automations WHERE id='rule-1'")
            ).scalar()
        )
    assert dev["device_type"] == "sensor"
    assert dev["sensor_kind"] == 2
    assert trig["device_type"] == "sensor"
    assert acts[0]["device_type"] == "sensor"


def test_cutover_all_types_together(sync_engine):
    """Control: all three device types in one run — verify isolation."""
    m = _load_migration()
    with sync_engine.begin() as conn:
        _insert_device(conn, "env-01", "environment")
        _insert_device(conn, "mot-01", "motion")
        _insert_device(conn, "light-01", "light")
        m._cutover(conn)
        rows = {
            r["id"]: r
            for r in conn.execute(
                text("SELECT id, device_type, sensor_kind FROM devices")
            ).mappings().all()
        }
    assert rows["env-01"]["device_type"] == "sensor"
    assert rows["env-01"]["sensor_kind"] == 2
    assert rows["mot-01"]["device_type"] == "sensor"
    assert rows["mot-01"]["sensor_kind"] == 1
    assert rows["light-01"]["device_type"] == "light"
    assert rows["light-01"]["sensor_kind"] is None
