/**
 * IncidentTable — Sortable, filterable table displaying incident reports.
 *
 * Features:
 *   - Severity and status badges with color coding
 *   - Row selection highlight synced with map
 *   - Status transition action buttons
 *   - Time-ago formatting for created_at timestamps
 *   - Image thumbnail preview
 */

import type { Incident, IncidentStatus, SeverityLevel } from '../types';
import { SEVERITY_COLORS, STATUS_COLORS } from '../types';
import { getImageUrl, updateIncidentStatus } from '../services/api';

interface IncidentTableProps {
  incidents: Incident[];
  selectedId: string | null;
  onSelect: (incident: Incident) => void;
  onRefresh: () => void;
}

/** Format a date string as relative time (e.g., "2h ago") */
function timeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diffMs = now - then;
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return 'Just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDay = Math.floor(diffHr / 24);
  return `${diffDay}d ago`;
}

/** Valid next states for each status */
const NEXT_ACTIONS: Partial<Record<IncidentStatus, { label: string; next: IncidentStatus }[]>> = {
  REPORTED: [
    { label: '✓ Verify', next: 'VERIFIED' },
    { label: '✗ Reject', next: 'REJECTED' },
  ],
  VERIFIED: [
    { label: '📋 Assign', next: 'ASSIGNED' },
  ],
  ASSIGNED: [
    { label: '▶ Start', next: 'IN_PROGRESS' },
  ],
  IN_PROGRESS: [
    { label: '✔ Resolve', next: 'RESOLVED' },
  ],
};

export default function IncidentTable({ incidents, selectedId, onSelect, onRefresh }: IncidentTableProps) {

  const handleStatusChange = async (incidentId: string, newStatus: IncidentStatus) => {
    try {
      await updateIncidentStatus(incidentId, { status: newStatus });
      onRefresh(); // Re-fetch to reflect the update
    } catch (err) {
      console.error('Status update failed:', err);
      alert(`Failed to update status: ${(err as Error).message}`);
    }
  };

  if (incidents.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-icon">📋</div>
        <h3>No Incidents Found</h3>
        <p>No animal incident reports match your current filters.</p>
      </div>
    );
  }

  return (
    <div className="table-container">
      <div className="table-header">
        <h3>📋 Incident Reports</h3>
        <span className="badge badge-count">{incidents.length} total</span>
      </div>

      <div className="table-scroll">
        {incidents.map((incident) => {
          const isSelected = incident.incident_id === selectedId;
          const severityColor = SEVERITY_COLORS[incident.severity as SeverityLevel] || '#6B7280';
          const statusColor = STATUS_COLORS[incident.status as IncidentStatus] || '#6B7280';
          const actions = NEXT_ACTIONS[incident.status as IncidentStatus] || [];

          return (
            <div
              key={incident.incident_id}
              className={`incident-card ${isSelected ? 'selected' : ''}`}
              onClick={() => onSelect(incident)}
            >
              {/* Top row: animal type + severity badge */}
              <div className="card-top">
                <div className="card-title-row">
                  {incident.image_url && (
                    <img
                      src={getImageUrl(incident.image_url)}
                      alt=""
                      className="card-thumbnail"
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = 'none';
                      }}
                    />
                  )}
                  <div>
                    <div className="card-animal">
                      {incident.animal_type || 'Unknown Animal'}
                    </div>
                    <div className="card-time">{timeAgo(incident.created_at)}</div>
                  </div>
                </div>

                <div className="card-badges">
                  <span
                    className="badge"
                    style={{ backgroundColor: severityColor }}
                  >
                    {incident.severity}
                  </span>
                  <span
                    className="badge badge-outline"
                    style={{ borderColor: statusColor, color: statusColor }}
                  >
                    {incident.status.replace('_', ' ')}
                  </span>
                </div>
              </div>

              {/* Description (truncated) */}
              {incident.description && (
                <p className="card-description">
                  {incident.description.length > 100
                    ? incident.description.slice(0, 100) + '…'
                    : incident.description}
                </p>
              )}

              {/* Coordinates + Distance */}
              <div className="card-meta">
                <span className="card-coords">
                  📍 {incident.latitude.toFixed(4)}, {incident.longitude.toFixed(4)}
                </span>
                {incident.distance_km != null && (
                  <span className="card-distance">
                    {incident.distance_km.toFixed(1)} km away
                  </span>
                )}
              </div>

              {/* Action buttons */}
              {actions.length > 0 && (
                <div className="card-actions">
                  {actions.map((action) => (
                    <button
                      key={action.next}
                      className={`action-btn ${action.next === 'REJECTED' ? 'action-danger' : 'action-primary'}`}
                      onClick={(e) => {
                        e.stopPropagation();
                        handleStatusChange(incident.incident_id, action.next);
                      }}
                    >
                      {action.label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
