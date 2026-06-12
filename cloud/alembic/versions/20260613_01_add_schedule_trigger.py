"""Add schedule trigger fields to automations.

Revision ID: 20260613_01
Revises:
Create Date: 2026-06-13
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "20260613_01"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TRIGGER_TYPE_VALUES = ("event", "schedule")
trigger_type_enum = sa.Enum(
    *TRIGGER_TYPE_VALUES,
    name="automation_trigger_type",
)


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table("automations"):
        return
    columns = {column["name"] for column in inspector.get_columns("automations")}
    if "trigger_type" not in columns:
        trigger_type_enum.create(bind, checkfirst=True)
        op.add_column(
            "automations",
            sa.Column(
                "trigger_type",
                trigger_type_enum,
                nullable=False,
                server_default="event",
            ),
        )
    if "schedule_cron" not in columns:
        op.add_column(
            "automations",
            sa.Column("schedule_cron", sa.Text(), nullable=True),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table("automations"):
        return
    columns = {column["name"] for column in inspector.get_columns("automations")}
    if "schedule_cron" in columns:
        op.drop_column("automations", "schedule_cron")
    if "trigger_type" in columns:
        op.drop_column("automations", "trigger_type")
    trigger_type_enum.drop(bind, checkfirst=True)
