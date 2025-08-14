import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'chat_screen.dart'; // Make sure this is the correct path to your ChatScreen

class ScanQRScreen extends StatefulWidget {
  final String communicationType;
  
  const ScanQRScreen({
    super.key,
    required this.communicationType,
  });

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _handled = false;

  Future<void> _handleScan(BarcodeCapture barcodeCapture) async {
    // Get the first barcode's raw value, which contains sessionId:communicationType
    final rawValue = barcodeCapture.barcodes.first.rawValue;

    // Parse the QR code data
    if (rawValue != null && rawValue.isNotEmpty) {
      final parts = rawValue.split(':');
      if (parts.length != 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code format')),
        );
        return;
      }
      
      final sessionId = parts[0];
      final qrCommunicationType = parts[1];
      
      // Verify communication type matches
      if (qrCommunicationType != widget.communicationType) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR code is for $qrCommunicationType but you selected ${widget.communicationType}'
            ),
          ),
        );
        return;
      }
      
      if (widget.communicationType == 'wifi') {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;

      try {
        // Update the Firestore session document to mark the user as connected
        await firestore.collection('sessions').doc(sessionId).update({
          // You should replace 'user2-id' with a real, unique user ID for the scanner
          'user2': 'user2-id',
          'status': 'connected',
        });

        // Navigate to the chat screen after a successful connection
        // Pass the session ID and the current user's ID
        const String currentUserId = 'user2-id';
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              sessionId: sessionId,
              currentUserId: currentUserId,
              communicationType: widget.communicationType,
            ),
          ),
        );
      } catch (e) {
        // Handle any errors, such as a session ID not found in Firestore
        // or a lack of permissions
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      }
      } else if (widget.communicationType == 'bluetooth') {
        // For Bluetooth, navigate directly to Bluetooth chat screen
        const String currentUserId = 'user2-id';
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              sessionId: sessionId,
              currentUserId: currentUserId,
              communicationType: widget.communicationType,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code (${widget.communicationType == 'wifi' ? 'WiFi' : 'Bluetooth'})')
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
