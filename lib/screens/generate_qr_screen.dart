import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'chat_screen.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'qr_action_selection_screen.dart';

class GenerateQRScreen extends StatefulWidget {
  const GenerateQRScreen({super.key});

  @override
  GenerateQRScreenState createState() => GenerateQRScreenState();
}

class GenerateQRScreenState extends State<GenerateQRScreen> {
  final String sessionId = const Uuid().v4();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _createSession();
    _listenForConnection();
  }

  void _createSession() async {
    final userName = await _authService.getCurrentUserName();
    await _firestore.collection('sessions').doc(sessionId).set({
      'sessionId': sessionId,
      'user1': _authService.currentUser?.uid ?? 'unknown',
      'user1Name': userName ?? 'Anonymous',
      'user1Email': _authService.currentUser?.email ?? '',
      'user2': null,
      'user2Name': null,
      'user2Email': null,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _listenForConnection() {
    _firestore.collection('sessions').doc(sessionId).snapshots().listen((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data()!['status'] == 'connected') {
        final String currentUserId = _authService.currentUser?.uid ?? 'unknown';
        final String? otherUserName = snapshot.data()!['user2Name'];
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
              sessionId: sessionId,
              currentUserId: currentUserId,
              otherUserName: otherUserName,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              
              var tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              
              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                    const QRActionSelectionScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(-1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  
                  var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  
                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 350),
              ),
            );
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate QR Code',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              _authService.currentUser?.email ?? 'Unknown user',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white, size: 18),
            label: const Text(
              'Logout',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      size: 40,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: sessionId,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Share this QR code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask your friend to scan this code\nto start chatting',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Session ID: ${sessionId.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Waiting for connection...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
