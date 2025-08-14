import 'package:flutter/material.dart';
import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';

class CommunicationSelectionScreen extends StatefulWidget {
  final bool isGenerating; // true for generating QR, false for scanning

  const CommunicationSelectionScreen({super.key, required this.isGenerating});

  @override
  State<CommunicationSelectionScreen> createState() =>
      _CommunicationSelectionScreenState();
}

class _CommunicationSelectionScreenState
    extends State<CommunicationSelectionScreen> {
  String selectedMethod = 'wifi'; // Default to WiFi

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isGenerating
              ? 'Select Connection Type'
              : 'Select Connection Type',
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 70,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Pick a connection channel',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'You can connect over the internet (Firebase) or directly via Bluetooth when offline.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 32),

            // WiFi Option Card
            _OptionCard(
              icon: Icons.wifi,
              title: 'WiFi / Internet',
              description:
                  'Fast, reliable and syncs through Firebase Cloud Firestore.',
              selected: selectedMethod == 'wifi',
              onTap: () => setState(() => selectedMethod = 'wifi'),
              color: Colors.teal,
              badge: 'Online',
            ),

            const SizedBox(height: 20),

            // Bluetooth Option Card
            _OptionCard(
              icon: Icons.bluetooth,
              title: 'Bluetooth (Offline)',
              description:
                  'Direct device-to-device link. Great when no internet.',
              selected: selectedMethod == 'bluetooth',
              onTap: () => setState(() => selectedMethod = 'bluetooth'),
              color: Colors.indigo,
              badge: 'Offline',
            ),

            const SizedBox(height: 32),

            // Continue Button
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: () {
                if (widget.isGenerating) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GenerateQRScreen(communicationType: selectedMethod),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ScanQRScreen(communicationType: selectedMethod),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final String? badge;
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.color,
    this.badge,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: selected ? 1.02 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: selected ? 10 : 2,
          shadowColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? color : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: selected ? color : Colors.black87,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (selected ? color : Colors.grey.shade300)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? color : Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: color, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Selected',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
