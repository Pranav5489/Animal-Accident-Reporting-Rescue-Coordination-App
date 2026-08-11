import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'screens/report_incident_screen.dart';
import 'services/offline_queue_service.dart';

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (requires google-services.json / GoogleService-Info.plist)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("Firebase init failed (check credentials): $e");
  }

  runApp(const EchoRescueApp());
}

class EchoRescueApp extends StatefulWidget {
  const EchoRescueApp({super.key});

  @override
  State<EchoRescueApp> createState() => _EchoRescueAppState();
}

class _EchoRescueAppState extends State<EchoRescueApp> {
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
    
    // Listen for connection changes and sync pending offline reports
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        print("🌐 Network connected. Attempting background sync...");
        OfflineQueueService().syncPendingIncidents();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission (Apple & Web)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      // Get the token and print it or send to backend
      String? token = await messaging.getToken();
      print('FCM Token: $token');
      // TODO: Send this token to the backend for the rescuer team
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo Rescue',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const ReportIncidentScreen(),
    );
  }
}
