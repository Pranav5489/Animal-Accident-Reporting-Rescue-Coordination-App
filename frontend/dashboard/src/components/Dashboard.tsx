/**
 * Dashboard — Main admin panel combining MapView + IncidentTable.
 *
 * Layout: Split-panel — map (left 60%) + incident list (right 40%)
 * Features:
 *   - Auto-fetches incidents on mount with polling refresh
 *   - Status/severity filter dropdowns
 *   - Synced selection between map markers and table rows
 *   - Real-time stats header (total, critical, active)
 */

import { useState, useEffect, useCallback } from 'react';
import MapView from './MapView';
import IncidentTable from './IncidentTable';
import { fetchIncidents } from '../services/api';
import type { Incident, IncidentStatus, SeverityLevel } from '../types';

const POLL_INTERVAL_MS = 30_000; // Auto-refresh every 30 seconds

export default function Dashboard() {
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date());

  // Filters
  const [statusFilter, setStatusFilter] = useState<IncidentStatus | ''>('');
  const [severityFilter, setSeverityFilter] = useState<SeverityLevel | ''>('');

  // ── Fetch Incidents ──────────────────────────────────────
  const loadIncidents = useCallback(async () => {
    try {
      setError(null);
      const data = await fetchIncidents({
        status: statusFilter || undefined,
        severity: severityFilter || undefined,
        limit: 100,
      });
      setIncidents(data);
      setLastRefresh(new Date());
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setIsLoading(false);
    }
  }, [statusFilter, severityFilter]);

  // Initial load + polling
  useEffect(() => {
    loadIncidents();
    const interval = setInterval(loadIncidents, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [loadIncidents]);

  // ── Selection Handler ────────────────────────────────────
  const handleSelect = (incident: Incident) => {
    setSelectedId(
      incident.incident_id === selectedId ? null : incident.incident_id
    );
  };

  // ── Stats ────────────────────────────────────────────────
  const stats = {
    total: incidents.length,
    critical: incidents.filter((i) => i.severity === 'CRITICAL').length,
    active: incidents.filter((i) =>
      ['REPORTED', 'VERIFIED', 'ASSIGNED', 'IN_PROGRESS'].includes(i.status)
    ).length,
    resolved: incidents.filter((i) => i.status === 'RESOLVED').length,
  };

  return (
    <div className="dashboard">
      {/* ── Header ──────────────────────────────────────── */}
      <header className="dashboard-header">
        <div className="header-left">
          <h1 className="header-title">
            <span className="header-icon">🐾</span>
            Animal Rescue Command Center
          </h1>
          <p className="header-subtitle">
            SIH1492 — Real-time Incident Triage & Dispatch
          </p>
        </div>

        <div className="header-right">
          <div className="stat-pills">
            <div className="stat-pill stat-total">
              <span className="stat-number">{stats.total}</span>
              <span className="stat-label">Total</span>
            </div>
            <div className="stat-pill stat-critical">
              <span className="stat-number">{stats.critical}</span>
              <span className="stat-label">Critical</span>
            </div>
            <div className="stat-pill stat-active">
              <span className="stat-number">{stats.active}</span>
              <span className="stat-label">Active</span>
            </div>
            <div className="stat-pill stat-resolved">
              <span className="stat-number">{stats.resolved}</span>
              <span className="stat-label">Resolved</span>
            </div>
          </div>
        </div>
      </header>

      {/* ── Filter Bar ──────────────────────────────────── */}
      <div className="filter-bar">
        <div className="filter-group">
          <label htmlFor="status-filter">Status</label>
          <select
            id="status-filter"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as IncidentStatus | '')}
          >
            <option value="">All Statuses</option>
            <option value="REPORTED">Reported</option>
            <option value="VERIFIED">Verified</option>
            <option value="ASSIGNED">Assigned</option>
            <option value="IN_PROGRESS">In Progress</option>
            <option value="RESOLVED">Resolved</option>
            <option value="REJECTED">Rejected</option>
          </select>
        </div>

        <div className="filter-group">
          <label htmlFor="severity-filter">Severity</label>
          <select
            id="severity-filter"
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value as SeverityLevel | '')}
          >
            <option value="">All Severities</option>
            <option value="CRITICAL">🔴 Critical</option>
            <option value="HIGH">🟠 High</option>
            <option value="MEDIUM">🟡 Medium</option>
            <option value="LOW">🟢 Low</option>
            <option value="UNKNOWN">⚪ Unknown</option>
          </select>
        </div>

        <div className="filter-actions">
          <button className="btn-refresh" onClick={loadIncidents} disabled={isLoading}>
            {isLoading ? '⏳' : '🔄'} Refresh
          </button>
          <span className="last-refresh">
            Updated {lastRefresh.toLocaleTimeString()}
          </span>
        </div>
      </div>

      {/* ── Error Banner ────────────────────────────────── */}
      {error && (
        <div className="error-banner">
          <span>⚠️ {error}</span>
          <button onClick={loadIncidents}>Retry</button>
        </div>
      )}

      {/* ── Split Panel: Map + Table ────────────────────── */}
      <div className="split-panel">
        <div className="panel-map">
          <MapView
            incidents={incidents}
            selectedId={selectedId}
            onSelect={handleSelect}
          />
        </div>

        <div className="panel-table">
          <IncidentTable
            incidents={incidents}
            selectedId={selectedId}
            onSelect={handleSelect}
            onRefresh={loadIncidents}
          />
        </div>
      </div>
    </div>
  );
}
