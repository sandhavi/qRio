import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/session_model.dart';
import '../models/message_model.dart';
import 'saved_chat_view_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> 
    with TickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  List<Session> _savedSessions = [];
  List<Session> _filteredSessions = [];
  final Map<String, Message?> _lastMessages = {};
  final Map<String, int> _messageCounts = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showSearch = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _listAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutBack,
    ));
    
    // Start animations
    _fadeController.forward();
    
    _loadSavedChats();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedChats() async {
    try {
      final sessions = await _databaseHelper.getSavedSessions();
      
      // Load last message and message count for each session
      for (var session in sessions) {
        final messages = await _databaseHelper.getMessages(session.sessionId);
        if (messages.isNotEmpty) {
          _lastMessages[session.sessionId] = messages.first;
        }
        _messageCounts[session.sessionId] = await _databaseHelper.getMessageCount(session.sessionId);
      }
      
      // Sort sessions by saved time (most recent first)
      sessions.sort((a, b) {
        final dateA = a.savedAt ?? a.createdAt;
        final dateB = b.savedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
      
      setState(() {
        _savedSessions = sessions;
        _filteredSessions = sessions;
        _isLoading = false;
      });
      
      // Start list animation after data is loaded
      if (_savedSessions.isNotEmpty) {
        _listController.forward();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading saved chats: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _filterSessions(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSessions = _savedSessions;
      } else {
        _filteredSessions = _savedSessions.where((session) {
          final title = session.chatTitle?.toLowerCase() ?? '';
          final lastMessage = _lastMessages[session.sessionId]?.text.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          
          return title.contains(searchLower) ||
              lastMessage.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _deleteChat(Session session) async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red[600],
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Chat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${session.chatTitle ?? 'Untitled Chat'}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _databaseHelper.deleteSessionMessages(session.sessionId);
      await _databaseHelper.deleteSession(session.sessionId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat deleted successfully'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      
      _loadSavedChats();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatMessagePreview(Message? message) {
    if (message == null) return 'No messages yet';
    
    String prefix = '';
    if (message.senderId == _authService.currentUser?.uid ||
        message.senderId == 'user') {
      prefix = 'You: ';
    }
    
    switch (message.messageType) {
      case MessageType.sticker:
        return '${prefix}🎨 Sticker';
      case MessageType.image:
        return '${prefix}📷 Photo';
      case MessageType.file:
        return '${prefix}📎 ${message.fileName ?? 'File'}';
      case MessageType.text:
        final text = message.text.replaceAll('\n', ' ');
        return '$prefix${text.length > 45 ? '${text.substring(0, 45)}...' : text}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (_showSearch) _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredSessions.isEmpty
                      ? _buildEmptyState()
                      : _buildChatList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                if (_savedSessions.isNotEmpty)
                  Text(
                    '${_savedSessions.length} ${_savedSessions.length == 1 ? 'conversation' : 'conversations'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          if (_savedSessions.isNotEmpty) ...[
            _buildActionButton(
              icon: _showSearch ? Icons.close : Icons.search,
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    _filterSessions('');
                  }
                });
              },
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              icon: Icons.delete_sweep_outlined,
              onPressed: _showDeleteAllDialog,
              color: Colors.red[600],
              backgroundColor: Colors.red[50],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: color ?? Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterSessions,
          autofocus: true,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[800],
          ),
          decoration: InputDecoration(
            hintText: 'Search chats...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey[400],
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your chats...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No chats found' : 'No saved chats yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                isSearching 
                  ? 'Try searching with different keywords'
                  : 'Your saved conversations will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chat, size: 20),
                label: const Text('Start a Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return FadeTransition(
      opacity: _listAnimation,
      child: RefreshIndicator(
        onRefresh: _loadSavedChats,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _filteredSessions.length,
          itemBuilder: (context, index) {
            final session = _filteredSessions[index];
            final lastMessage = _lastMessages[session.sessionId];
            
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 50)),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SavedChatViewScreen(
                          session: session,
                        ),
                      ),
                    ).then((_) => _loadSavedChats());
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE8EAED),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _getAvatarColor(session.chatTitle ?? session.sessionId),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              (session.chatTitle ?? 'C')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Chat Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.chatTitle ?? 'Chat Session',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimestamp(session.savedAt ?? session.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMessagePreview(lastMessage),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F6F8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.message_outlined,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_messageCounts[session.sessionId] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.wifi,
                                          size: 14,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          session.communicationType == 'wifi' ? 'WiFi' : 'Bluetooth',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Delete Button
                        IconButton(
                          onPressed: () => _deleteChat(session),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.grey[400],
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getAvatarColor(String text) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00BFA6),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFA726),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
      const Color(0xFF42A5F5),
    ];
    
    int hash = text.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Future<void> _showDeleteAllDialog() async {
    HapticFeedback.mediumImpact();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_sweep,
                  color: Colors.red[600],
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete All Chats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete all ${_savedSessions.length} saved ${_savedSessions.length == 1 ? 'chat' : 'chats'}. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete All',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      
      for (var session in _savedSessions) {
        await _databaseHelper.deleteSessionMessages(session.sessionId);
        await _databaseHelper.deleteSession(session.sessionId);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All chats deleted successfully'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      
      _loadSavedChats();
    }
  }
}