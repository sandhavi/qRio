import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/bluetooth_service.dart';
import 'services/database_helper.dart';
import 'models/message_model.dart';
import 'models/session_model.dart';

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
  final BluetoothService _bluetoothService = BluetoothService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  List<Message> _messages = [];
  bool _isConnecting = true;
  String _connectionStatus = 'Initializing...';
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadMessages();
    _listenToMessages();
  }

  Future<void> _initializeChat() async {
    // Save session to local database
    await _databaseHelper.insertSession(Session(
      sessionId: widget.sessionId,
      user1Id: widget.isHost ? widget.currentUserId : 'peer',
      user2Id: widget.isHost ? null : widget.currentUserId,
      status: 'connecting',
      createdAt: DateTime.now(),
      communicationType: 'bluetooth',
    ));

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
      _connectionStatus = 'Scanning for host device...';
    });
    
    // Scan for devices
    List<BluetoothDevice> devices = await _bluetoothService.scanForDevices(widget.sessionId);
    
    if (devices.isEmpty) {
      setState(() {
        _connectionStatus = 'No devices found. Make sure the host is advertising.';
        _isConnecting = false;
      });
      return;
    }
    
    // Connect to the first found device
    setState(() {
      _connectionStatus = 'Connecting to host...';
    });
    
    bool connected = await _bluetoothService.connectToDevice(devices.first);
    
    if (connected) {
      setState(() {
        _connectedDevice = devices.first;
        _connectionStatus = 'Connected';
        _isConnecting = false;
      });
      
      // Update session status
      await _databaseHelper.updateSession(Session(
        sessionId: widget.sessionId,
        user1Id: 'peer',
        user2Id: widget.currentUserId,
        status: 'connected',
        createdAt: DateTime.now(),
        communicationType: 'bluetooth',
      ));
    } else {
      setState(() {
        _connectionStatus = 'Failed to connect to host';
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
    List<Message> messages = await _databaseHelper.getMessages(widget.sessionId);
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
          if (_isConnecting)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 12),
                  Text(_connectionStatus),
                ],
              ),
            ),
          
          // Message list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      _isConnecting
                          ? 'Connecting...'
                          : 'No messages yet. Start a conversation!',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == widget.currentUserId;
                      
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    message.isSent
                                        ? Icons.done_all
                                        : Icons.done,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Message input
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isConnecting && _bluetoothService.isConnected,
                    decoration: InputDecoration(
                      hintText: _bluetoothService.isConnected
                          ? 'Type a message...'
                          : 'Waiting for connection...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: _bluetoothService.isConnected
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  onPressed: _bluetoothService.isConnected ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}