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
      version: 1,
      onCreate: _onCreate,
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
        communicationType TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isSent INTEGER NOT NULL DEFAULT 0,
        communicationType TEXT NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES sessions (sessionId)
      )
    ''');
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
}