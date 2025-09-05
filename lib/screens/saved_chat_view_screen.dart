import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../models/message_model.dart';
import '../services/database_helper.dart';

class SavedChatViewScreen extends StatefulWidget {
  final Session session;

  const SavedChatViewScreen({
    super.key,
    required this.session,
  });

  @override
  State<SavedChatViewScreen> createState() => _SavedChatViewScreenState();
}

class _SavedChatViewScreenState extends State<SavedChatViewScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _databaseHelper.getMessages(widget.session.sessionId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Card(
              color: isMe 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey.shade200,
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
                    if (message.messageType == MessageType.sticker)
                      _buildStickerContent(message.stickerPath)
                    else if (message.messageType == MessageType.image)
                      _buildImageContent(message.imagePath)
                    else if (message.messageType == MessageType.file)
                      _buildFileContent(message.fileName)
                    else
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isMe 
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isSent ? Icons.done_all : Icons.done,
                            size: 14,
                            color: message.isRead 
                              ? Colors.lightBlue[200] 
                              : Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerContent(String? stickerPath) {
    if (stickerPath == null) return const Text('Sticker');
    
    final stickerEmojis = {
      'happy': '😊',
      'love': '❤️',
      'sad': '😢',
      'laugh': '😂',
      'thumbsup': '👍',
      'heart': '💕',
      'fire': '🔥',
      'party': '🎉',
      'cool': '😎',
      'wink': '😉',
    };
    
    return Text(
      stickerEmojis[stickerPath] ?? '🎨',
      style: const TextStyle(fontSize: 48),
    );
  }

  Widget _buildImageContent(String? imagePath) {
    return Column(
      children: [
        Container(
          height: 150,
          width: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.image,
            size: 50,
            color: Colors.grey,
          ),
        ),
        if (imagePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              imagePath.split('/').last,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildFileContent(String? fileName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.attach_file,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(fileName ?? 'File'),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.session.chatTitle ?? 'Saved Chat'),
            Text(
              '${widget.session.messageCount} messages • ${widget.session.communicationType == 'wifi' ? 'WiFi' : 'Bluetooth'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.session.communicationType == 'wifi' 
                ? Icons.wifi 
                : Icons.bluetooth,
              color: widget.session.communicationType == 'wifi'
                ? Colors.green
                : Colors.blue,
            ),
            onPressed: null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages in this chat',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == widget.session.user1Id;
                    
                    // Check if we need to show date separator
                    bool showDateSeparator = false;
                    if (index == _messages.length - 1) {
                      showDateSeparator = true;
                    } else {
                      final prevMessage = _messages[index + 1];
                      if (message.timestamp.day != prevMessage.timestamp.day ||
                          message.timestamp.month != prevMessage.timestamp.month ||
                          message.timestamp.year != prevMessage.timestamp.year) {
                        showDateSeparator = true;
                      }
                    }
                    
                    return Column(
                      children: [
                        if (showDateSeparator)
                          _buildDateSeparator(message.timestamp),
                        _buildMessageBubble(message, isMe),
                      ],
                    );
                  },
                ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'delete',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Chat'),
                  content: Text('Are you sure you want to delete "${widget.session.chatTitle ?? 'this chat'}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await _databaseHelper.deleteSessionMessages(widget.session.sessionId);
                await _databaseHelper.deleteSession(widget.session.sessionId);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete),
            mini: true,
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'export',
            onPressed: () async {
              // Export chat functionality
              final export = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Export Chat'),
                  content: const Text('Export this chat as a text file?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Export'),
                    ),
                  ],
                ),
              );
              
              if (export == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat exported successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }
}