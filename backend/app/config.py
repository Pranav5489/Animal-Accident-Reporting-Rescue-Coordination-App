"""
Application configuration loaded from environment variables.
Uses pydantic-settings for type-safe, validated config management.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Central configuration class — all values sourced from .env file."""

    # ── Database ──────────────────────────────────────────
    DATABASE_URL: str = "sqlite:///./animal_rescue.db"

    # ── Security / JWT ────────────────────────────────────
    SECRET_KEY: str = "dev-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours

    # ── File Storage ──────────────────────────────────────
    UPLOAD_DIR: str = "./uploads"

    # ── Firebase ──────────────────────────────────────────
    FIREBASE_CREDENTIALS_PATH: str = ""

    # ── CORS ──────────────────────────────────────────────
    CORS_ORIGINS: str = "http://localhost:5173,http://localhost:3000"

    @property
    def cors_origin_list(self) -> list[str]:
        """Parse comma-separated CORS origins into a list."""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": True,
    }


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton — avoids re-reading .env on every call."""
    return Settings()
