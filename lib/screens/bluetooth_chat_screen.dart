import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';
import '../services/database_helper.dart';
import '../models/message_model.dart';
import '../models/session_model.dart';

class BluetoothChatScreen extends StatefulWidget {
  final String sessionId;
  final String currentUserId;
  final bool isHost;

  const BluetoothChatScreen({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    required this.isHost,
  });

  @override
  State<BluetoothChatScreen> createState() => _BluetoothChatScreenState();
}

class _BluetoothChatScreenState extends State<BluetoothChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final BluetoothChatService _bluetoothService = BluetoothChatService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Message> _messages = [];
  bool _isConnecting = true;
  String _connectionStatus = 'Initializing...';
  List<fbp.ScanResult> _scanResults = [];
  fbp.BluetoothDevice? _selectedDevice;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadMessages();
    _listenToMessages();
  }

  Future<void> _initializeChat() async {
    // Save session to local database
    // Only insert if doesn't already exist
    final existing = await _databaseHelper.getSession(widget.sessionId);
    if (existing == null) {
      await _databaseHelper.insertSession(
        Session(
          sessionId: widget.sessionId,
          user1Id: widget.isHost ? widget.currentUserId : 'peer',
          user2Id: widget.isHost ? null : widget.currentUserId,
          status: 'connecting',
          createdAt: DateTime.now(),
          communicationType: 'bluetooth',
        ),
      );
    }

    // Initialize Bluetooth
    bool initialized = await _bluetoothService.initializeBluetooth();
    if (!initialized) {
      setState(() {
        _connectionStatus = 'Bluetooth initialization failed';
        _isConnecting = false;
      });
      return;
    }

    if (widget.isHost) {
      await _startAsHost();
    } else {
      await _connectAsPeer();
    }
  }

  Future<void> _startAsHost() async {
    setState(() {
      _connectionStatus = 'Waiting for peer to connect...';
    });

    // Start advertising
    await _bluetoothService.startAdvertising(widget.sessionId);

    // Wait for connection
    // In a real implementation, you'd need to set up a Bluetooth server
    // For now, we'll simulate waiting for connection
    _checkForConnection();
  }

  Future<void> _connectAsPeer() async {
    setState(() {
      _connectionStatus = 'Scanning for nearby devices...';
      _isScanning = true;
    });
    _scanResults = await _bluetoothService.scanForDevices();
    setState(() {
      _isScanning = false;
      if (_scanResults.isEmpty) {
        _connectionStatus = 'No Bluetooth devices found';
        _isConnecting = false;
      } else {
        _connectionStatus = 'Select a device to connect';
      }
    });
  }

  Future<void> _attemptConnection(fbp.BluetoothDevice device) async {
    setState(() {
      _selectedDevice = device;
      _isConnecting = true;
      _connectionStatus = 'Connecting to ${device.platformName}...';
    });
    final ok = await _bluetoothService.connectToDevice(device);
    if (ok) {
      setState(() {
        _connectionStatus = 'Connected';
        _isConnecting = false;
      });
      final original = await _databaseHelper.getSession(widget.sessionId);
      await _databaseHelper.updateSession(
        Session(
          id: original?.id,
          sessionId: widget.sessionId,
          user1Id: original?.user1Id ?? 'peer',
          user2Id: widget.currentUserId,
          status: 'connected',
          createdAt: original?.createdAt ?? DateTime.now(),
          communicationType: 'bluetooth',
        ),
      );
    } else {
      setState(() {
        _connectionStatus = 'Failed to connect. Tap a device to retry.';
        _isConnecting = false;
      });
    }
  }

  void _checkForConnection() {
    // In a real implementation, this would check for incoming connections
    // For now, we'll simulate a successful connection after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Connected';
          _isConnecting = false;
        });
      }
    });
  }

  void _listenToMessages() {
    _bluetoothService.messageStream.listen((messageData) {
      _handleReceivedMessage(messageData);
    });
  }

  void _handleReceivedMessage(Map<String, dynamic> messageData) async {
    Message message = Message(
      sessionId: widget.sessionId,
      senderId: messageData['senderId'],
      text: messageData['text'],
      timestamp: DateTime.parse(messageData['timestamp']),
      isSent: false,
      communicationType: 'bluetooth',
    );

    // Save to database
    await _databaseHelper.insertMessage(message);

    // Update UI
    setState(() {
      _messages.insert(0, message);
    });
  }

  Future<void> _loadMessages() async {
    List<Message> messages = await _databaseHelper.getMessages(
      widget.sessionId,
    );
    setState(() {
      _messages = messages;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || !_bluetoothService.isConnected) {
      return;
    }

    String messageText = _messageController.text;
    _messageController.clear();

    // Create message
    Message message = Message(
      sessionId: widget.sessionId,
      senderId: widget.currentUserId,
      text: messageText,
      timestamp: DateTime.now(),
      isSent: true,
      communicationType: 'bluetooth',
    );

    // Save to database
    int messageId = await _databaseHelper.insertMessage(message);

    // Update UI
    setState(() {
      _messages.insert(0, message);
    });

    // Send via Bluetooth
    await _bluetoothService.sendMessage(messageText, widget.currentUserId);

    // Update sent status
    await _databaseHelper.updateMessageSentStatus(messageId, true);
  }

  @override
  void dispose() {
    _bluetoothService.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Chat'),
        actions: [
          if (_bluetoothService.isConnected)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.bluetooth_connected, color: Colors.green),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.bluetooth_disabled, color: Colors.red),
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          // Connection / scanning status & device list (peer mode)
          if (_isConnecting ||
              !_bluetoothService.isConnected ||
              _scanResults.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bluetoothService.isConnected
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade100, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isConnecting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_isConnecting) const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connectionStatus,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!_bluetoothService.isConnected && !_isScanning)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Rescan',
                          onPressed: () {
                            _isConnecting = true;
                            _scanResults.clear();
                            _connectAsPeer();
                          },
                        ),
                    ],
                  ),
                  if (_scanResults.isNotEmpty && !_bluetoothService.isConnected)
                    Wrap(
                      spacing: 8,
                      children: _scanResults.map((r) {
                        final selected =
                            _selectedDevice?.remoteId == r.device.remoteId;
                        return ChoiceChip(
                          label: Text(
                            r.device.platformName.isEmpty
                                ? r.device.remoteId.str
                                : r.device.platformName,
                          ),
                          selected: selected,
                          onSelected: (_) => _attemptConnection(r.device),
                          avatar: const Icon(Icons.bluetooth, size: 16),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

          // Message list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      _bluetoothService.isConnected
                          ? 'Say hi 👋'
                          : (_connectionStatus),
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == widget.currentUserId;
                      return _MessageBubble(message: message, isMe: isMe);
                    },
                  ),
          ),

          // Message input
          _InputBar(
            controller: _messageController,
            enabled: !_isConnecting && _bluetoothService.isConnected,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bg = isMe
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade200;
    final fg = isMe ? Colors.white : Colors.black87;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Card(
          color: bg,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.text, style: TextStyle(color: fg, fontSize: 15.5)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmtTime(message.timestamp),
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          message.isSent ? Icons.done_all : Icons.done,
                          size: 14,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -2),
              blurRadius: 6,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Type a message'
                      : 'Waiting for connection...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: enabled
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: enabled ? onSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
