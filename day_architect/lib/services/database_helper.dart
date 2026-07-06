import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../models/sleep_log.dart';

/// Singleton helper managing the local SQLite database.
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'day_architect.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add date column to tasks
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN date TEXT');
      // Backfill existing rows with today's date
      final todayStr = formatDate(DateTime.now());
      await db.update('tasks', {'date': todayStr});
    }
    // v2 -> v3: add preferences table
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS preferences (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // --- Tasks table ---
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        time TEXT NOT NULL,
        chipLabel TEXT NOT NULL,
        accentColor INTEGER NOT NULL,
        chipBg INTEGER NOT NULL,
        meta TEXT,
        done INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // --- Focus sessions table ---
    await db.execute('''
      CREATE TABLE focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        taskId INTEGER,
        durationMinutes INTEGER NOT NULL,
        interruptions INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        FOREIGN KEY (taskId) REFERENCES tasks(id)
      )
    ''');

    // --- Sleep logs table ---
    await db.execute('''
      CREATE TABLE sleep_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        sleepDurationMinutes INTEGER NOT NULL,
        goalDurationMinutes INTEGER NOT NULL DEFAULT 450
      )
    ''');

    // --- Preferences table ---
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed sample data matching the current hardcoded UI
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // Colors from AppTheme (stored as ints via Color.value)
    const sage = 0xFF9CAF94;
    const accent = 0xFFE8935B;
    const accentSoft = 0xFFF2A488;
    const plum = 0xFF6E6A99;
    const chipSage = 0x339CAF94;
    const chipAmber = 0x33E8935B;
    const chipCoral = 0x33F2A488;
    const chipPlum = 0x336E6A99;

    final todayStr = formatDate(DateTime.now());

    // --- Seed tasks (Today's schedule) ---
    await db.insert('tasks', {
      'title': 'Wake & stretch',
      'time': '7:30',
      'chipLabel': 'Routine',
      'accentColor': sage,
      'chipBg': chipSage,
      'done': 1,
      'date': todayStr,
      'sortOrder': 1,
    });
    await db.insert('tasks', {
      'title': 'Software Design Lecture',
      'time': '8:00',
      'chipLabel': 'Class',
      'accentColor': accent,
      'chipBg': chipAmber,
      'meta': 'CpE 205 · Rm 302',
      'done': 1,
      'date': todayStr,
      'sortOrder': 2,
    });
    await db.insert('tasks', {
      'title': 'Focus Block: Thesis Prep',
      'time': '10:30',
      'chipLabel': 'Focus',
      'accentColor': accentSoft,
      'chipBg': chipCoral,
      'meta': '30 min · Social media blocked',
      'done': 0,
      'date': todayStr,
      'sortOrder': 3,
    });
    await db.insert('tasks', {
      'title': 'Org Meeting — BITS',
      'time': '2:00',
      'chipLabel': 'Org',
      'accentColor': plum,
      'chipBg': chipPlum,
      'done': 0,
      'date': todayStr,
      'sortOrder': 4,
    });
    await db.insert('tasks', {
      'title': 'Wind-down begins',
      'time': '8:30',
      'chipLabel': 'Sleep',
      'accentColor': sage,
      'chipBg': chipSage,
      'done': 0,
      'date': todayStr,
      'sortOrder': 5,
    });

    // --- Seed focus sessions ---
    await db.insert('focus_sessions', {
      'title': 'Thesis Defense Prep',
      'durationMinutes': 47,
      'interruptions': 0,
      'date': _todayString,
    });
    await db.insert('focus_sessions', {
      'title': 'Software Design Review',
      'durationMinutes': 35,
      'interruptions': 1,
      'date': _todayString,
    });
    await db.insert('focus_sessions', {
      'title': 'Math Practice',
      'durationMinutes': 42,
      'interruptions': 0,
      'date': _yesterdayString,
    });

    // --- Seed sleep logs (7 days) ---
    final today = DateTime.now();
    final sleepData = [
      (minutes: 340, goal: 450), // 5h 40m
      (minutes: 430, goal: 450), // 7h 10m
      (minutes: 360, goal: 450), // 6h 00m
      (minutes: 440, goal: 450), // 7h 20m
      (minutes: 405, goal: 450), // 6h 45m
      (minutes: 450, goal: 450), // 7h 30m
      (minutes: 450, goal: 450), // goal
    ];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final dateStr = formatDate(day);
      final data = sleepData[6 - i];
      await db.insert('sleep_logs', {
        'date': dateStr,
        'sleepDurationMinutes': data.minutes,
        'goalDurationMinutes': data.goal,
      });
    }
  }

  // ==================== Task CRUD ====================

  Future<List<Task>> getTasks({String? date}) async {
    final db = await database;
    final where = date != null ? 'date = ?' : null;
    final whereArgs = date != null ? [date] : null;
    final maps = await db.query(
      'tasks',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<Task?> getTask(int id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Focus Session CRUD ====================

  Future<List<FocusSession>> getFocusSessions({String? date}) async {
    final db = await database;
    final where = date != null ? 'date = ?' : null;
    final whereArgs = date != null ? [date] : null;
    final maps = await db.query(
      'focus_sessions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return maps.map((m) => FocusSession.fromMap(m)).toList();
  }

  Future<int> insertFocusSession(FocusSession session) async {
    final db = await database;
    return await db.insert('focus_sessions', session.toMap());
  }

  /// Get total focus minutes for a date range.
  Future<int> getTotalFocusMinutes({String? date}) async {
    final db = await database;
    final where = date != null ? 'WHERE date = ?' : '';
    final whereArgs = date != null ? [date] : null;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(durationMinutes), 0) as total FROM focus_sessions $where',
      whereArgs,
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Get total focus minutes for each day of the current week.
  Future<Map<String, int>> getFocusMinutesByDay() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - today.weekday + 1);
    final maps = await db.rawQuery('''
      SELECT date, COALESCE(SUM(durationMinutes), 0) as total
      FROM focus_sessions
      WHERE date >= ? AND date <= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [formatDate(start), formatDate(today)]);

    final result = <String, int>{};
    for (final row in maps) {
      result[row['date'] as String] = (row['total'] as int?) ?? 0;
    }
    return result;
  }

  // ==================== Sleep Log CRUD ====================

  Future<List<SleepLog>> getSleepLogs({int? days}) async {
    final db = await database;
    final maps = await db.query(
      'sleep_logs',
      orderBy: 'date DESC',
      limit: days,
    );
    return maps.map((m) => SleepLog.fromMap(m)).toList();
  }

  Future<SleepLog?> getSleepLog(String date) async {
    final db = await database;
    final maps = await db.query('sleep_logs', where: 'date = ?', whereArgs: [date]);
    if (maps.isEmpty) return null;
    return SleepLog.fromMap(maps.first);
  }

  Future<int> insertSleepLog(SleepLog log) async {
    final db = await database;
    return await db.insert('sleep_logs', log.toMap());
  }

  Future<double> getAverageSleepMinutes({int days = 7}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(AVG(sleepDurationMinutes), 0) as avg FROM sleep_logs ORDER BY date DESC LIMIT ?',
      [days],
    );
    return (result.first['avg'] as num?)?.toDouble() ?? 0.0;
  }

  // ==================== Preferences CRUD ====================

  Future<String?> getPreference(String key) async {
    final db = await database;
    final maps = await db.query('preferences',
        where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setPreference(String key, String value) async {
    final db = await database;
    await db.insert(
      'preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllPreferences() async {
    final db = await database;
    final maps = await db.query('preferences');
    return {for (final m in maps) m['key'] as String: m['value'] as String};
  }

  /// Get the average focus minutes per day of week across all time.
  /// Returns a map where keys are day-of-week numbers (1=Monday..7=Sunday)
  /// and values are the average focus minutes for that day.
  Future<Map<int, double>> getAverageFocusMinutesByDayOfWeek() async {
    final db = await database;
    // SQLite's strftime('%w', date) returns 0=Sunday..6=Saturday.
    // We adjust to 1=Monday..7=Sunday by: ((strftime('%w', date) + 6) % 7) + 1
    final maps = await db.rawQuery('''
      SELECT
        ((CAST(strftime('%w', date) AS INTEGER) + 6) % 7) + 1 AS day_of_week,
        AVG(CAST(durationMinutes AS REAL)) AS avg_minutes
      FROM focus_sessions
      GROUP BY day_of_week
      ORDER BY day_of_week ASC
    ''');

    final result = <int, double>{};
    for (final row in maps) {
      final dow = row['day_of_week'] as int;
      final avg = (row['avg_minutes'] as num?)?.toDouble() ?? 0.0;
      result[dow] = avg;
    }
    return result;
  }

  // ==================== Streak ====================

  /// Calculate the current streak: consecutive trailing days (including today)
  /// where at least one completed task exists.
  Future<int> getStreak() async {
    final db = await database;
    final today = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      final dateStr = formatDate(day);

      // Check if any completed task exists for this day
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM tasks WHERE date = ? AND done = 1',
        [dateStr],
      );
      final count = (result.first['cnt'] as int?) ?? 0;

      if (count > 0) {
        streak++;
      } else {
        break; // streak broken
      }
    }
    return streak;
  }

  // ==================== Helpers ====================

  static String get _todayString => formatDate(DateTime.now());
  static String get _yesterdayString =>
      formatDate(DateTime.now().subtract(const Duration(days: 1)));

  /// Format a DateTime as yyyy-MM-dd.
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
