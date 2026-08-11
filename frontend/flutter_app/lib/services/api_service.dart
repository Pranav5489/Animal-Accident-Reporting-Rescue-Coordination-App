/// HTTP client wrapper for communicating with the Animal Rescue FastAPI backend.
///
/// Provides typed methods for:
///   - `submitIncident()` — multipart/form-data upload with image + GPS
///   - `fetchNearbyIncidents()` — spatial radius query
///
/// Configure the base URL via the `_baseUrl` constant.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/incident_model.dart';

class ApiService {
  // ── Configuration ────────────────────────────────────────
  // Change this to your deployed backend URL in production.
  // For Android emulator use 10.0.2.2; for iOS simulator use localhost.
  static const String _baseUrl = 'http://10.0.2.2:8000/api/v1';

  static const Duration _timeout = Duration(seconds: 30);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // POST /incidents — Submit a new incident report
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Uploads an incident report with photo + GPS as multipart/form-data.
  ///
  /// [imageFile] — The captured photo file from the device camera.
  /// [latitude]  — WGS84 latitude from Geolocator.
  /// [longitude] — WGS84 longitude from Geolocator.
  /// [animalType] — Optional species identifier (e.g., "Dog", "Cow").
  /// [description] — Optional free-text description of the situation.
  ///
  /// Returns the created [Incident] on success, or throws on failure.
  static Future<Incident> submitIncident({
    required File imageFile,
    required double latitude,
    required double longitude,
    String? animalType,
    String? description,
    String? addressText,
  }) async {
    final uri = Uri.parse('$_baseUrl/incidents');

    // Build multipart request
    final request = http.MultipartRequest('POST', uri)
      ..fields['latitude'] = latitude.toString()
      ..fields['longitude'] = longitude.toString();

    // Attach optional metadata fields
    if (animalType != null && animalType.isNotEmpty) {
      request.fields['animal_type'] = animalType;
    }
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    if (addressText != null && addressText.isNotEmpty) {
      request.fields['address_text'] = addressText;
    }

    // Attach image file
    final mimeType = _getMimeType(imageFile.path);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image', // Must match FastAPI's parameter name
        imageFile.path,
        contentType: http.MediaType.parse(mimeType),
      ),
    );

    // Send request with timeout
    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Incident.fromJson(json);
    } else {
      final errorBody = response.body;
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to submit incident: $errorBody',
      );
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GET /incidents — Fetch nearby incidents
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Fetches incidents within [radiusKm] of the given coordinates.
  ///
  /// Results are sorted by ascending distance from the query point.
  static Future<List<Incident>> fetchNearbyIncidents({
    required double latitude,
    required double longitude,
    double radiusKm = 50.0,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/incidents').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
      },
    );

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      return jsonList
          .map((json) => Incident.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to fetch incidents: ${response.body}',
      );
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Helpers
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Infer MIME type from file extension.
  static String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

/// Custom exception for API errors with status code context.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
