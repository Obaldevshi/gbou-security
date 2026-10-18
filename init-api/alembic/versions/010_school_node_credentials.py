"""Per-school credential for a local Raspberry node.

Revision ID: 010_school_node_credentials
Revises: 009_trusted_device_sessions
"""

import sqlalchemy as sa
from alembic import op

revision = "010_school_node_credentials"
down_revision = "009_trusted_device_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "school_node_credentials",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("school_id", sa.Integer(), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("school_id", name="uq_school_node_credentials_school_id"),
    )
    op.create_index("ix_school_node_credentials_school_id", "school_node_credentials", ["school_id"])
    op.create_index("ix_school_node_credentials_token_hash", "school_node_credentials", ["token_hash"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_school_node_credentials_token_hash", table_name="school_node_credentials")
    op.drop_index("ix_school_node_credentials_school_id", table_name="school_node_credentials")
    op.drop_table("school_node_credentials")
