"""add one-time super administrator password recovery marker

Revision ID: 008_superadmin_password_recovery
Revises: 007_school_buildings
"""

import sqlalchemy as sa
from alembic import op


revision = "008_superadmin_password_recovery"
down_revision = "007_school_buildings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("password_reset_marker", sa.String(length=64), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "password_reset_marker")
