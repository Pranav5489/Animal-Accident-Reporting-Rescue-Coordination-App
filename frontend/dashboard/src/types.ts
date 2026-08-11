/**
 * TypeScript type definitions for the Animal Rescue Dashboard.
 * Mirrors the backend Pydantic schemas for type-safe API communication.
 */

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Enums
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export type IncidentStatus =
  | 'REPORTED'
  | 'VERIFIED'
  | 'ASSIGNED'
  | 'IN_PROGRESS'
  | 'RESOLVED'
  | 'REJECTED';

export type SeverityLevel =
  | 'CRITICAL'
  | 'HIGH'
  | 'MEDIUM'
  | 'LOW'
  | 'UNKNOWN';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Incident
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export interface Incident {
  incident_id: string;
  reporter_id?: string | null;
  animal_type?: string | null;
  description?: string | null;
  latitude: number;
  longitude: number;
  address_text?: string | null;
  image_url: string;
  ai_confidence?: number | null;
  severity: SeverityLevel;
  status: IncidentStatus;
  assigned_team_id?: string | null;
  created_at: string;
  verified_at?: string | null;
  resolved_at?: string | null;
  distance_km?: number | null;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Rescue Team
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export interface RescueTeam {
  team_id: string;
  ngo_name: string;
  is_available: boolean;
  distance_km: number;
  last_ping?: string | null;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UI Helpers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/** Maps severity levels to display colors for markers and badges */
export const SEVERITY_COLORS: Record<SeverityLevel, string> = {
  CRITICAL: '#DC2626', // Red
  HIGH: '#EA580C',     // Orange
  MEDIUM: '#CA8A04',   // Amber
  LOW: '#16A34A',      // Green
  UNKNOWN: '#6B7280',  // Gray
};

/** Maps status to badge colors */
export const STATUS_COLORS: Record<IncidentStatus, string> = {
  REPORTED: '#3B82F6',   // Blue
  VERIFIED: '#8B5CF6',   // Purple
  ASSIGNED: '#F59E0B',   // Amber
  IN_PROGRESS: '#F97316', // Orange
  RESOLVED: '#22C55E',   // Green
  REJECTED: '#EF4444',   // Red
};
