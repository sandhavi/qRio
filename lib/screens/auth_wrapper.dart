import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'qr_action_selection_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Show appropriate screen based on auth state
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in
          return const QRActionSelectionScreen();
        } else {
          // User is not logged in
          return const HomeScreen();
        }
      },
    );
  }
}
