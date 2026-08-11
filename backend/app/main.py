"""
FastAPI application factory.

Mounts routers, configures CORS, serves uploaded images,
and initializes the database schema on startup.
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.database import engine, Base
from app.routes import incidents, teams
from app.firebase import init_firebase

settings = get_settings()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Lifespan: runs on app startup / shutdown
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup: Create all tables if they don't exist.
    Requires PostgreSQL with PostGIS extension already enabled.
    Run `CREATE EXTENSION IF NOT EXISTS postgis;` in your DB first.
    """
    # Create tables from ORM models (includes PostGIS Geography columns)
    Base.metadata.create_all(bind=engine)

    # Ensure upload directory exists
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    
    # Initialize Firebase
    init_firebase()

    print("✅ Database tables created / verified")
    print(f"📂 Uploads directory: {os.path.abspath(settings.UPLOAD_DIR)}")

    yield  # App is running

    # Shutdown cleanup (if needed)
    print("🛑 Application shutting down")


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# App Factory
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

app = FastAPI(
    title="Animal Rescue API",
    description=(
        "SIH1492 — Incident Triage & Dispatch Engine. "
        "Receives citizen reports with photo + GPS, runs AI verification, "
        "and dispatches nearest rescue teams via PostGIS KNN spatial queries."
    ),
    version="1.0.0-mvp",
    lifespan=lifespan,
)

# ── CORS Middleware ───────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Static file serving for uploaded images ───────────────
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# ── Router Registration ──────────────────────────────────
app.include_router(incidents.router, prefix="/api/v1")
app.include_router(teams.router, prefix="/api/v1")


# ── Health Check ──────────────────────────────────────────
@app.get("/health", tags=["System"])
def health_check():
    """Simple health check for load balancers and monitoring."""
    return {"status": "healthy", "version": "1.0.0-mvp"}
