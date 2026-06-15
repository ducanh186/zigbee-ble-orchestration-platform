"""allow provisioning room assignment after session create

Revision ID: 20260615_01
Revises: 20260614_01
Create Date: 2026-06-15
"""
from typing import Sequence, Union

from alembic import op

revision: str = "20260615_01"
down_revision: Union[str, None] = "20260614_01"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("provisioning_sessions", "room_id", nullable=True)


def downgrade() -> None:
    op.alter_column("provisioning_sessions", "room_id", nullable=False)
