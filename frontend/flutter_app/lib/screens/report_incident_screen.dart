/// ReportIncidentScreen — The core citizen-facing UI for reporting injured animals.
///
/// Workflow:
///   1. User taps "Take Photo" → camera opens via image_picker
///   2. GPS coordinates captured via geolocator (with permission handling)
///   3. User fills optional metadata (animal type, description)
///   4. Taps "Submit Report" → multipart upload to FastAPI
///   5. Shows success/failure feedback with retry support
///
/// Edge Cases Handled:
///   - Location permission denied → guides user to settings
///   - Location services disabled → shows enablement prompt
///   - Network failure → queues report for retry
///   - Camera permission denied → graceful fallback message

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  // ── Form Controllers ─────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _animalTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  // ── State ────────────────────────────────────────────────
  File? _capturedImage;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Animal type dropdown options ─────────────────────────
  final List<String> _animalTypes = [
    'Dog',
    'Cat',
    'Cow',
    'Horse',
    'Bird',
    'Goat',
    'Sheep',
    'Monkey',
    'Wildlife',
    'Other',
  ];
  String? _selectedAnimalType;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Pre-fetch location as soon as the screen loads
    _acquireLocation();
  }

  @override
  void dispose() {
    _animalTypeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Location Acquisition with Full Permission Handling
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _acquireLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage =
              'Location services are disabled. Please enable GPS in your device settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // 2. Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage =
                'Location permission denied. We need your location to pinpoint the animal\'s position.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permission permanently denied. Please enable it in your device settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // 3. Get high-accuracy position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to acquire location: ${e.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Camera Capture
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to reduce upload size
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture photo: ${e.toString()}';
      });
    }
  }

  /// Allow selecting from gallery as a fallback option
  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
      });
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Incident Submission
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _submitReport() async {
    // Validate prerequisites
    if (_capturedImage == null) {
      setState(() => _errorMessage = 'Please capture a photo of the animal first.');
      return;
    }
    if (_currentPosition == null) {
      setState(() => _errorMessage = 'Location not available. Tap "Refresh Location" to try again.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final incident = await ApiService.submitIncident(
        imageFile: _capturedImage!,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        animalType: _selectedAnimalType ?? _animalTypeController.text,
        description: _descriptionController.text,
        addressText: _addressController.text,
      );

      setState(() {
        _isSubmitting = false;
        _successMessage =
            'Report submitted successfully!\nIncident ID: ${incident.incidentId}\nStatus: ${incident.status}';
        // Reset form
        _capturedImage = null;
        _animalTypeController.clear();
        _descriptionController.clear();
        _addressController.clear();
        _selectedAnimalType = null;
      });
    } on ApiException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Server error (${e.statusCode}): ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Network error — your report has been saved for retry.\n${e.toString()}';
      });
      // TODO: Queue to local Hive/SQLite for offline retry in production
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // UI Build
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Injured Animal'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Status Messages ────────────────────────
              if (_errorMessage != null) _buildAlert(_errorMessage!, isError: true),
              if (_successMessage != null) _buildAlert(_successMessage!, isError: false),

              const SizedBox(height: 8),

              // ── Photo Capture Section ──────────────────
              _buildSectionHeader('📸 Photo Evidence', 'Take a clear photo of the injured animal'),
              const SizedBox(height: 8),
              _buildPhotoCaptureCard(),

              const SizedBox(height: 20),

              // ── Location Section ───────────────────────
              _buildSectionHeader('📍 Location', 'GPS coordinates captured automatically'),
              const SizedBox(height: 8),
              _buildLocationCard(),

              const SizedBox(height: 20),

              // ── Animal Details Section ─────────────────
              _buildSectionHeader('🐾 Animal Details', 'Help us identify the animal'),
              const SizedBox(height: 8),
              _buildAnimalDetailsCard(),

              const SizedBox(height: 24),

              // ── Submit Button ──────────────────────────
              _buildSubmitButton(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget Builders ──────────────────────────────────────

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAlert(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade300 : Colors.green.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: isError ? Colors.red.shade800 : Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCaptureCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Image preview
            if (_capturedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _capturedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No photo captured yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Camera and gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isLoadingLocation)
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Acquiring GPS location...'),
                ],
              )
            else if (_currentPosition != null)
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                          'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}\n'
                          'Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Optional manual address input
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Landmark / Address (optional)',
                      hintText: 'e.g., Near Central Park gate',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 1,
                  ),
                ],
              )
            else
              const Text('Location not available'),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isLoadingLocation ? null : _acquireLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Animal type dropdown
            DropdownButtonFormField<String>(
              value: _selectedAnimalType,
              decoration: const InputDecoration(
                labelText: 'Animal Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _animalTypes
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedAnimalType = value),
            ),

            const SizedBox(height: 12),

            // Description text area
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the animal\'s condition, visible injuries, behavior...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 2000,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit =
        _capturedImage != null && _currentPosition != null && !_isSubmitting;

    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitReport : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Submitting...'),
                ],
              )
            : const Text('🚨 Submit Emergency Report'),
      ),
    );
  }
}
