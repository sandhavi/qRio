import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if available, but don't crash if missing.
  bool envLoaded = false;
  try {
    await dotenv.load(fileName: '.env');
    envLoaded = true;
  } catch (e) {
    debugPrint('dotenv load skipped: $e');
  }

  // Initialize Firebase with best-effort fallbacks to avoid startup crash/black screen.
  try {
    if (envLoaded) {
      // Use options from firebase_options.dart which read from .env
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Fall back to platform defaults (e.g., Android uses google-services.json)
      await Firebase.initializeApp();
    }
  } catch (e) {
    // As a last resort, continue without Firebase so the UI still loads.
    debugPrint('Firebase init failed, continuing without it: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Connect',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
