"""Short-lived QR requests and optional device building metadata."""
from alembic import op
import sqlalchemy as sa

revision = '012_device_pairing'
down_revision = '011_school_devices'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('school_devices') as batch:
        batch.add_column(sa.Column('building_id', sa.Integer(), nullable=True))
        batch.create_foreign_key('fk_device_building', 'school_buildings', ['building_id'], ['id'], ondelete='SET NULL')
    op.create_table('device_pairings',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('created_at', sa.DateTime()), sa.Column('updated_at', sa.DateTime()),
        sa.Column('request_id', sa.String(36), nullable=False, unique=True),
        sa.Column('device_id', sa.String(36), nullable=False, unique=True),
        sa.Column('label', sa.String(80), nullable=False),
        sa.Column('public_key', sa.String(44), nullable=False),
        sa.Column('poll_hash', sa.String(64), nullable=False),
        sa.Column('code_hash', sa.String(64), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('state', sa.String(12), nullable=False),
        sa.Column('failed_checks', sa.Integer(), nullable=False),
        sa.CheckConstraint("state IN ('waiting','approved','completed','expired')", name='ck_pairing_state'))
    op.create_index('ix_device_pairings_expires_at', 'device_pairings', ['expires_at'])


def downgrade():
    op.drop_table('device_pairings')
    with op.batch_alter_table('school_devices') as batch:
        batch.drop_constraint('fk_device_building', type_='foreignkey')
        batch.drop_column('building_id')
