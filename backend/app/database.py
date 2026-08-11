"""
Database engine, session factory, and dependency injection for FastAPI.
Uses synchronous SQLAlchemy with psycopg2 for hackathon simplicity.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase, Session
from typing import Generator

from app.config import get_settings

settings = get_settings()

# ── Engine ────────────────────────────────────────────────
# pool_pre_ping=True ensures stale connections are recycled
connect_args = {"check_same_thread": False} if settings.DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    echo=False,  # Set True for SQL debug logging
)

# ── Session Factory ───────────────────────────────────────
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


# ── Declarative Base ─────────────────────────────────────
class Base(DeclarativeBase):
    """Base class for all ORM models."""
    pass


# ── FastAPI Dependency ────────────────────────────────────
def get_db() -> Generator[Session, None, None]:
    """
    Yields a database session for the duration of a single request.
    Automatically closes the session when the request completes.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
