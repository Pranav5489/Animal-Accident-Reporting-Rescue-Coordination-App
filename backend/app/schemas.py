"""
Pydantic request/response schemas for the Incident Triage API.
Strict type validation ensures clean data enters PostGIS.
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
from uuid import UUID
from enum import Enum


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enums (mirror ORM enums for schema validation)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class IncidentStatusSchema(str, Enum):
    REPORTED = "REPORTED"
    VERIFIED = "VERIFIED"
    ASSIGNED = "ASSIGNED"
    IN_PROGRESS = "IN_PROGRESS"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"


class SeverityLevelSchema(str, Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    UNKNOWN = "UNKNOWN"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Incident Schemas
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class IncidentCreate(BaseModel):
    """
    Schema for creating a new incident via multipart form.
    Image is handled separately as UploadFile; these fields come
    as form data or JSON body alongside the image.
    """
    latitude: float = Field(..., ge=-90, le=90, description="WGS84 latitude")
    longitude: float = Field(..., ge=-180, le=180, description="WGS84 longitude")
    animal_type: Optional[str] = Field(None, max_length=50, description="e.g. Dog, Cat, Cow")
    description: Optional[str] = Field(None, max_length=2000)
    address_text: Optional[str] = Field(None, max_length=500)
    reporter_id: Optional[UUID] = None
    severity: Optional[SeverityLevelSchema] = SeverityLevelSchema.UNKNOWN

    @field_validator("latitude")
    @classmethod
    def validate_latitude(cls, v: float) -> float:
        if not -90 <= v <= 90:
            raise ValueError("Latitude must be between -90 and 90")
        return round(v, 8)

    @field_validator("longitude")
    @classmethod
    def validate_longitude(cls, v: float) -> float:
        if not -180 <= v <= 180:
            raise ValueError("Longitude must be between -180 and 180")
        return round(v, 8)


class IncidentResponse(BaseModel):
    """Full incident detail returned from the API."""
    incident_id: UUID
    reporter_id: Optional[UUID] = None
    animal_type: Optional[str] = None
    description: Optional[str] = None
    latitude: float
    longitude: float
    address_text: Optional[str] = None
    image_url: str
    ai_confidence: Optional[float] = None
    severity: SeverityLevelSchema
    status: IncidentStatusSchema
    assigned_team_id: Optional[UUID] = None
    created_at: datetime
    verified_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class IncidentListResponse(BaseModel):
    """Incident with computed distance from query point."""
    incident_id: UUID
    animal_type: Optional[str] = None
    latitude: float
    longitude: float
    image_url: str
    severity: SeverityLevelSchema
    status: IncidentStatusSchema
    distance_km: Optional[float] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class StatusUpdate(BaseModel):
    """Schema for PATCH status transitions."""
    status: IncidentStatusSchema
    assigned_team_id: Optional[UUID] = None


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Rescue Team Schemas
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class NearbyTeamResponse(BaseModel):
    """Rescue team with distance from incident point."""
    team_id: UUID
    ngo_name: str
    is_available: bool
    distance_km: float
    last_ping: Optional[datetime] = None

    model_config = {"from_attributes": True}


class NearbyQuery(BaseModel):
    """Query parameters for spatial proximity searches."""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(default=50.0, ge=0.1, le=500.0, description="Search radius in km")
    limit: int = Field(default=20, ge=1, le=100)
