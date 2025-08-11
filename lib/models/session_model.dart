class Session {
  final int? id;
  final String sessionId;
  final String user1Id;
  final String? user2Id;
  final String status;
  final DateTime createdAt;
  final String communicationType; // 'wifi' or 'bluetooth'

  Session({
    this.id,
    required this.sessionId,
    required this.user1Id,
    this.user2Id,
    required this.status,
    required this.createdAt,
    required this.communicationType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'communicationType': communicationType,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      sessionId: map['sessionId'],
      user1Id: map['user1Id'],
      user2Id: map['user2Id'],
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      communicationType: map['communicationType'],
    );
  }
}