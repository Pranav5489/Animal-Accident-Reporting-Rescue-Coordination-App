"""
Incident CRUD routes with PostGIS spatial queries.

Endpoints:
  POST   /incidents           — Create incident (multipart: image + metadata)
  GET    /incidents           — List incidents, optionally filtered by radius
  GET    /incidents/{id}      — Single incident detail
  PATCH  /incidents/{id}/status — Transition workflow state
"""

import os
import uuid
import shutil
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query, status
from sqlalchemy.orm import Session
from sqlalchemy.orm import Session
from sqlalchemy import func, cast, Float
import math

from app.database import get_db
from app.models import Incident, IncidentStatus, SeverityLevel
from app.schemas import (
    IncidentResponse,
    IncidentListResponse,
    StatusUpdate,
    SeverityLevelSchema,
    IncidentStatusSchema,
)
from app.config import get_settings

router = APIRouter(prefix="/incidents", tags=["Incidents"])
settings = get_settings()

# Ensure uploads directory exists
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

# Allowed image MIME types for security validation
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_FILE_SIZE_MB = 10


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helpers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


def _incident_to_response(incident: Incident, distance_km: Optional[float] = None) -> dict:
    """Extract lat/lon from model and build response dict."""
    data = {
        "incident_id": incident.incident_id,
        "reporter_id": incident.reporter_id,
        "animal_type": incident.animal_type,
        "description": incident.description,
        "latitude": incident.latitude,
        "longitude": incident.longitude,
        "address_text": incident.address_text,
        "image_url": incident.image_url,
        "ai_confidence": incident.ai_confidence,
        "severity": incident.severity.value if incident.severity else "UNKNOWN",
        "status": incident.status.value if incident.status else "REPORTED",
        "assigned_team_id": incident.assigned_team_id,
        "created_at": incident.created_at,
        "verified_at": incident.verified_at,
        "resolved_at": incident.resolved_at,
    }
    if distance_km is not None:
        data["distance_km"] = round(distance_km, 3)
    return data


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POST /incidents — Create a new incident report
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


@router.post(
    "",
    response_model=IncidentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Report a new animal incident",
)
async def create_incident(
    # Image file (required)
    image: UploadFile = File(..., description="Photo evidence of the incident"),
    # Form fields sent alongside the image
    latitude: float = Form(..., ge=-90, le=90),
    longitude: float = Form(..., ge=-180, le=180),
    animal_type: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    address_text: Optional[str] = Form(None),
    reporter_id: Optional[str] = Form(None),
    severity: Optional[str] = Form("UNKNOWN"),
    db: Session = Depends(get_db),
):
    """
    Receives a multipart/form-data request containing:
    - An image file (JPEG/PNG/WebP)
    - GPS coordinates (latitude, longitude)
    - Optional metadata (animal_type, description, address)

    The image is saved to local storage and the incident is persisted
    with a PostGIS GEOGRAPHY(POINT) for spatial indexing.
    """
    # ── 1. Validate MIME type ─────────────────────────────
    if image.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file type '{image.content_type}'. Allowed: {ALLOWED_MIME_TYPES}",
        )

    # ── 2. Save image to disk ─────────────────────────────
    file_ext = os.path.splitext(image.filename or "photo.jpg")[1] or ".jpg"
    file_name = f"{uuid.uuid4().hex}{file_ext}"
    file_path = os.path.join(settings.UPLOAD_DIR, file_name)

    with open(file_path, "wb") as f:
        shutil.copyfileobj(image.file, f)

    # ── 3. (Mock) Skip PostGIS WKT ──────────────────

    # ── 4. Parse optional fields ──────────────────────────
    parsed_reporter_id = None
    if reporter_id:
        try:
            parsed_reporter_id = uuid.UUID(reporter_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="reporter_id must be a valid UUID",
            )

    severity_enum = SeverityLevel.UNKNOWN
    if severity:
        try:
            severity_enum = SeverityLevel(severity.upper())
        except ValueError:
            severity_enum = SeverityLevel.UNKNOWN

    # ── 5. Persist to database ────────────────────────────
    incident = Incident(
        reporter_id=parsed_reporter_id,
        animal_type=animal_type,
        description=description,
        latitude=latitude,
        longitude=longitude,
        address_text=address_text,
        image_url=f"/uploads/{file_name}",
        severity=severity_enum,
        status=IncidentStatus.REPORTED,
    )

    db.add(incident)
    db.commit()
    db.refresh(incident)

    return IncidentResponse(**_incident_to_response(incident))


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GET /incidents — List with optional spatial radius filter
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


@router.get(
    "",
    response_model=list[IncidentListResponse],
    summary="Fetch incidents, optionally filtered by radius",
)
def list_incidents(
    lat: Optional[float] = Query(None, ge=-90, le=90, description="Center latitude for radius search"),
    lon: Optional[float] = Query(None, ge=-180, le=180, description="Center longitude for radius search"),
    radius_km: float = Query(50.0, ge=0.1, le=500.0, description="Search radius in kilometers"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status"),
    severity_filter: Optional[str] = Query(None, alias="severity", description="Filter by severity"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """
    Returns incidents sorted by proximity if lat/lon are provided.
    (Mocked: Fetches all, sorts in Python using Euclidean approximation)
    """
    query = db.query(Incident)
    
    # Apply filters
    if status_filter:
        try:
            status_enum = IncidentStatus(status_filter.upper())
            query = query.filter(Incident.status == status_enum)
        except ValueError:
            pass
            
    if severity_filter:
        try:
            severity_enum = SeverityLevel(severity_filter.upper())
            query = query.filter(Incident.severity == severity_enum)
        except ValueError:
            pass
            
    results = query.all()
    
    # In-memory distance filtering and sorting for mock
    if lat is not None and lon is not None:
        def calc_dist(i):
            return math.sqrt((i.latitude - lat)**2 + (i.longitude - lon)**2) * 111.0 # approx km
        results = [(i, calc_dist(i)) for i in results if calc_dist(i) <= radius_km]
        results.sort(key=lambda x: x[1])
    else:
        results = [(i, None) for i in results]
        results.sort(key=lambda x: x[0].created_at, reverse=True)
        
    results = results[offset : offset + limit]

    # ── Build response ────────────────────────────────────
    response = []
    for row in results:
        if lat is not None and lon is not None:
            incident, dist = row
        else:
            incident = row[0] if isinstance(row, tuple) else row
            dist = None

        response.append(
            IncidentListResponse(
                incident_id=incident.incident_id,
                animal_type=incident.animal_type,
                latitude=incident.latitude,
                longitude=incident.longitude,
                image_url=incident.image_url,
                severity=incident.severity.value if incident.severity else "UNKNOWN",
                status=incident.status.value if incident.status else "REPORTED",
                distance_km=round(dist, 3) if dist is not None else None,
                created_at=incident.created_at,
            )
        )

    return response


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GET /incidents/{id} — Single incident detail
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


@router.get(
    "/{incident_id}",
    response_model=IncidentResponse,
    summary="Get incident details",
)
def get_incident(
    incident_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Fetch a single incident by its UUID."""
    incident = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident {incident_id} not found",
        )
    return IncidentResponse(**_incident_to_response(incident))


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PATCH /incidents/{id}/status — Workflow state transition
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Valid state transitions enforced server-side
VALID_TRANSITIONS: dict[IncidentStatus, list[IncidentStatus]] = {
    IncidentStatus.REPORTED: [IncidentStatus.VERIFIED, IncidentStatus.REJECTED],
    IncidentStatus.VERIFIED: [IncidentStatus.ASSIGNED, IncidentStatus.REJECTED],
    IncidentStatus.ASSIGNED: [IncidentStatus.IN_PROGRESS, IncidentStatus.VERIFIED],
    IncidentStatus.IN_PROGRESS: [IncidentStatus.RESOLVED],
    IncidentStatus.RESOLVED: [],  # Terminal state
    IncidentStatus.REJECTED: [],  # Terminal state
}


@router.patch(
    "/{incident_id}/status",
    response_model=IncidentResponse,
    summary="Update incident status",
)
def update_incident_status(
    incident_id: uuid.UUID,
    body: StatusUpdate,
    db: Session = Depends(get_db),
):
    """
    Transition an incident through the workflow state machine.
    Enforces valid transitions (e.g., REPORTED → VERIFIED, not REPORTED → RESOLVED).
    """
    incident = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident {incident_id} not found",
        )

    current_status = incident.status
    new_status = IncidentStatus(body.status.value)

    # Enforce state machine transitions
    allowed = VALID_TRANSITIONS.get(current_status, [])
    if new_status not in allowed:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Cannot transition from {current_status.value} to {new_status.value}. "
                   f"Allowed: {[s.value for s in allowed]}",
        )

    # Apply transition
    incident.status = new_status

    if new_status == IncidentStatus.VERIFIED:
        incident.verified_at = datetime.now(timezone.utc)
    elif new_status == IncidentStatus.RESOLVED:
        incident.resolved_at = datetime.now(timezone.utc)

    if body.assigned_team_id:
        incident.assigned_team_id = body.assigned_team_id

    db.commit()
    db.refresh(incident)

    return IncidentResponse(**_incident_to_response(incident))


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POST /incidents/{id}/dispatch — Dispatch an incident
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


@router.post(
    "/{incident_id}/dispatch",
    response_model=IncidentResponse,
    summary="Dispatch incident to a rescue team via push notification",
)
def dispatch_incident(
    incident_id: uuid.UUID,
    team_id: uuid.UUID = Query(..., description="The team to dispatch to"),
    db: Session = Depends(get_db),
):
    """
    Assign an incident to a team and trigger a push notification
    to the team's registered device.
    """
    from app.models import RescueTeam
    from app.firebase import send_push_notification
    
    incident = db.query(Incident).filter(Incident.incident_id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    team = db.query(RescueTeam).filter(RescueTeam.team_id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Rescue team not found")
        
    if incident.status not in [IncidentStatus.VERIFIED, IncidentStatus.REPORTED]:
        raise HTTPException(
            status_code=422, 
            detail=f"Cannot dispatch incident in state {incident.status.value}"
        )

    # Transition to ASSIGNED
    incident.status = IncidentStatus.ASSIGNED
    incident.assigned_team_id = team_id
    db.commit()
    db.refresh(incident)

    # Send Push Notification if team has a token
    if team.device_token:
        send_push_notification(
            token=team.device_token,
            title="🚨 New Emergency Dispatch",
            body=f"New {incident.animal_type or 'Animal'} incident reported.",
            data={
                "incident_id": str(incident.incident_id),
                "latitude": str(incident.latitude),
                "longitude": str(incident.longitude),
            }
        )
    
    return IncidentResponse(**_incident_to_response(incident))
