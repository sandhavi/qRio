import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/message_model.dart';
import '../models/session_model.dart';
import '../widgets/save_chat_dialog.dart';
import '../widgets/save_confirmation_widget.dart';
import '../widgets/sticker_picker.dart';
import 'home_screen.dart';
import 'chat_history_screen.dart';

class ChatScreen extends StatefulWidget {
  final String sessionId;
  final String currentUserId;
  final String? otherUserName;

  const ChatScreen({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    this.otherUserName,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _otherUserTyping = false;
  bool _chatSaved = false;
  int _messageCount = 0;
  Session? _currentSession;
  bool _isTyping = false;
  DateTime? _lastTypingTime;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    _saveSessionLocally();
    _listenForSaveConfirmations();
    _listenForTypingStatus();
    _messageController.addListener(_handleTyping);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _messageController.removeListener(_handleTyping);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveSessionLocally() async {
    try {
      _currentSession = await _databaseHelper.getSession(widget.sessionId);
      if (_currentSession == null) {
        await _databaseHelper.insertSession(
          Session(
            sessionId: widget.sessionId,
            user1Id: widget.currentUserId,
            user2Id: 'peer',
            status: 'connected',
            createdAt: DateTime.now(),
            communicationType: 'wifi',
          ),
        );
        _currentSession = await _databaseHelper.getSession(widget.sessionId);
      }
    } catch (e) {
      debugPrint('Error saving session locally: $e');
    }
  }

  void _listenForSaveConfirmations() {
    _firestore.collection('sessions').doc(widget.sessionId).snapshots().listen((
      snapshot,
    ) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['chatSaved'] == true) {
          final savedBy = data['savedBy'];
          if (savedBy != widget.currentUserId && !_chatSaved) {
            _showSaveConfirmationFromOtherUser(data['chatTitle'] ?? 'Untitled');
          }
        }
      }
    });
  }

  void _listenForTypingStatus() {
    _firestore
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('typing')
        .doc('status')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              final typingUserId = data['typingUserId'];
              final typingTime = data['typingTime'] as Timestamp?;

              if (typingUserId != null &&
                  typingUserId != widget.currentUserId &&
                  typingTime != null) {
                final timeDiff = DateTime.now().difference(typingTime.toDate());
                setState(() {
                  _otherUserTyping = timeDiff.inSeconds < 3;
                });
              } else {
                setState(() {
                  _otherUserTyping = false;
                });
              }
            }
          }
        });
  }

  void _handleTyping() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _updateTypingStatus(true);
    } else if (_messageController.text.isEmpty && _isTyping) {
      _isTyping = false;
      _updateTypingStatus(false);
    } else if (_isTyping) {
      final now = DateTime.now();
      if (_lastTypingTime == null ||
          now.difference(_lastTypingTime!).inSeconds >= 2) {
        _updateTypingStatus(true);
      }
    }
  }

  void _updateTypingStatus(bool isTyping) {
    _lastTypingTime = DateTime.now();
    _firestore
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('typing')
        .doc('status')
        .set({
          'typingUserId': isTyping ? widget.currentUserId : null,
          'typingTime': isTyping ? FieldValue.serverTimestamp() : null,
        }, SetOptions(merge: true))
        .catchError((error) {
          debugPrint('Error updating typing status: $error');
        });
  }

  void _showSaveConfirmationFromOtherUser(String chatTitle) {
    SaveNotificationOverlay.show(
      context,
      chatTitle: chatTitle,
      isInitiator: false,
      otherUserConfirmed: true,
    );
    setState(() {
      _chatSaved = true;
    });
  }

  void _sendMessage({
    MessageType messageType = MessageType.text,
    String? stickerPath,
  }) async {
    if (_messageController.text.isEmpty && messageType == MessageType.text) {
      return;
    }

    String messageText = messageType == MessageType.text
        ? _messageController.text.trim()
        : '';

    if (messageType == MessageType.text) {
      if (messageText.isEmpty) return;
      if (messageText.length > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Message is too long. Maximum 1000 characters allowed.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      _messageController.clear();
      _isTyping = false;
      _updateTypingStatus(false);
    }

    try {
      // Save to local database
      Message localMessage = Message(
        sessionId: widget.sessionId,
        senderId: widget.currentUserId,
        text: messageText,
        messageType: messageType,
        stickerPath: stickerPath,
        timestamp: DateTime.now(),
        isSent: false,
        communicationType: 'wifi',
      );

      int messageId = await _databaseHelper.insertMessage(localMessage);

      // Send to Firebase
      await _firestore
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('messages')
          .add({
            'senderId': widget.currentUserId,
            'text': messageText,
            'timestamp': FieldValue.serverTimestamp(),
            'messageType': messageType.index,
            'stickerPath': stickerPath,
          });

      // Update sent status
      await _databaseHelper.updateMessageSentStatus(messageId, true);

      setState(() {
        _messageCount++;
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendMessage(
                messageType: messageType,
                stickerPath: stickerPath,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveReceivedMessage(Map<String, dynamic> message) async {
    // Check if message already exists
    List<Message> existingMessages = await _databaseHelper.getMessages(
      widget.sessionId,
    );
    bool exists = existingMessages.any(
      (m) =>
          m.text == (message['text'] ?? '') &&
          m.senderId == message['senderId'] &&
          m.messageType.index == (message['messageType'] ?? 0),
    );

    if (!exists) {
      await _databaseHelper.insertMessage(
        Message(
          sessionId: widget.sessionId,
          senderId: message['senderId'],
          text: message['text'] ?? '',
          messageType: MessageType.values[message['messageType'] ?? 0],
          stickerPath: message['stickerPath'],
          timestamp: message['timestamp'] != null
              ? (message['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
          isSent: message['senderId'] == widget.currentUserId,
          communicationType: 'wifi',
        ),
      );
      setState(() {
        _messageCount++;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_messageCount > 0 && !_chatSaved) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SaveChatDialog(messageCount: _messageCount),
      );

      if (result != null && result['save'] == true) {
        await _saveChat(result['title']);
        return true;
      }
    }
    return true;
  }

  Future<void> _saveChat(String? title) async {
    final chatTitle =
        title ?? 'Chat ${DateTime.now().toString().substring(0, 10)}';

    // Save locally
    await _databaseHelper.saveChat(widget.sessionId, chatTitle);

    // Update message count
    final messageCount = await _databaseHelper.getMessageCount(
      widget.sessionId,
    );
    await _databaseHelper.updateSession(
      _currentSession!.copyWith(
        isSaved: true,
        savedAt: DateTime.now(),
        chatTitle: chatTitle,
        messageCount: messageCount,
      ),
    );

    // Notify other user via Firebase
    await _firestore.collection('sessions').doc(widget.sessionId).set({
      'chatSaved': true,
      'savedBy': widget.currentUserId,
      'chatTitle': chatTitle,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Show confirmation
    if (mounted) {
      SaveNotificationOverlay.show(
        context,
        chatTitle: chatTitle,
        isInitiator: true,
        otherUserConfirmed: false,
      );
    }

    setState(() {
      _chatSaved = true;
    });
  }

  Widget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey[800],
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green.withValues(alpha: 0.05),
            child: Text(
              (widget.otherUserName ?? 'User').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName ?? 'Anonymous User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _otherUserTyping ? 'typing...' : 'Active now',
                    key: ValueKey<bool>(_otherUserTyping),
                    style: TextStyle(
                      fontSize: 12,
                      color: _otherUserTyping ? Colors.green : Colors.grey[600],
                      fontStyle: _otherUserTyping
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.emoji_emotions_outlined),
          onPressed: () {
            StickerPicker.show(context, (stickerPath) {
              _sendMessage(
                messageType: MessageType.sticker,
                stickerPath: stickerPath,
              );
            });
          },
          tooltip: 'Stickers',
        ),
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ChatHistoryScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOutCubic;

                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 350),
              ),
            );
          },
          tooltip: 'Chat History',
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 20),
          onPressed: () async {
            await _authService.signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
          },
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildModernMessageInput(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: SafeArea(
          top: false,
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined),
                onPressed: () {
                  StickerPicker.show(context, (stickerPath) {
                    _sendMessage(
                      messageType: MessageType.sticker,
                      stickerPath: stickerPath,
                    );
                  });
                },
                color: const Color(
                  0xFF5BC236,
                ), // Green to match received messages
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF), // Blue to match sent messages
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: _sendMessage,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernMessageBubble(Map<String, dynamic> message, bool isMe) {
    final messageType = MessageType.values[message['messageType'] ?? 0];

    Widget content;
    if (messageType == MessageType.sticker) {
      content = _buildStickerContent(message['stickerPath']);
    } else {
      content = Text(
        message['text'] ?? '',
        style: const TextStyle(
          color: Colors.white, // White text for both sent and received messages
          fontSize: 15,
          height: 1.3,
        ),
      );
    }

    final time =
        (message['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF007AFF) // Blue for sent messages
                    : const Color.fromARGB(255, 29, 86, 8), // Green for received messages
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.08,
                    ), // Slightly more visible shadow
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 4),
                  Text(
                    timeString,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.8,
                      ), // White with transparency for both
                      fontSize: 11,
                    ),
                  ),
                ],
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
      'angry': '😠',
      'kiss': '😘',
      'thinking': '🤔',
      'celebrate': '🥳',
      'hug': '🤗',
      'star': '⭐',
      'rocket': '🚀',
      'rainbow': '🌈',
      'sun': '☀️',
      'moon': '🌙',
      'gift': '🎁',
      'cake': '🎂',
      'pizza': '🍕',
      'coffee': '☕',
    };

    return Text(
      stickerEmojis[stickerPath] ?? '🎨',
      style: const TextStyle(fontSize: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _buildModernAppBar(),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
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
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey[400]!,
                            ),
                          ),
                        );
                      }

                      final messages = snapshot.data!.docs;

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation!',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              messages[index].data() as Map<String, dynamic>;

                          // Save received message to local database
                          _saveReceivedMessage(message);
                          final bool isMe =
                              message['senderId'] == widget.currentUserId;

                          return _buildModernMessageBubble(message, isMe);
                        },
                      );
                    },
                  ),
                ),

                // Message Input Field
                _buildModernMessageInput(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
