enum MessageType { text, sticker, image, file }

class Message {
  final int? id;
  final String sessionId;
  final String senderId;
  final String text;
  final MessageType messageType;
  final String? stickerPath;
  final String? imagePath;
  final String? fileName;
  final DateTime timestamp;
  final bool isSent;
  final bool isRead;
  final String communicationType; 

  Message({
    this.id,
    required this.sessionId,
    required this.senderId,
    required this.text,
    this.messageType = MessageType.text,
    this.stickerPath,
    this.imagePath,
    this.fileName,
    required this.timestamp,
    this.isSent = false,
    this.isRead = false,
    required this.communicationType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'senderId': senderId,
      'text': text,
      'messageType': messageType.index,
      'stickerPath': stickerPath,
      'imagePath': imagePath,
      'fileName': fileName,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent ? 1 : 0,
      'isRead': isRead ? 1 : 0,
      'communicationType': communicationType,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      sessionId: map['sessionId'],
      senderId: map['senderId'],
      text: map['text'] ?? '',
      messageType: MessageType.values[map['messageType'] ?? 0],
      stickerPath: map['stickerPath'],
      imagePath: map['imagePath'],
      fileName: map['fileName'],
      timestamp: DateTime.parse(map['timestamp']),
      isSent: map['isSent'] == 1,
      isRead: map['isRead'] == 1,
      communicationType: map['communicationType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'senderId': senderId,
      'text': text,
      'messageType': messageType.index,
      'stickerPath': stickerPath,
      'imagePath': imagePath,
      'fileName': fileName,
      'timestamp': timestamp.toIso8601String(),
      'communicationType': communicationType,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sessionId: json['sessionId'],
      senderId: json['senderId'],
      text: json['text'] ?? '',
      messageType: MessageType.values[json['messageType'] ?? 0],
      stickerPath: json['stickerPath'],
      imagePath: json['imagePath'],
      fileName: json['fileName'],
      timestamp: DateTime.parse(json['timestamp']),
      communicationType: json['communicationType'],
    );
  }
}