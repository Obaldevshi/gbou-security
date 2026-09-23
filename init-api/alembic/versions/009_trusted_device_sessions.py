"""add trusted device sessions for Android PIN unlock

Revision ID: 009_trusted_device_sessions
Revises: 008_superadmin_password_recovery
"""

import sqlalchemy as sa
from alembic import op

revision = "009_trusted_device_sessions"
down_revision = "008_superadmin_password_recovery"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trusted_device_sessions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        "ix_trusted_device_sessions_user_id",
        "trusted_device_sessions",
        ["user_id"],
    )
    op.create_index(
        "ix_trusted_device_sessions_token_hash",
        "trusted_device_sessions",
        ["token_hash"],
        unique=True,
    )
    op.create_index(
        "ix_trusted_device_sessions_expires_at",
        "trusted_device_sessions",
        ["expires_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_trusted_device_sessions_expires_at", table_name="trusted_device_sessions")
    op.drop_index("ix_trusted_device_sessions_token_hash", table_name="trusted_device_sessions")
    op.drop_index("ix_trusted_device_sessions_user_id", table_name="trusted_device_sessions")
    op.drop_table("trusted_device_sessions")
