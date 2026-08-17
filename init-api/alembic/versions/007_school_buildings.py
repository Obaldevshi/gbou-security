"""add school buildings

Revision ID: 007_school_buildings
Revises: 006_audit_logs
"""

import sqlalchemy as sa
from alembic import op


revision = "007_school_buildings"
down_revision = "006_audit_logs"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "school_buildings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("school_id", sa.Integer(), sa.ForeignKey("schools.id"), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("address", sa.String(length=255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("school_id", "name", name="uq_school_buildings_school_name"),
    )
    op.create_index("ix_school_buildings_school_id", "school_buildings", ["school_id"])

    connection = op.get_bind()
    schools = sa.table("schools", sa.column("id", sa.Integer), sa.column("address", sa.String))
    buildings = sa.table(
        "school_buildings",
        sa.column("school_id", sa.Integer),
        sa.column("name", sa.String),
        sa.column("address", sa.String),
        sa.column("is_active", sa.Boolean),
        sa.column("created_at", sa.DateTime),
        sa.column("updated_at", sa.DateTime),
    )
    now = sa.func.now()
    for school in connection.execute(sa.select(schools.c.id, schools.c.address)):
        connection.execute(buildings.insert().values(
            school_id=school.id,
            name="Основной корпус",
            address=school.address,
            is_active=True,
            created_at=now,
            updated_at=now,
        ))

    op.add_column("school_classes", sa.Column("building_id", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("building_id", sa.Integer(), nullable=True))
    op.add_column("exit_requests", sa.Column("building_id", sa.Integer(), nullable=True))
    op.create_foreign_key("fk_school_classes_building", "school_classes", "school_buildings", ["building_id"], ["id"])
    op.create_foreign_key("fk_users_building", "users", "school_buildings", ["building_id"], ["id"])
    op.create_foreign_key("fk_exit_requests_building", "exit_requests", "school_buildings", ["building_id"], ["id"])
    op.create_index("ix_school_classes_building_id", "school_classes", ["building_id"])
    op.create_index("ix_users_building_id", "users", ["building_id"])
    op.create_index("ix_exit_requests_building_id", "exit_requests", ["building_id"])

    connection.execute(sa.text("UPDATE school_classes SET building_id = (SELECT id FROM school_buildings WHERE school_buildings.school_id = school_classes.school_id LIMIT 1)"))
    connection.execute(sa.text("UPDATE users SET building_id = (SELECT id FROM school_buildings WHERE school_buildings.school_id = users.school_id LIMIT 1) WHERE role IN ('teacher', 'guard')"))
    connection.execute(sa.text("UPDATE exit_requests SET building_id = (SELECT building_id FROM school_classes WHERE school_classes.id = exit_requests.class_id)"))
    op.alter_column("school_classes", "building_id", nullable=False)
    op.alter_column("exit_requests", "building_id", nullable=False)
    op.drop_constraint("uq_school_classes_school_name", "school_classes", type_="unique")
    op.create_unique_constraint("uq_school_classes_building_name", "school_classes", ["building_id", "name"])


def downgrade() -> None:
    op.drop_constraint("uq_school_classes_building_name", "school_classes", type_="unique")
    op.create_unique_constraint("uq_school_classes_school_name", "school_classes", ["school_id", "name"])
    op.drop_index("ix_exit_requests_building_id", table_name="exit_requests")
    op.drop_index("ix_users_building_id", table_name="users")
    op.drop_index("ix_school_classes_building_id", table_name="school_classes")
    op.drop_constraint("fk_exit_requests_building", "exit_requests", type_="foreignkey")
    op.drop_constraint("fk_users_building", "users", type_="foreignkey")
    op.drop_constraint("fk_school_classes_building", "school_classes", type_="foreignkey")
    op.drop_column("exit_requests", "building_id")
    op.drop_column("users", "building_id")
    op.drop_column("school_classes", "building_id")
    op.drop_index("ix_school_buildings_school_id", table_name="school_buildings")
    op.drop_table("school_buildings")
