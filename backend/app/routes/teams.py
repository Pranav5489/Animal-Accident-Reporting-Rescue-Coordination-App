"""
Rescue Team spatial routes for KNN dispatch.

Endpoints:
  GET  /teams/nearby — Find nearest available rescue teams to an incident point
"""

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy.orm import Session
import math

from app.database import get_db
from app.models import RescueTeam
from app.schemas import NearbyTeamResponse

router = APIRouter(prefix="/teams", tags=["Rescue Teams"])


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GET /teams/nearby — KNN dispatch query
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


@router.get(
    "/nearby",
    response_model=list[NearbyTeamResponse],
    summary="Find nearest available rescue teams",
)
def find_nearby_teams(
    lat: float = Query(..., ge=-90, le=90, description="Incident latitude"),
    lon: float = Query(..., ge=-180, le=180, description="Incident longitude"),
    radius_km: float = Query(50.0, ge=0.1, le=500.0, description="Max search radius in km"),
    limit: int = Query(5, ge=1, le=20, description="Max teams to return"),
    db: Session = Depends(get_db),
):
    """
    Mock KNN dispatch query. Uses Python math on lat/lon.
    """
    # Fetch all available teams with locations
    teams = db.query(RescueTeam).filter(
        RescueTeam.is_available.is_(True),
        RescueTeam.latitude.isnot(None),
        RescueTeam.longitude.isnot(None)
    ).all()
    
    def calc_dist(t):
        return math.sqrt((t.latitude - lat)**2 + (t.longitude - lon)**2) * 111.0 # approx km

    # Filter and sort
    results = [(t, calc_dist(t)) for t in teams if calc_dist(t) <= radius_km]
    results.sort(key=lambda x: x[1])
    
    results = results[:limit]

    return [
        NearbyTeamResponse(
            team_id=team.team_id,
            ngo_name=team.ngo_name,
            is_available=team.is_available,
            distance_km=round(dist, 3),
            last_ping=team.last_ping,
        )
        for team, dist in results
    ]
