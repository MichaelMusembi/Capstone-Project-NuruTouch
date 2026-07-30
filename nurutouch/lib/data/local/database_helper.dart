import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../models/braille_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  // For pilot, hardcode a DB password. In prod, this would come from SecureStorage.
  final String _dbPassword = "nurutouch_secure_db_key_2026!";

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nurutouch_secure.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      password: _dbPassword,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS session_state');
        await db.execute('DROP TABLE IF EXISTS attempt_events');
        await db.execute('DROP TABLE IF EXISTS lessons_progress');
        await db.execute('DROP TABLE IF EXISTS students');
        await db.execute('DROP TABLE IF EXISTS supervisors');
        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        face_embedding TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE supervisors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE lessons_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        easiness_factor REAL NOT NULL DEFAULT 2.5,
        interval_minutes INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        next_review_date INTEGER NOT NULL DEFAULT 0,
        passed INTEGER NOT NULL DEFAULT 0,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_timestamp INTEGER NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(student_id, language, lesson_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE attempt_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        attempt_timestamp INTEGER NOT NULL,
        input_pattern TEXT NOT NULL,
        target_pattern TEXT NOT NULL,
        error_type TEXT NOT NULL,
        hint_level_reached INTEGER NOT NULL,
        FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE session_state (
        student_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        current_lesson_id TEXT NOT NULL,
        current_stage TEXT NOT NULL,
        current_item_index INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (student_id, language),
        FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- STUDENTS ---
  Future<int> insertStudent(String name, int age, List<double> faceEmbedding) async {
    final db = await instance.database;
    return await db.insert('students', {
      'name': name,
      'age': age,
      'face_embedding': jsonEncode(faceEmbedding),
    });
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final db = await instance.database;
    return await db.query('students');
  }

  // --- SUPERVISORS ---
  Future<bool> authenticateSupervisor(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'supervisors',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (result.isEmpty) return false;
    
    final hash = result.first['password_hash'] as String;
    return BCrypt.checkpw(password, hash);
  }

  Future<List<Map<String, dynamic>>> getAllSupervisors() async {
    final db = await instance.database;
    return await db.query('supervisors');
  }

  Future<int> insertSupervisor(String email, String password) async {
    final db = await instance.database;
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    return await db.insert('supervisors', {
      'email': email,
      'password_hash': hash,
    });
  }

  // --- LESSON PROGRESS ---
  Future<void> upsertLessonProgress(BrailleRecord record) async {
    final db = await instance.database;
    await db.insert(
      'lessons_progress',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getStudentProgress(int studentId, {String? languageCode}) async {
    final db = await instance.database;
    if (languageCode != null) {
      return await db.query(
        'lessons_progress',
        where: 'student_id = ? AND language = ?',
        whereArgs: [studentId, languageCode],
      );
    } else {
      return await db.query(
        'lessons_progress',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
    }
  }

  Future<List<BrailleRecord>> getAllProgress() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('lessons_progress');
    return List.generate(maps.length, (i) {
      return BrailleRecord.fromMap(maps[i]);
    });
  }

  Future<bool> hasPassedLesson(int studentId, String language, String lessonId) async {
    final db = await instance.database;
    try {
      final existing = await db.query(
        'lessons_progress',
        where: 'student_id = ? AND language = ? AND lesson_id = ? AND passed = 1',
        whereArgs: [studentId, language, lessonId],
      );
      return existing.isNotEmpty;
    } catch (e) {
      print("Error in hasPassedLesson: \$e");
      return false;
    }
  }
  
  // --- SESSION STATE ---
  Future<void> saveSessionState(int studentId, String language, String lessonId, String stage, int itemIndex) async {
    final db = await instance.database;
    await db.insert(
      'session_state',
      {
        'student_id': studentId,
        'language': language,
        'current_lesson_id': lessonId,
        'current_stage': stage,
        'current_item_index': itemIndex,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<Map<String, dynamic>?> getSessionState(int studentId, String language) async {
    final db = await instance.database;
    final result = await db.query(
      'session_state',
      where: 'student_id = ? AND language = ?',
      whereArgs: [studentId, language],
    );
    return result.isNotEmpty ? result.first : null;
  }
  
  // --- ATTEMPT EVENTS ---
  Future<void> logAttemptEvent({
    required int studentId,
    required String language,
    required String lessonId,
    required String inputPattern,
    required String targetPattern,
    required String errorType,
    required int hintLevelReached,
  }) async {
    final db = await instance.database;
    await db.insert('attempt_events', {
      'student_id': studentId,
      'language': language,
      'lesson_id': lessonId,
      'attempt_timestamp': DateTime.now().millisecondsSinceEpoch,
      'input_pattern': inputPattern,
      'target_pattern': targetPattern,
      'error_type': errorType,
      'hint_level_reached': hintLevelReached,
    });
  }

  Future<List<Map<String, dynamic>>> getStudentAttempts(int studentId, {int limit = 50}) async {
    final db = await instance.database;
    return await db.query(
      'attempt_events',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'attempt_timestamp DESC',
      limit: limit,
    );
  }

  Future<String?> getLastMasteredLessonId(int studentId) async {
    final db = await instance.database;
    final result = await db.query(
      'lessons_progress',
      columns: ['lesson_id'],
      where: 'student_id = ? AND passed = 1',
      whereArgs: [studentId],
      orderBy: 'last_attempt_timestamp DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first['lesson_id'] as String : null;
  }

  Future<int> getTodayMasteredCount(int studentId, String language) async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM lessons_progress WHERE student_id = ? AND language = ? AND passed = 1 AND last_attempt_timestamp >= ?',
      [studentId, language, startOfDay]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteSessionState(int studentId, String language) async {
    final db = await instance.database;
    await db.delete(
      'session_state',
      where: 'student_id = ? AND language = ?',
      whereArgs: [studentId, language],
    );
  }
}
