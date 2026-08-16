"""require temporary password change

Revision ID: 005_password_security
Revises: 004_exit_request_lifecycle
"""

import sqlalchemy as sa
from alembic import op


revision = "005_password_security"
down_revision = "004_exit_request_lifecycle"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "must_change_password",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.execute("UPDATE users SET must_change_password = true")


def downgrade() -> None:
    op.drop_column("users", "must_change_password")
