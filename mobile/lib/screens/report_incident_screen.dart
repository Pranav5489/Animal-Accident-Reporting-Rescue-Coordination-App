import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/offline_queue_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  File? _imageFile;
  Position? _currentPosition;
  bool _isLoading = false;
  
  // Use 10.0.2.2 for Android Emulator connecting to localhost backend
  // Change to your actual backend IP/URL when running on a physical device
  final String _apiUrl = 'http://10.0.2.2:8000/api/v1/incidents';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _captureImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80, // Compress to save bandwidth
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      // Auto-fetch location when image is captured
      _getLocation();
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _submitReport() async {
    if (_imageFile == null || _currentPosition == null) {
      _showSnackBar('Please capture an image and ensure GPS is located.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      
      // Attach Metadata
      request.fields['latitude'] = _currentPosition!.latitude.toString();
      request.fields['longitude'] = _currentPosition!.longitude.toString();
      request.fields['description'] = _descriptionController.text;
      
      // Attach Image File
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path)
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _showSnackBar('✅ Emergency reported successfully!');
        setState(() {
          _imageFile = null;
          _currentPosition = null;
          _descriptionController.clear();
        });
      } else {
        _showSnackBar('❌ Failed to report: ${response.statusCode}');
      }
    } catch (e) {
      if (e is SocketException || e.toString().contains('Timeout') || e.toString().contains('Network')) {
        await OfflineQueueService().saveIncidentOffline(
          imagePath: _imageFile!.path,
          latitude: _currentPosition!.latitude.toString(),
          longitude: _currentPosition!.longitude.toString(),
          description: _descriptionController.text,
        );
        _showSnackBar('📡 No network. Report saved offline and will sync later.');
        setState(() {
          _imageFile = null;
          _currentPosition = null;
          _descriptionController.clear();
        });
      } else {
        _showSnackBar('❌ Network Error. Please try again.');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Animal Emergency', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Area
            GestureDetector(
              onTap: _captureImage,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap to Take Photo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Location Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _currentPosition != null ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on, 
                    color: _currentPosition != null ? Colors.green : Colors.orange
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPosition != null 
                          ? 'GPS Locked: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                          : 'Waiting for GPS...',
                      style: TextStyle(
                        color: _currentPosition != null ? Colors.green[800] : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Description Field
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Add context (e.g., bleeding, on the highway)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 30),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text(
                      '🚨 SUBMIT REPORT', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
