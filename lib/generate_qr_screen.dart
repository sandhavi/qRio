import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'chat_screen.dart';

class GenerateQRScreen extends StatefulWidget {
  const GenerateQRScreen({super.key});

  @override
  GenerateQRScreenState createState() => GenerateQRScreenState();
}

class GenerateQRScreenState extends State<GenerateQRScreen> {
  final String sessionId = const Uuid().v4();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _createSession();
    _listenForConnection();
  }

  void _createSession() async {
    await _firestore.collection('sessions').doc(sessionId).set({
      'user1': 'user1-id', // You can replace this with a real user ID
      'user2': null,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _listenForConnection() {
    _firestore.collection('sessions').doc(sessionId).snapshots().listen((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data()!['status'] == 'connected') {
        // Assuming 'user1-id' is the ID for the person who generated the QR code
        const String currentUserId = 'user1-id';
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatScreen(sessionId: sessionId, currentUserId: currentUserId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate QR Code')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Scan this code to connect:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            QrImageView(data: sessionId, version: QrVersions.auto, size: 200.0),
            const SizedBox(height: 20),
            Text(
              'Session ID: $sessionId',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
