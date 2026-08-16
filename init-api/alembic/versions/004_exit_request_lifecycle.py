"""add cancellation and expiration states

Revision ID: 004_exit_request_lifecycle
Revises: 003_exit_request_foundation
"""

from alembic import op


revision = "004_exit_request_lifecycle"
down_revision = "003_exit_request_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE exit_request_status ADD VALUE IF NOT EXISTS 'cancelled'")
    op.execute("ALTER TYPE exit_request_status ADD VALUE IF NOT EXISTS 'expired'")


def downgrade() -> None:
    op.execute("UPDATE exit_requests SET status = 'pending' WHERE status IN ('cancelled', 'expired')")
    op.execute("ALTER TYPE exit_request_status RENAME TO exit_request_status_old")
    op.execute("CREATE TYPE exit_request_status AS ENUM ('pending', 'released')")
    op.execute(
        "ALTER TABLE exit_requests ALTER COLUMN status TYPE exit_request_status "
        "USING status::text::exit_request_status"
    )
    op.execute("DROP TYPE exit_request_status_old")
