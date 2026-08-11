"""
SQLAlchemy ORM models with PostGIS spatial columns.

Uses GeoAlchemy2 GEOGRAPHY(POINT, 4326) for spherical distance calculations
on the WGS84 ellipsoid. GIST spatial indices enable sub-millisecond KNN lookups.
"""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Text, Float, Boolean, Enum, ForeignKey,
    DateTime, Index,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from app.database import Base


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enum Types (mirror PostgreSQL ENUM definitions)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class IncidentStatus(str, enum.Enum):
    REPORTED = "REPORTED"
    VERIFIED = "VERIFIED"
    ASSIGNED = "ASSIGNED"
    IN_PROGRESS = "IN_PROGRESS"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"


class SeverityLevel(str, enum.Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    UNKNOWN = "UNKNOWN"


class UserRole(str, enum.Enum):
    CITIZEN = "CITIZEN"
    RESCUER = "RESCUER"
    ADMIN = "ADMIN"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Users
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class User(Base):
    __tablename__ = "users"

    user_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    full_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    phone_number = Column(String(15), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(
        Enum(UserRole, name="user_role", create_type=True),
        nullable=False,
        default=UserRole.CITIZEN,
    )
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    incidents = relationship("Incident", back_populates="reporter")


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Rescue Teams (with live spatial tracking)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class RescueTeam(Base):
    __tablename__ = "rescue_teams"

    team_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ngo_name = Column(String(150), nullable=False)
    lead_user_id = Column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True
    )
    # Mock SQLite columns
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    is_available = Column(Boolean, default=True)
    last_ping = Column(DateTime(timezone=True), nullable=True)
    
    # Firebase Cloud Messaging token
    device_token = Column(String(255), nullable=True)

    # Relationships
    lead_user = relationship("User")
    assigned_incidents = relationship("Incident", back_populates="assigned_team")


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Incidents (core entity with PostGIS geography)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class Incident(Base):
    __tablename__ = "incidents"

    incident_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    reporter_id = Column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True
    )
    animal_type = Column(String(50), nullable=True)
    description = Column(Text, nullable=True)

    # Mock SQLite location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address_text = Column(Text, nullable=True)

    # Image evidence
    image_url = Column(String(512), nullable=False)

    # AI triage results
    ai_confidence = Column(Float, nullable=True)
    severity = Column(
        Enum(SeverityLevel, name="severity_level", create_type=True),
        default=SeverityLevel.UNKNOWN,
    )

    # Workflow state machine
    status = Column(
        Enum(IncidentStatus, name="incident_status", create_type=True),
        default=IncidentStatus.REPORTED,
    )
    assigned_team_id = Column(
        UUID(as_uuid=True), ForeignKey("rescue_teams.team_id"), nullable=True
    )

    # Audit timestamps
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    verified_at = Column(DateTime(timezone=True), nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    reporter = relationship("User", back_populates="incidents")
    assigned_team = relationship("RescueTeam", back_populates="assigned_incidents")
