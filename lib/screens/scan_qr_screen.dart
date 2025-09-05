import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'chat_screen.dart';
import '../services/auth_service.dart';
import 'qr_action_selection_screen.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final AuthService _authService = AuthService();
  bool _handled = false;


  Future<void> _handleScan(BarcodeCapture barcodeCapture) async {
    final rawValue = barcodeCapture.barcodes.first.rawValue;

    if (rawValue != null && rawValue.isNotEmpty) {
      final sessionId = rawValue.trim();
      
      if (sessionId.isEmpty || sessionId.length < 10) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid session ID in QR code'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;

        try {
          final sessionDoc = await firestore.collection('sessions').doc(sessionId).get();
          
          if (!sessionDoc.exists) {
            throw 'Session not found';
          }
          
          final otherUserName = sessionDoc.data()?['user1Name'] ?? 'Anonymous';
          final currentUserId = _authService.currentUser?.uid ?? 'unknown';
          final currentUserName = await _authService.getCurrentUserName();
          
          await firestore.collection('sessions').doc(sessionId).update({
            'user2': currentUserId,
            'user2Name': currentUserName ?? 'Anonymous',
            'user2Email': _authService.currentUser?.email ?? '',
            'status': 'connected',
          });

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
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
        }
      }
    }
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
              'Scan QR Code',
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
      ),
      body: Stack(
        children: [
          // MobileScanner widget to display the camera and detect QR codes
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
            ),
            onDetect: (barcodeCapture) {
              if (_handled) return;
              _handled = true;
              _handleScan(barcodeCapture);
            },
          ),

          // Optional: Add a UI overlay to guide the user
          // For example, a transparent box in the middle of the screen
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Position the QR code within the frame',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
