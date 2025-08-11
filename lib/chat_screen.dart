import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bluetooth_chat_screen.dart';
import 'services/database_helper.dart';
import 'models/message_model.dart';
import 'models/session_model.dart';

class ChatScreen extends StatefulWidget {
  final String sessionId;
  final String currentUserId; // To distinguish between sender and receiver
  final String communicationType; // 'wifi' or 'bluetooth'

  const ChatScreen({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    required this.communicationType,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  @override
  void initState() {
    super.initState();
    // If Bluetooth, redirect to Bluetooth chat screen
    if (widget.communicationType == 'bluetooth') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BluetoothChatScreen(
              sessionId: widget.sessionId,
              currentUserId: widget.currentUserId,
              isHost: widget.currentUserId == 'user1-id',
            ),
          ),
        );
      });
    } else {
      _saveSessionLocally();
    }
  }
  
  Future<void> _saveSessionLocally() async {
    await _databaseHelper.insertSession(Session(
      sessionId: widget.sessionId,
      user1Id: widget.currentUserId == 'user1-id' ? widget.currentUserId : 'peer',
      user2Id: widget.currentUserId == 'user2-id' ? widget.currentUserId : null,
      status: 'connected',
      createdAt: DateTime.now(),
      communicationType: widget.communicationType,
    ));
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String messageText = _messageController.text;
      _messageController.clear();
      
      // Save to local database
      Message localMessage = Message(
        sessionId: widget.sessionId,
        senderId: widget.currentUserId,
        text: messageText,
        timestamp: DateTime.now(),
        isSent: false,
        communicationType: widget.communicationType,
      );
      
      int messageId = await _databaseHelper.insertMessage(localMessage);
      
      // Send to Firebase
      if (widget.communicationType == 'wifi') {
        await _firestore
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('messages')
            .add({
              'senderId': widget.currentUserId,
              'text': messageText,
              'timestamp': FieldValue.serverTimestamp(),
            });
        
        // Update sent status
        await _databaseHelper.updateMessageSentStatus(messageId, true);
      }
    }
  }

  Future<void> _saveReceivedMessage(Map<String, dynamic> message) async {
    // Check if message already exists
    List<Message> existingMessages = await _databaseHelper.getMessages(widget.sessionId);
    bool exists = existingMessages.any((m) => 
      m.text == message['text'] && 
      m.senderId == message['senderId']
    );
    
    if (!exists) {
      await _databaseHelper.insertMessage(Message(
        sessionId: widget.sessionId,
        senderId: message['senderId'],
        text: message['text'],
        timestamp: message['timestamp'] != null 
          ? (message['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
        isSent: message['senderId'] == widget.currentUserId,
        communicationType: widget.communicationType,
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Return empty container if bluetooth (will redirect)
    if (widget.communicationType == 'bluetooth') {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat (${widget.communicationType == 'wifi' ? 'WiFi' : 'Bluetooth'})'),
        actions: [
          IconButton(
            icon: Icon(
              widget.communicationType == 'wifi' ? Icons.wifi : Icons.bluetooth,
              color: widget.communicationType == 'wifi' ? Colors.green : Colors.blue,
            ),
            onPressed: null,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Message List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('sessions')
                  .doc(widget.sessionId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // To show new messages at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    
                    // Save received message to local database
                    _saveReceivedMessage(message);
                    final bool isMe =
                        message['senderId'] == widget.currentUserId;

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
                          color: isMe ? Colors.blueAccent : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          message['text'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
