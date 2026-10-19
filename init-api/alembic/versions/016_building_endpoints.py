"""Campus-scoped routing, retaining the legacy registry and all school records."""
from alembic import op
import sqlalchemy as sa

revision = '016_building_endpoints'
down_revision = '015_login_directory'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('building_endpoints',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('created_at', sa.DateTime()), sa.Column('updated_at', sa.DateTime()),
        sa.Column('school_id', sa.Integer(), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False),
        sa.Column('building_id', sa.Integer(), sa.ForeignKey('school_buildings.id', ondelete='RESTRICT'), nullable=False, unique=True),
        sa.Column('slug', sa.String(63), nullable=False, unique=True),
        sa.Column('legacy_hostname', sa.String(255), unique=True),
        sa.Column('generation', sa.Integer(), nullable=False),
        sa.Column('primary_device_id', sa.String(36), unique=True),
        sa.UniqueConstraint('school_id', 'building_id', name='uq_building_endpoint_scope'))
    op.create_index('ix_building_endpoints_school_id', 'building_endpoints', ['school_id'])
    with op.batch_alter_table('device_invitations') as batch:
        batch.add_column(sa.Column('building_id', sa.Integer(), nullable=True))
        batch.create_foreign_key('fk_invitation_building', 'school_buildings', ['building_id'], ['id'], ondelete='RESTRICT')
    # Copy only a proven existing writer, preserving its actual URL, UUID, and
    # generation. No guessing the building of orphan/legacy pending devices.
    op.execute(sa.text('''INSERT INTO building_endpoints
        (school_id, building_id, slug, legacy_hostname, generation, primary_device_id, created_at, updated_at)
        SELECT e.school_id, d.building_id, e.slug, e.legacy_hostname,
               e.generation, e.primary_device_id, e.created_at, e.updated_at
        FROM school_endpoints e
        JOIN school_devices d ON d.device_id = e.primary_device_id
        JOIN school_buildings b ON b.id = d.building_id AND b.school_id = e.school_id
        WHERE d.school_id = e.school_id AND d.role = 'primary' AND d.state = 'active'
          AND d.generation = e.generation'''))
    op.create_table('building_login_directory_entries',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('created_at', sa.DateTime()), sa.Column('updated_at', sa.DateTime()),
        sa.Column('endpoint_id', sa.Integer(), sa.ForeignKey('building_endpoints.id', ondelete='CASCADE'), nullable=False),
        sa.Column('lookup_tag', sa.String(64), nullable=False),
        sa.Column('generation', sa.Integer(), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('endpoint_id', 'lookup_tag', name='uq_building_directory_tag'))
    for name in ('endpoint_id', 'lookup_tag', 'expires_at'):
        op.create_index('ix_building_login_directory_entries_' + name, 'building_login_directory_entries', [name])
    op.execute(sa.text('''INSERT INTO building_login_directory_entries
        (endpoint_id, lookup_tag, generation, expires_at, created_at, updated_at)
        SELECT b.id, l.lookup_tag, l.generation, l.expires_at, l.created_at, l.updated_at
        FROM login_directory_entries l JOIN building_endpoints b ON b.school_id=l.school_id
        WHERE b.generation=l.generation'''))


def downgrade():
    connection = op.get_bind()
    # Never silently drop working routes that cannot be represented by the
    # legacy one-primary model. Data remains intact when this guard fails.
    if connection.execute(sa.text('''SELECT COUNT(*) FROM building_endpoints b
        LEFT JOIN school_endpoints e ON e.school_id = b.school_id
        WHERE e.id IS NULL OR e.slug <> b.slug OR e.generation <> b.generation
          OR COALESCE(e.primary_device_id, '') <> COALESCE(b.primary_device_id, '')
          OR COALESCE(e.legacy_hostname, '') <> COALESCE(b.legacy_hostname, '')''')).scalar():
        raise RuntimeError('Building registry diverged: export and plan an explicit rollback first')
    op.drop_table('building_login_directory_entries')
    with op.batch_alter_table('device_invitations') as batch:
        batch.drop_constraint('fk_invitation_building', type_='foreignkey')
        batch.drop_column('building_id')
    op.drop_index('ix_building_endpoints_school_id', table_name='building_endpoints')
    op.drop_table('building_endpoints')
