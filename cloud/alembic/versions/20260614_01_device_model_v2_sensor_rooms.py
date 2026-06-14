"""device model v2: sensor taxonomy + sensor_kind

Revision ID: 20260614_01
Revises: 20260613_01
Create Date: 2026-06-14
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import json

revision: str = "20260614_01"
down_revision: Union[str, None] = "20260613_01"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _retype(obj):
    """Recursively rewrite legacy device_type values to 'sensor'.

    - "environment" -> "sensor"
    - "motion"      -> "sensor"
    - everything else is left untouched.
    """
    if isinstance(obj, dict):
        # Pure transform: build a new dict (recursing into children) and rewrite
        # the device_type on the copy. Never mutate the caller's object.
        out = {k: _retype(v) for k, v in obj.items()}
        if out.get("device_type") in ("environment", "motion"):
            out["device_type"] = "sensor"
        return out
    if isinstance(obj, list):
        return [_retype(v) for v in obj]
    return obj


def _cutover(bind):
    """Apply the hard-cutover data transform.

    1. Convert Device rows: environment -> sensor/kind=2, motion -> sensor/kind=1.
    2. Rewrite automation trigger/actions JSON that reference legacy device_types.

    Factored out of upgrade() so it can be unit-tested without a live Alembic
    context (see cloud/tests/test_device_model_v2_migration.py).
    """
    # Devices
    bind.execute(
        sa.text(
            "UPDATE devices "
            "SET device_type='sensor', sensor_kind=2 "
            "WHERE device_type='environment'"
        )
    )
    bind.execute(
        sa.text(
            "UPDATE devices "
            "SET device_type='sensor', sensor_kind=1 "
            "WHERE device_type='motion'"
        )
    )

    # Automation JSON
    rows = (
        bind.execute(
            sa.text("SELECT id, trigger, actions FROM automations")
        )
        .mappings()
        .all()
    )
    for r in rows:
        trig = r["trigger"]
        acts = r["actions"]
        if trig is None and acts is None:
            continue
        # JSONB (Postgres) surfaces as dict/list; TEXT/JSON (sqlite) as str.
        # Guard None defensively in case a legacy row predates the NOT NULL
        # constraint.
        trig_obj = json.loads(trig) if isinstance(trig, str) else (trig or {})
        acts_obj = json.loads(acts) if isinstance(acts, str) else (acts or [])
        # The JSON string binds into the JSONB column via Postgres' implicit
        # text->jsonb cast (sync psycopg driver under Alembic); on sqlite the
        # column is TEXT/JSON so the string stores directly. No double-encode.
        bind.execute(
            sa.text(
                "UPDATE automations "
                "SET trigger=:t, actions=:a "
                "WHERE id=:id"
            ),
            {
                "t": json.dumps(_retype(trig_obj)),
                "a": json.dumps(_retype(acts_obj)),
                "id": r["id"],
            },
        )


def upgrade() -> None:
    # Guard: prod may already have sensor_kind if init_db ran create_all after
    # Phase 0 added the column to the model.  Only add it if missing.
    bind = op.get_bind()
    insp = sa.inspect(bind)
    cols = [c["name"] for c in insp.get_columns("devices")]
    if "sensor_kind" not in cols:
        op.add_column(
            "devices",
            sa.Column("sensor_kind", sa.Integer(), nullable=True),
        )
    _cutover(bind)


def downgrade() -> None:
    """Best-effort reverse.

    Device rows are restored; automation JSON rewrite is NOT reversed
    because we cannot distinguish a pre-existing "sensor" from a
    migrated one.  Document this trade-off — downgrade is for dev/test
    rollback only, not a safe prod revert.
    """
    bind = op.get_bind()
    bind.execute(
        sa.text(
            "UPDATE devices "
            "SET device_type='environment' "
            "WHERE device_type='sensor' AND sensor_kind=2"
        )
    )
    bind.execute(
        sa.text(
            "UPDATE devices "
            "SET device_type='motion' "
            "WHERE device_type='sensor' AND sensor_kind=1"
        )
    )
    insp = sa.inspect(bind)
    if "sensor_kind" in [c["name"] for c in insp.get_columns("devices")]:
        op.drop_column("devices", "sensor_kind")
