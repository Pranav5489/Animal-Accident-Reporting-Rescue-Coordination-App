/**
 * API service for the React Admin Dashboard.
 * Typed fetch wrapper for communicating with the FastAPI backend.
 */

import type { Incident, IncidentStatus } from '../types';

// ── Configuration ──────────────────────────────────────────
// Change to your deployed backend URL in production
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api/v1';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Fetch Incidents
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface FetchIncidentsParams {
  lat?: number;
  lon?: number;
  radius_km?: number;
  status?: IncidentStatus;
  severity?: string;
  limit?: number;
  offset?: number;
}

/**
 * Fetch incidents with optional spatial and filter parameters.
 * If lat/lon are provided, results are sorted by proximity.
 */
export async function fetchIncidents(params: FetchIncidentsParams = {}): Promise<Incident[]> {
  const searchParams = new URLSearchParams();

  if (params.lat !== undefined) searchParams.set('lat', params.lat.toString());
  if (params.lon !== undefined) searchParams.set('lon', params.lon.toString());
  if (params.radius_km !== undefined) searchParams.set('radius_km', params.radius_km.toString());
  if (params.status) searchParams.set('status', params.status);
  if (params.severity) searchParams.set('severity', params.severity);
  if (params.limit !== undefined) searchParams.set('limit', params.limit.toString());
  if (params.offset !== undefined) searchParams.set('offset', params.offset.toString());

  const url = `${API_BASE_URL}/incidents?${searchParams.toString()}`;
  const response = await fetch(url);

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to fetch incidents (${response.status}): ${errorText}`);
  }

  return response.json();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Get Single Incident
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export async function getIncident(incidentId: string): Promise<Incident> {
  const response = await fetch(`${API_BASE_URL}/incidents/${incidentId}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch incident ${incidentId}: ${response.statusText}`);
  }

  return response.json();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Update Incident Status
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface StatusUpdatePayload {
  status: IncidentStatus;
  assigned_team_id?: string;
}

export async function updateIncidentStatus(
  incidentId: string,
  payload: StatusUpdatePayload
): Promise<Incident> {
  const response = await fetch(`${API_BASE_URL}/incidents/${incidentId}/status`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to update status (${response.status}): ${errorText}`);
  }

  return response.json();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Image URL Helper
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const BACKEND_BASE = import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000';

/**
 * Converts a relative image path (e.g., /uploads/abc.jpg)
 * to a full URL pointing at the FastAPI static file server.
 */
export function getImageUrl(relativePath: string): string {
  if (relativePath.startsWith('http')) return relativePath;
  return `${BACKEND_BASE}${relativePath}`;
}
