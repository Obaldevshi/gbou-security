from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker
from .settings import settings


sqlite_mode = settings.database_url.startswith("sqlite:")
engine = create_engine(
    settings.database_url,
    connect_args={"check_same_thread": False, "timeout": 30} if sqlite_mode else {},
    **({} if sqlite_mode else {"pool_pre_ping": True, "pool_recycle": 300, "pool_timeout": 15}),
)
if sqlite_mode:
    @event.listens_for(engine, "connect")
    def configure_sqlite(dbapi_connection, _connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA busy_timeout=30000")
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.close()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
