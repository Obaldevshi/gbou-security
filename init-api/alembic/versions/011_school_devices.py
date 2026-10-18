"""Stable school endpoints and one-primary device registry (no personal data)."""
import sqlalchemy as sa
from alembic import op

revision = '011_school_devices'
down_revision = '010_school_node_credentials'
branch_labels = None
depends_on = None


def upgrade():
    common = lambda: [sa.Column('id', sa.Integer(), primary_key=True),
                      sa.Column('created_at', sa.DateTime()), sa.Column('updated_at', sa.DateTime())]
    school = lambda: sa.Column('school_id', sa.Integer(), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False)
    op.create_table('school_endpoints', *common(), school(),
                    sa.Column('slug', sa.String(63), nullable=False),
                    sa.Column('generation', sa.Integer(), nullable=False, server_default='0'),
                    sa.Column('primary_device_id', sa.String(36)),
                    sa.UniqueConstraint('school_id'), sa.UniqueConstraint('slug'), sa.UniqueConstraint('primary_device_id'))
    op.create_table('school_devices', *common(), school(),
                    sa.Column('device_id', sa.String(36), nullable=False),
                    sa.Column('label', sa.String(80), nullable=False),
                    sa.Column('role', sa.String(12), nullable=False),
                    sa.Column('state', sa.String(12), nullable=False),
                    sa.Column('token_hash', sa.String(64), nullable=False),
                    sa.Column('public_key', sa.String(44)), sa.Column('tunnel_ip', sa.String(15)),
                    sa.Column('last_seen_at', sa.DateTime()), sa.Column('generation', sa.Integer(), nullable=False),
                    sa.UniqueConstraint('device_id'), sa.UniqueConstraint('token_hash'),
                    sa.UniqueConstraint('public_key'), sa.UniqueConstraint('tunnel_ip'),
                    sa.CheckConstraint("role IN ('primary', 'terminal')", name='ck_device_role'),
                    sa.CheckConstraint("state IN ('pending', 'active', 'revoked')", name='ck_device_state'))
    op.create_index('ix_school_devices_school_id', 'school_devices', ['school_id'])
    op.create_table('device_invitations', *common(), school(),
                    sa.Column('token_hash', sa.String(64), nullable=False),
                    sa.Column('role', sa.String(12), nullable=False),
                    sa.Column('generation', sa.Integer(), nullable=False),
                    sa.Column('expires_at', sa.DateTime(), nullable=False), sa.Column('consumed_at', sa.DateTime()),
                    sa.Column('device_id', sa.String(36)),
                    sa.Column('revoked', sa.Boolean(), nullable=False, server_default=sa.false()),
                    sa.UniqueConstraint('token_hash'))
    op.create_index('ix_device_invitations_school_id', 'device_invitations', ['school_id'])


def downgrade():
    op.drop_table('device_invitations')
    op.drop_table('school_devices')
    op.drop_table('school_endpoints')
