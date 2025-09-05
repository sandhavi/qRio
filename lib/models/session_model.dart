class Session {
  final int? id;
  final String sessionId;
  final String user1Id;
  final String? user2Id;
  final String status;
  final DateTime createdAt;
  final DateTime? savedAt;
  final bool isSaved;
  final String? chatTitle;
  final String communicationType; 
  final int messageCount;

  Session({
    this.id,
    required this.sessionId,
    required this.user1Id,
    this.user2Id,
    required this.status,
    required this.createdAt,
    this.savedAt,
    this.isSaved = false,
    this.chatTitle,
    required this.communicationType,
    this.messageCount = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'sessionId': sessionId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'savedAt': savedAt?.toIso8601String(),
      'isSaved': isSaved ? 1 : 0,
      'chatTitle': chatTitle,
      'communicationType': communicationType,
      'messageCount': messageCount,
    };
    // Only include id when updating an existing row fetched from DB
    if (id != null) map['id'] = id;
    return map;
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      sessionId: map['sessionId'],
      user1Id: map['user1Id'],
      user2Id: map['user2Id'],
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      savedAt: map['savedAt'] != null ? DateTime.parse(map['savedAt']) : null,
      isSaved: map['isSaved'] == 1,
      chatTitle: map['chatTitle'],
      communicationType: map['communicationType'],
      messageCount: map['messageCount'] ?? 0,
    );
  }

  Session copyWith({
    int? id,
    String? sessionId,
    String? user1Id,
    String? user2Id,
    String? status,
    DateTime? createdAt,
    DateTime? savedAt,
    bool? isSaved,
    String? chatTitle,
    String? communicationType,
    int? messageCount,
  }) {
    return Session(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      savedAt: savedAt ?? this.savedAt,
      isSaved: isSaved ?? this.isSaved,
      chatTitle: chatTitle ?? this.chatTitle,
      communicationType: communicationType ?? this.communicationType,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}
