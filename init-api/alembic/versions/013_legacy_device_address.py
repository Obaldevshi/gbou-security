"""Keep an existing school address when adopting its running primary."""
from alembic import op
import sqlalchemy as sa

revision = '013_legacy_device_address'
down_revision = '012_device_pairing'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('school_endpoints') as batch:
        batch.add_column(sa.Column('legacy_hostname', sa.String(255), nullable=True))
        batch.create_unique_constraint('uq_school_endpoint_legacy_hostname', ['legacy_hostname'])


def downgrade():
    with op.batch_alter_table('school_endpoints') as batch:
        batch.drop_constraint('uq_school_endpoint_legacy_hostname', type_='unique')
        batch.drop_column('legacy_hostname')
