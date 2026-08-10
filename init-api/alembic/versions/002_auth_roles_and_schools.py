"""Add schools and role-aware authentication.

Revision ID: 002_auth_roles
Revises: 001_initial
Create Date: 2026-08-10
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002_auth_roles"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


user_role = sa.Enum(
    "super_admin",
    "school_admin",
    "teacher",
    "guard",
    name="user_role",
)


def upgrade() -> None:
    user_role.create(op.get_bind(), checkfirst=True)
    op.create_table(
        "schools",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("full_name", sa.String(), nullable=False),
        sa.Column("short_name", sa.String(), nullable=False),
        sa.Column("address", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_schools_id"), "schools", ["id"], unique=False)

    op.add_column("users", sa.Column("school_id", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("login", sa.String(), nullable=True))
    op.add_column("users", sa.Column("full_name", sa.String(), nullable=True))
    op.add_column("users", sa.Column("phone", sa.String(), nullable=True))
    op.add_column("users", sa.Column("role", user_role, nullable=True))
    op.add_column(
        "users",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.execute("UPDATE users SET login = lower(email)")
    op.execute("UPDATE users SET full_name = trim(coalesce(first_name, '') || ' ' || coalesce(last_name, ''))")
    op.execute("UPDATE users SET role = 'teacher'")
    op.alter_column("users", "login", nullable=False)
    op.alter_column("users", "full_name", nullable=False)
    op.alter_column("users", "role", nullable=False)
    op.create_index(op.f("ix_users_login"), "users", ["login"], unique=True)
    op.create_index(op.f("ix_users_school_id"), "users", ["school_id"], unique=False)
    op.create_foreign_key(
        "fk_users_school_id_schools",
        "users",
        "schools",
        ["school_id"],
        ["id"],
    )
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_column("users", "email")
    op.drop_column("users", "first_name")
    op.drop_column("users", "last_name")


def downgrade() -> None:
    op.add_column("users", sa.Column("last_name", sa.String(), nullable=True))
    op.add_column("users", sa.Column("first_name", sa.String(), nullable=True))
    op.add_column("users", sa.Column("email", sa.String(), nullable=True))
    op.execute("UPDATE users SET email = login || '@legacy.local', first_name = full_name, last_name = ''")
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.drop_constraint("fk_users_school_id_schools", "users", type_="foreignkey")
    op.drop_index(op.f("ix_users_school_id"), table_name="users")
    op.drop_index(op.f("ix_users_login"), table_name="users")
    op.drop_column("users", "is_active")
    op.drop_column("users", "role")
    op.drop_column("users", "phone")
    op.drop_column("users", "full_name")
    op.drop_column("users", "login")
    op.drop_column("users", "school_id")
    op.drop_index(op.f("ix_schools_id"), table_name="schools")
    op.drop_table("schools")
    user_role.drop(op.get_bind(), checkfirst=True)
