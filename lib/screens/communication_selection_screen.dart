import 'package:flutter/material.dart';
import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';

class CommunicationSelectionScreen extends StatefulWidget {
  final bool isGenerating; // true for generating QR, false for scanning
  
  const CommunicationSelectionScreen({
    super.key,
    required this.isGenerating,
  });

  @override
  State<CommunicationSelectionScreen> createState() => _CommunicationSelectionScreenState();
}

class _CommunicationSelectionScreenState extends State<CommunicationSelectionScreen> {
  String selectedMethod = 'wifi'; // Default to WiFi

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGenerating ? 'Select Connection Type' : 'Select Connection Type'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose Communication Method',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // WiFi Option Card
            GestureDetector(
              onTap: () => setState(() => selectedMethod = 'wifi'),
              child: Card(
                elevation: selectedMethod == 'wifi' ? 8 : 2,
                color: selectedMethod == 'wifi' 
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: selectedMethod == 'wifi'
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                    width: selectedMethod == 'wifi' ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi,
                        size: 50,
                        color: selectedMethod == 'wifi'
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'WiFi / Internet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: selectedMethod == 'wifi' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Uses Firebase for real-time sync',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (selectedMethod == 'wifi')
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Bluetooth Option Card
            GestureDetector(
              onTap: () => setState(() => selectedMethod = 'bluetooth'),
              child: Card(
                elevation: selectedMethod == 'bluetooth' ? 8 : 2,
                color: selectedMethod == 'bluetooth' 
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: selectedMethod == 'bluetooth'
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                    width: selectedMethod == 'bluetooth' ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bluetooth,
                        size: 50,
                        color: selectedMethod == 'bluetooth'
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bluetooth',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: selectedMethod == 'bluetooth' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Direct peer-to-peer connection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (selectedMethod == 'bluetooth')
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Continue Button
            ElevatedButton(
              onPressed: () {
                if (widget.isGenerating) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenerateQRScreen(
                        communicationType: selectedMethod,
                      ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScanQRScreen(
                        communicationType: selectedMethod,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}