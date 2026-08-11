/// Data model representing an animal incident report.
///
/// Handles JSON serialization/deserialization for API communication.
/// Mirrors the backend's `IncidentResponse` schema.

class Incident {
  final String incidentId;
  final String? reporterId;
  final String? animalType;
  final String? description;
  final double latitude;
  final double longitude;
  final String? addressText;
  final String imageUrl;
  final double? aiConfidence;
  final String severity;
  final String status;
  final String? assignedTeamId;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final DateTime? resolvedAt;
  final double? distanceKm;

  Incident({
    required this.incidentId,
    this.reporterId,
    this.animalType,
    this.description,
    required this.latitude,
    required this.longitude,
    this.addressText,
    required this.imageUrl,
    this.aiConfidence,
    required this.severity,
    required this.status,
    this.assignedTeamId,
    required this.createdAt,
    this.verifiedAt,
    this.resolvedAt,
    this.distanceKm,
  });

  /// Parse from API JSON response.
  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      incidentId: json['incident_id'] as String,
      reporterId: json['reporter_id'] as String?,
      animalType: json['animal_type'] as String?,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      addressText: json['address_text'] as String?,
      imageUrl: json['image_url'] as String,
      aiConfidence: json['ai_confidence'] != null
          ? (json['ai_confidence'] as num).toDouble()
          : null,
      severity: json['severity'] as String? ?? 'UNKNOWN',
      status: json['status'] as String? ?? 'REPORTED',
      assignedTeamId: json['assigned_team_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
    );
  }

  /// Serialize to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'incident_id': incidentId,
      'reporter_id': reporterId,
      'animal_type': animalType,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address_text': addressText,
      'image_url': imageUrl,
      'ai_confidence': aiConfidence,
      'severity': severity,
      'status': status,
      'assigned_team_id': assignedTeamId,
      'created_at': createdAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'distance_km': distanceKm,
    };
  }

  @override
  String toString() =>
      'Incident(id: $incidentId, animal: $animalType, severity: $severity, status: $status)';
}
