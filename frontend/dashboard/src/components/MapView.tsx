/**
 * MapView — Interactive Leaflet map displaying incident markers.
 *
 * Features:
 *   - Severity-colored circular markers (CRITICAL=red, HIGH=orange, etc.)
 *   - Popup cards on click with incident summary + image thumbnail
 *   - Selected incident highlight with pulsing ring
 *   - Auto-fits bounds to show all markers on load
 */

import { useEffect, useRef } from 'react';
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from 'react-leaflet';
import type { Incident } from '../types';
import { SEVERITY_COLORS } from '../types';
import { getImageUrl } from '../services/api';
import 'leaflet/dist/leaflet.css';

interface MapViewProps {
  incidents: Incident[];
  selectedId: string | null;
  onSelect: (incident: Incident) => void;
}

/** Auto-fit map bounds to show all markers */
function FitBounds({ incidents }: { incidents: Incident[] }) {
  const map = useMap();

  useEffect(() => {
    if (incidents.length === 0) return;

    const bounds = incidents.map(
      (inc) => [inc.latitude, inc.longitude] as [number, number]
    );

    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 });
  }, [incidents, map]);

  return null;
}

export default function MapView({ incidents, selectedId, onSelect }: MapViewProps) {
  const mapRef = useRef(null);

  // Default center: India (for SIH context)
  const defaultCenter: [number, number] = [20.5937, 78.9629];
  const defaultZoom = 5;

  return (
    <div style={{ height: '100%', width: '100%', borderRadius: '12px', overflow: 'hidden' }}>
      <MapContainer
        center={defaultCenter}
        zoom={defaultZoom}
        ref={mapRef}
        style={{ height: '100%', width: '100%' }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        <FitBounds incidents={incidents} />

        {incidents.map((incident) => {
          const isSelected = incident.incident_id === selectedId;
          const color = SEVERITY_COLORS[incident.severity] || '#6B7280';

          return (
            <CircleMarker
              key={incident.incident_id}
              center={[incident.latitude, incident.longitude]}
              radius={isSelected ? 12 : 8}
              pathOptions={{
                color: isSelected ? '#1E40AF' : color,
                fillColor: color,
                fillOpacity: isSelected ? 0.9 : 0.7,
                weight: isSelected ? 3 : 2,
              }}
              eventHandlers={{
                click: () => onSelect(incident),
              }}
            >
              <Popup maxWidth={280} minWidth={200}>
                <div style={{ fontFamily: 'Inter, system-ui, sans-serif' }}>
                  <div style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: '8px',
                  }}>
                    <strong style={{ fontSize: '14px' }}>
                      {incident.animal_type || 'Unknown Animal'}
                    </strong>
                    <span style={{
                      backgroundColor: color,
                      color: 'white',
                      padding: '2px 8px',
                      borderRadius: '10px',
                      fontSize: '11px',
                      fontWeight: 600,
                    }}>
                      {incident.severity}
                    </span>
                  </div>

                  {incident.image_url && (
                    <img
                      src={getImageUrl(incident.image_url)}
                      alt="Incident"
                      style={{
                        width: '100%',
                        height: '120px',
                        objectFit: 'cover',
                        borderRadius: '6px',
                        marginBottom: '8px',
                      }}
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = 'none';
                      }}
                    />
                  )}

                  <p style={{
                    fontSize: '12px',
                    color: '#4B5563',
                    margin: '4px 0',
                    lineHeight: '1.4',
                  }}>
                    {incident.description || 'No description provided'}
                  </p>

                  <div style={{
                    fontSize: '11px',
                    color: '#9CA3AF',
                    marginTop: '6px',
                    display: 'flex',
                    justifyContent: 'space-between',
                  }}>
                    <span>Status: <strong>{incident.status}</strong></span>
                    <span>{new Date(incident.created_at).toLocaleDateString()}</span>
                  </div>
                </div>
              </Popup>
            </CircleMarker>
          );
        })}
      </MapContainer>
    </div>
  );
}
