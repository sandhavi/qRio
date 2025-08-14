class Message {
  final int? id;
  final String sessionId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final String communicationType; // 'wifi' or 'bluetooth'

  Message({
    this.id,
    required this.sessionId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isSent = false,
    required this.communicationType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent ? 1 : 0,
      'communicationType': communicationType,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      sessionId: map['sessionId'],
      senderId: map['senderId'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
      isSent: map['isSent'] == 1,
      communicationType: map['communicationType'],
    );
  }
}