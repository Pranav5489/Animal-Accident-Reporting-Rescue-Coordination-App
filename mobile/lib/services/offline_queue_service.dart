import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Database? _db;
  final String _apiUrl = 'http://10.0.2.2:8000/api/v1/incidents';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'offline_queue.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE incidents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT,
            latitude TEXT,
            longitude TEXT,
            description TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveIncidentOffline({
    required String imagePath,
    required String latitude,
    required String longitude,
    required String description,
  }) async {
    final db = await database;
    await db.insert('incidents', {
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print('✅ Saved to offline queue');
  }

  Future<void> syncPendingIncidents() async {
    final db = await database;
    final List<Map<String, dynamic>> pending = await db.query('incidents');
    
    if (pending.isEmpty) {
      print('📭 No offline incidents to sync.');
      return;
    }
    
    print('🔄 Attempting to sync ${pending.length} offline incidents...');

    for (var incident in pending) {
      try {
        var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
        
        request.fields['latitude'] = incident['latitude'];
        request.fields['longitude'] = incident['longitude'];
        request.fields['description'] = incident['description'];
        
        // Ensure file exists before trying to upload
        File imageFile = File(incident['imagePath']);
        if (await imageFile.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('image', incident['imagePath'])
          );
        } else {
          print('⚠️ Image missing for incident ${incident['id']}, removing from queue.');
          await db.delete('incidents', where: 'id = ?', whereArgs: [incident['id']]);
          continue;
        }

        var streamedResponse = await request.send();
        
        if (streamedResponse.statusCode == 201) {
          // Success, delete from queue
          await db.delete('incidents', where: 'id = ?', whereArgs: [incident['id']]);
          print('✅ Successfully synced incident ${incident['id']}');
        } else {
          print('❌ Failed to sync incident ${incident['id']}: ${streamedResponse.statusCode}');
        }
      } catch (e) {
        print('❌ Error syncing incident ${incident['id']} (will retry later): $e');
        // Stop processing further if network is still down
        break;
      }
    }
  }
}
