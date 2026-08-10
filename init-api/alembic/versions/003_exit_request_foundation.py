"""Add teacher classes, students, assignments, and exit requests.

Revision ID: 003_exit_requests
Revises: 002_auth_roles
Create Date: 2026-08-10
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "003_exit_requests"
down_revision: Union[str, None] = "002_auth_roles"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


exit_reason_type = sa.Enum(
    "parent_note",
    "health",
    "other",
    name="exit_reason_type",
)
exit_request_status = sa.Enum(
    "pending",
    "released",
    name="exit_request_status",
)


def upgrade() -> None:
    exit_reason_type.create(op.get_bind(), checkfirst=True)
    exit_request_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "school_classes",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("school_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=64), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(["school_id"], ["schools.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "school_id",
            "name",
            name="uq_school_classes_school_name",
        ),
    )
    op.create_index("ix_school_classes_id", "school_classes", ["id"])
    op.create_index("ix_school_classes_school_id", "school_classes", ["school_id"])

    op.create_table(
        "students",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("school_id", sa.Integer(), nullable=False),
        sa.Column("class_id", sa.Integer(), nullable=False),
        sa.Column("last_name", sa.String(length=100), nullable=False),
        sa.Column("first_name", sa.String(length=100), nullable=False),
        sa.Column("middle_name", sa.String(length=100), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(["class_id"], ["school_classes.id"]),
        sa.ForeignKeyConstraint(["school_id"], ["schools.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_students_id", "students", ["id"])
    op.create_index("ix_students_school_id", "students", ["school_id"])
    op.create_index("ix_students_class_id", "students", ["class_id"])

    op.create_table(
        "teacher_class_assignments",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("teacher_id", sa.Integer(), nullable=False),
        sa.Column("class_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["class_id"], ["school_classes.id"]),
        sa.ForeignKeyConstraint(["teacher_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "teacher_id",
            "class_id",
            name="uq_teacher_class_assignments_teacher_class",
        ),
    )
    op.create_index(
        "ix_teacher_class_assignments_id",
        "teacher_class_assignments",
        ["id"],
    )
    op.create_index(
        "ix_teacher_class_assignments_teacher_id",
        "teacher_class_assignments",
        ["teacher_id"],
    )
    op.create_index(
        "ix_teacher_class_assignments_class_id",
        "teacher_class_assignments",
        ["class_id"],
    )

    op.create_table(
        "exit_requests",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("school_id", sa.Integer(), nullable=False),
        sa.Column("class_id", sa.Integer(), nullable=False),
        sa.Column("student_id", sa.Integer(), nullable=False),
        sa.Column("teacher_id", sa.Integer(), nullable=False),
        sa.Column("reason_type", exit_reason_type, nullable=False),
        sa.Column("custom_reason", sa.String(length=500), nullable=True),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "status",
            exit_request_status,
            nullable=False,
            server_default="pending",
        ),
        sa.Column("released_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("released_by_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["class_id"], ["school_classes.id"]),
        sa.ForeignKeyConstraint(["released_by_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["school_id"], ["schools.id"]),
        sa.ForeignKeyConstraint(["student_id"], ["students.id"]),
        sa.ForeignKeyConstraint(["teacher_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_exit_requests_id", "exit_requests", ["id"])
    op.create_index("ix_exit_requests_school_id", "exit_requests", ["school_id"])
    op.create_index("ix_exit_requests_class_id", "exit_requests", ["class_id"])
    op.create_index("ix_exit_requests_student_id", "exit_requests", ["student_id"])
    op.create_index("ix_exit_requests_teacher_id", "exit_requests", ["teacher_id"])
    op.create_index("ix_exit_requests_scheduled_at", "exit_requests", ["scheduled_at"])
    op.create_index("ix_exit_requests_status", "exit_requests", ["status"])
    op.create_index(
        "ix_exit_requests_teacher_status",
        "exit_requests",
        ["teacher_id", "status"],
    )
    op.create_index(
        "ix_exit_requests_school_status_scheduled",
        "exit_requests",
        ["school_id", "status", "scheduled_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_exit_requests_school_status_scheduled", table_name="exit_requests")
    op.drop_index("ix_exit_requests_teacher_status", table_name="exit_requests")
    op.drop_index("ix_exit_requests_status", table_name="exit_requests")
    op.drop_index("ix_exit_requests_scheduled_at", table_name="exit_requests")
    op.drop_index("ix_exit_requests_teacher_id", table_name="exit_requests")
    op.drop_index("ix_exit_requests_student_id", table_name="exit_requests")
    op.drop_index("ix_exit_requests_class_id", table_name="exit_requests")
    op.drop_index("ix_exit_requests_school_id", table_name="exit_requests")
    op.drop_index("ix_exit_requests_id", table_name="exit_requests")
    op.drop_table("exit_requests")

    op.drop_index(
        "ix_teacher_class_assignments_class_id",
        table_name="teacher_class_assignments",
    )
    op.drop_index(
        "ix_teacher_class_assignments_teacher_id",
        table_name="teacher_class_assignments",
    )
    op.drop_index(
        "ix_teacher_class_assignments_id",
        table_name="teacher_class_assignments",
    )
    op.drop_table("teacher_class_assignments")

    op.drop_index("ix_students_class_id", table_name="students")
    op.drop_index("ix_students_school_id", table_name="students")
    op.drop_index("ix_students_id", table_name="students")
    op.drop_table("students")

    op.drop_index("ix_school_classes_school_id", table_name="school_classes")
    op.drop_index("ix_school_classes_id", table_name="school_classes")
    op.drop_table("school_classes")

    exit_request_status.drop(op.get_bind(), checkfirst=True)
    exit_reason_type.drop(op.get_bind(), checkfirst=True)
