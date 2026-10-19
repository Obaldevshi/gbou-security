"""Protected login-to-school pointers, no source identifiers or credentials."""
from alembic import op
import sqlalchemy as sa

revision = '015_login_directory'
down_revision = '014_account_deletion'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('login_directory_entries',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('created_at', sa.DateTime()),
        sa.Column('updated_at', sa.DateTime()),
        sa.Column('school_id', sa.Integer(), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False),
        sa.Column('lookup_tag', sa.String(64), nullable=False),
        sa.Column('generation', sa.Integer(), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('school_id', 'lookup_tag', name='uq_login_directory_school_tag'))
    op.create_index('ix_login_directory_entries_school_id', 'login_directory_entries', ['school_id'])
    op.create_index('ix_login_directory_entries_lookup_tag', 'login_directory_entries', ['lookup_tag'])
    op.create_index('ix_login_directory_entries_expires_at', 'login_directory_entries', ['expires_at'])


def downgrade():
    op.drop_index('ix_login_directory_entries_expires_at', table_name='login_directory_entries')
    op.drop_index('ix_login_directory_entries_lookup_tag', table_name='login_directory_entries')
    op.drop_index('ix_login_directory_entries_school_id', table_name='login_directory_entries')
    op.drop_table('login_directory_entries')
