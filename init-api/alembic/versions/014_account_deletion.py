"""Track irreversible profile deletion without cascading school records."""
from alembic import op
import sqlalchemy as sa

revision = '014_account_deletion'
down_revision = '013_legacy_device_address'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('users', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))

def downgrade():
    op.drop_column('users', 'deleted_at')
