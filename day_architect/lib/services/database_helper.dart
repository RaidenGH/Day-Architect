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
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add date column to tasks
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN date TEXT');
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
    // v3 -> v4: add new columns for Phase 3 models
    if (oldVersion < 4) {
      // Tasks: add category, startTime, durationMinutes
      await db.execute('ALTER TABLE tasks ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN startTime TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN durationMinutes INTEGER');
      // Backfill category from chipLabel
      await db.rawUpdate('UPDATE tasks SET category = chipLabel');

      // Focus sessions: add subject, plannedMinutes, actualMinutes, startTime, endTime
      await db.execute('ALTER TABLE focus_sessions ADD COLUMN subject TEXT');
      await db.execute('ALTER TABLE focus_sessions ADD COLUMN plannedMinutes INTEGER');
      await db.execute('ALTER TABLE focus_sessions ADD COLUMN actualMinutes INTEGER');
      await db.execute('ALTER TABLE focus_sessions ADD COLUMN startTime TEXT');
      await db.execute('ALTER TABLE focus_sessions ADD COLUMN endTime TEXT');
      // Backfill subject from title, plannedMinutes from durationMinutes, actualMinutes from durationMinutes
      await db.rawUpdate('UPDATE focus_sessions SET subject = title, plannedMinutes = durationMinutes, actualMinutes = durationMinutes');

      // Sleep logs: add actualDuration, targetDuration, bedtime, wakeTime
      await db.execute('ALTER TABLE sleep_logs ADD COLUMN actualDuration INTEGER');
      await db.execute('ALTER TABLE sleep_logs ADD COLUMN targetDuration INTEGER');
      await db.execute('ALTER TABLE sleep_logs ADD COLUMN bedtime TEXT');
      await db.execute('ALTER TABLE sleep_logs ADD COLUMN wakeTime TEXT');
      // Backfill
      await db.rawUpdate('UPDATE sleep_logs SET actualDuration = sleepDurationMinutes, targetDuration = goalDurationMinutes');
    }
    // v4 -> v5: add blocked_apps table
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS blocked_apps (
          package_name TEXT PRIMARY KEY,
          display_name TEXT NOT NULL,
          selected INTEGER NOT NULL DEFAULT 1
        )
      ''');
      // Seed with default blocked apps
      final defaults = [
        ('com.instagram.android', 'Instagram'),
        ('com.zhiliaoapp.musically', 'TikTok'),
        ('com.ss.android.ugc.trill', 'TikTok'),
        ('com.facebook.katana', 'Facebook'),
        ('com.facebook.orca', 'Messenger'),
        ('com.twitter.android', 'X / Twitter'),
        ('com.snapchat.android', 'Snapchat'),
        ('com.spotify.music', 'Spotify'),
        ('com.netflix.mediaclient', 'Netflix'),
        ('com.google.android.youtube', 'YouTube'),
      ];
      for (final (pkg, name) in defaults) {
        await db.insert('blocked_apps', {
          'package_name': pkg,
          'display_name': name,
          'selected': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    // v5 -> v6: rename selected to is_blocked, add is_system column
    if (oldVersion < 6) {
      // SQLite doesn't support renaming columns, so recreate the table
      await db.execute('ALTER TABLE blocked_apps RENAME TO blocked_apps_old');
      await db.execute('''
        CREATE TABLE blocked_apps (
          package_name TEXT PRIMARY KEY,
          display_name TEXT NOT NULL,
          is_blocked INTEGER NOT NULL DEFAULT 0,
          is_system INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO blocked_apps (package_name, display_name, is_blocked, is_system)
        SELECT package_name, display_name, selected, 0 FROM blocked_apps_old
      ''');
      await db.execute('DROP TABLE blocked_apps_old');
    }
    // v6 -> v7: reset default apps to unblocked (they were incorrectly seeded as blocked)
    if (oldVersion < 7) {
      final defaults = [
        'com.instagram.android',
        'com.zhiliaoapp.musically',
        'com.ss.android.ugc.trill',
        'com.facebook.katana',
        'com.facebook.orca',
        'com.twitter.android',
        'com.snapchat.android',
        'com.spotify.music',
        'com.netflix.mediaclient',
        'com.google.android.youtube',
      ];
      for (final pkg in defaults) {
        await db.update(
          'blocked_apps',
          {'is_blocked': 0},
          where: 'package_name = ?',
          whereArgs: [pkg],
        );
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // --- Tasks table (v4 schema) ---
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
        sortOrder INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        startTime TEXT,
        durationMinutes INTEGER
      )
    ''');

    // --- Focus sessions table (v4 schema) ---
    await db.execute('''
      CREATE TABLE focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        title TEXT,
        taskId INTEGER,
        plannedMinutes INTEGER NOT NULL DEFAULT 25,
        actualMinutes INTEGER NOT NULL DEFAULT 0,
        durationMinutes INTEGER NOT NULL DEFAULT 25,
        interruptions INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        startTime TEXT,
        endTime TEXT,
        FOREIGN KEY (taskId) REFERENCES tasks(id)
      )
    ''');

    // --- Sleep logs table (v4 schema) ---
    await db.execute('''
      CREATE TABLE sleep_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        actualDuration INTEGER NOT NULL DEFAULT 0,
        targetDuration INTEGER NOT NULL DEFAULT 450,
        sleepDurationMinutes INTEGER NOT NULL DEFAULT 0,
        goalDurationMinutes INTEGER NOT NULL DEFAULT 450,
        bedtime TEXT,
        wakeTime TEXT
      )
    ''');

    // --- Preferences table ---
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // --- Blocked apps table ---
    await db.execute('''
      CREATE TABLE IF NOT EXISTS blocked_apps (
        package_name TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        is_blocked INTEGER NOT NULL DEFAULT 0,
        is_system INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Seed sample data
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

    // --- Seed tasks (Today's schedule) with new v4 columns ---
    await db.insert('tasks', {
      'title': 'Wake & stretch',
      'time': '7:30',
      'chipLabel': 'Routine',
      'category': 'Routine',
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
      'category': 'Class',
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
      'category': 'Focus',
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
      'category': 'Org',
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
      'category': 'Sleep',
      'accentColor': sage,
      'chipBg': chipSage,
      'done': 0,
      'date': todayStr,
      'sortOrder': 5,
    });

    // --- Seed focus sessions (v4 schema) ---
    await db.insert('focus_sessions', {
      'subject': 'Thesis Defense Prep',
      'title': 'Thesis Defense Prep',
      'plannedMinutes': 47,
      'actualMinutes': 47,
      'durationMinutes': 47,
      'interruptions': 0,
      'date': _todayString,
    });
    await db.insert('focus_sessions', {
      'subject': 'Software Design Review',
      'title': 'Software Design Review',
      'plannedMinutes': 35,
      'actualMinutes': 35,
      'durationMinutes': 35,
      'interruptions': 1,
      'date': _todayString,
    });
    await db.insert('focus_sessions', {
      'subject': 'Math Practice',
      'title': 'Math Practice',
      'plannedMinutes': 42,
      'actualMinutes': 42,
      'durationMinutes': 42,
      'interruptions': 0,
      'date': _yesterdayString,
    });

    // --- Seed sleep logs (7 days) with v4 columns ---
    final today = DateTime.now();
    final sleepData = [
      (minutes: 340, goal: 450),
      (minutes: 430, goal: 450),
      (minutes: 360, goal: 450),
      (minutes: 440, goal: 450),
      (minutes: 405, goal: 450),
      (minutes: 450, goal: 450),
      (minutes: 450, goal: 450),
    ];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final dateStr = formatDate(day);
      final data = sleepData[6 - i];
      await db.insert('sleep_logs', {
        'date': dateStr,
        'actualDuration': data.minutes,
        'targetDuration': data.goal,
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

  Future<int> updateFocusSession(FocusSession session) async {
    final db = await database;
    return await db.update(
      'focus_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
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
    // If a log with this date exists, replace it
    final existing = await getSleepLog(log.date);
    if (existing != null) {
      return await db.update(
        'sleep_logs',
        log.toMap(),
        where: 'date = ?',
        whereArgs: [log.date],
      );
    }
    return await db.insert('sleep_logs', log.toMap());
  }

  /// Delete a sleep log by date.
  Future<void> deleteSleepLog(String date) async {
    final db = await database;
    await db.delete('sleep_logs', where: 'date = ?', whereArgs: [date]);
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

  /// Get a set of dates (yyyy-MM-dd) that meet the 80% completion threshold.
  /// Useful for rendering the streak calendar in the UI.
  Future<Set<String>> getCompletedTaskDates({int days = 7}) async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - days + 1);
    // A day qualifies if at least 80% of its tasks are done
    final maps = await db.rawQuery('''
      SELECT date,
             CAST(SUM(CASE WHEN done = 1 THEN 1 ELSE 0 END) AS REAL) /
             CAST(COUNT(*) AS REAL) AS completion_ratio
      FROM tasks
      WHERE date >= ? AND date <= ?
      GROUP BY date
      HAVING completion_ratio >= 0.8
      ORDER BY date ASC
    ''', [formatDate(start), formatDate(today)]);

    return maps.map((m) => m['date'] as String).toSet();
  }

  // ==================== Streak ====================

  /// Calculate the current streak: consecutive trailing days (including today)
  /// where at least 80% of tasks were marked done.
  Future<int> getStreak() async {
    final db = await database;
    final today = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      final dateStr = formatDate(day);

      // Check if at least 80% of tasks are done for this day
      final result = await db.rawQuery('''
        SELECT 
          CAST(SUM(CASE WHEN done = 1 THEN 1 ELSE 0 END) AS REAL) /
          CAST(COUNT(*) AS REAL) AS completion_ratio
        FROM tasks WHERE date = ?
      ''', [dateStr]);
      final row = result.first;
      final ratio = (row['completion_ratio'] as num?)?.toDouble() ?? 0.0;

      if (ratio >= 0.8) {
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

  // ==================== Blocked Apps CRUD ====================

  /// Upsert a single app's block state. Called immediately when a toggle flips.
  Future<void> setAppBlocked(String packageName, String displayName,
      {required bool isBlocked, bool isSystem = false}) async {
    final db = await database;
    await db.insert(
      'blocked_apps',
      {
        'package_name': packageName,
        'display_name': displayName,
        'is_blocked': isBlocked ? 1 : 0,
        'is_system': isSystem ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all apps from the DB (both blocked and unblocked).
  Future<List<Map<String, dynamic>>> getAllBlockedApps() async {
    final db = await database;
    return await db.query('blocked_apps', orderBy: 'display_name ASC');
  }

  /// Get only blocked (is_blocked = 1) apps as package name strings.
  Future<List<String>> getBlockedPackageNames() async {
    final db = await database;
    final maps = await db.query('blocked_apps',
        where: 'is_blocked = 1', orderBy: 'display_name ASC');
    return maps.map((m) => m['package_name'] as String).toList();
  }

  /// Delete all rows from blocked_apps (used before a fresh scan).
  Future<void> clearBlockedApps() async {
    final db = await database;
    await db.delete('blocked_apps');
  }

  /// Insert many apps at once (used after scanning installed apps).
  Future<void> insertAllApps(List<Map<String, dynamic>> apps) async {
    final db = await database;
    final batch = db.batch();
    for (final app in apps) {
      batch.insert(
        'blocked_apps',
        {
          'package_name': app['packageName'] ?? '',
          'display_name': app['displayName'] ?? 'Unknown',
          'is_blocked': (app['is_blocked'] as int?) ?? 0,
          'is_system': (app['isSystem'] == true) ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Format a DateTime as yyyy-MM-dd.
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
