import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message_model.dart';
import '../models/session_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'qrio_chat.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL UNIQUE,
        user1Id TEXT NOT NULL,
        user2Id TEXT,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        savedAt TEXT,
        isSaved INTEGER NOT NULL DEFAULT 0,
        chatTitle TEXT,
        communicationType TEXT NOT NULL,
        messageCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        text TEXT,
        messageType INTEGER NOT NULL DEFAULT 0,
        stickerPath TEXT,
        imagePath TEXT,
        fileName TEXT,
        timestamp TEXT NOT NULL,
        isSent INTEGER NOT NULL DEFAULT 0,
        isRead INTEGER NOT NULL DEFAULT 0,
        communicationType TEXT NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES sessions (sessionId)
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        savedAt TEXT NOT NULL,
        user1Confirmed INTEGER NOT NULL DEFAULT 0,
        user2Confirmed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (sessionId) REFERENCES sessions (sessionId)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to existing tables
      await db.execute('ALTER TABLE sessions ADD COLUMN savedAt TEXT');
      await db.execute('ALTER TABLE sessions ADD COLUMN isSaved INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sessions ADD COLUMN chatTitle TEXT');
      await db.execute('ALTER TABLE sessions ADD COLUMN messageCount INTEGER NOT NULL DEFAULT 0');
      
      await db.execute('ALTER TABLE messages ADD COLUMN messageType INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE messages ADD COLUMN stickerPath TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN imagePath TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN fileName TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN isRead INTEGER NOT NULL DEFAULT 0');
      
      // Create new table for saved chats
      await db.execute('''
        CREATE TABLE IF NOT EXISTS saved_chats(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId TEXT NOT NULL,
          savedAt TEXT NOT NULL,
          user1Confirmed INTEGER NOT NULL DEFAULT 0,
          user2Confirmed INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (sessionId) REFERENCES sessions (sessionId)
        )
      ''');
    }
  }

  // Session operations
  Future<int> insertSession(Session session) async {
    Database db = await database;
    return await db.insert('sessions', session.toMap());
  }

  Future<Session?> getSession(String sessionId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    if (maps.isNotEmpty) {
      return Session.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Session>> getAllSessions() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('sessions');
    return List.generate(maps.length, (i) {
      return Session.fromMap(maps[i]);
    });
  }

  Future<int> updateSession(Session session) async {
    Database db = await database;
    return await db.update(
      'sessions',
      session.toMap(),
      where: 'sessionId = ?',
      whereArgs: [session.sessionId],
    );
  }

  Future<int> deleteSession(String sessionId) async {
    Database db = await database;
    return await db.delete(
      'sessions',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // Message operations
  Future<int> insertMessage(Message message) async {
    Database db = await database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<Message>> getMessages(String sessionId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }

  Future<int> updateMessageSentStatus(int messageId, bool isSent) async {
    Database db = await database;
    return await db.update(
      'messages',
      {'isSent': isSent ? 1 : 0},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessage(int messageId) async {
    Database db = await database;
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteSessionMessages(String sessionId) async {
    Database db = await database;
    return await db.delete(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // Save chat operations
  Future<int> saveChat(String sessionId, String? chatTitle) async {
    Database db = await database;
    
    // Update session as saved
    await db.update(
      'sessions',
      {
        'isSaved': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'chatTitle': chatTitle ?? 'Chat ${DateTime.now().toString().substring(0, 10)}',
      },
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    
    // Insert into saved_chats table
    return await db.insert('saved_chats', {
      'sessionId': sessionId,
      'savedAt': DateTime.now().toIso8601String(),
      'user1Confirmed': 0,
      'user2Confirmed': 0,
    });
  }

  Future<List<Session>> getSavedSessions() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'isSaved = ?',
      whereArgs: [1],
      orderBy: 'savedAt DESC',
    );
    return List.generate(maps.length, (i) {
      return Session.fromMap(maps[i]);
    });
  }

  Future<void> confirmSaveChat(String sessionId, bool isUser1) async {
    Database db = await database;
    String column = isUser1 ? 'user1Confirmed' : 'user2Confirmed';
    await db.update(
      'saved_chats',
      {column: 1},
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<Map<String, bool>> getSaveChatConfirmation(String sessionId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'saved_chats',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    
    if (maps.isNotEmpty) {
      return {
        'user1Confirmed': maps.first['user1Confirmed'] == 1,
        'user2Confirmed': maps.first['user2Confirmed'] == 1,
      };
    }
    return {'user1Confirmed': false, 'user2Confirmed': false};
  }

  Future<int> getMessageCount(String sessionId) async {
    Database db = await database;
    var result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE sessionId = ?',
      [sessionId],
    );
    return result.first['count'] as int;
  }
}