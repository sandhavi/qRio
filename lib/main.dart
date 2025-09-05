import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if present (non-fatal if missing)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Initialize Firebase safely (don't crash app if options are already configured)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Log and continue; AuthWrapper/UI can still render even if init fails temporarily
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      title: 'QRio',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
    );
  }
}
