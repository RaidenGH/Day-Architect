import 'package:flutter/material.dart';
import '../models/sleep_log.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Reactive provider for the Wind Down screen.
/// Calculates bedtime from tomorrow's earliest class, persists toggle states,
/// logs sleep when starting wind-down, and schedules notifications.
class WindDownProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final NotificationService _notif = NotificationService();

  // --- Toggle states (persisted via preferences DB) ---
  bool _dnd = true;
  bool _dimApps = true;
  bool _alarm = false;

  // --- Computed bedtime info ---
  String _earliestClassLabel = '';
  String _earliestClassTime = '';
  DateTime? _earliestClassDt;
  SleepLog? _lastNight;
  double _avgSleepMinutes = 0;
  bool _loading = true;

  // --- Getters ---
  bool get loading => _loading;
  bool get dnd => _dnd;
  bool get dimApps => _dimApps;
  bool get alarm => _alarm;

  SleepLog? get lastNight => _lastNight;
  double get avgSleepMinutes => _avgSleepMinutes;

  /// The target sleep duration in minutes (default 7h 30m).
  int get targetSleepMinutes => _lastNight?.targetDuration ?? 450;

  /// The earliest class time tomorrow as a display string.
  String get earliestClassLabel =>
      _earliestClassLabel.isNotEmpty ? _earliestClassLabel : 'No class tomorrow';

  String get earliestClassTime => _earliestClassTime;

  /// Minutes from now until the recommended bedtime.
  /// Bedtime = earliest class time - target sleep duration - 30 min buffer.
  int get minutesUntilBedtime {
    if (_earliestClassDt == null) return 0;
    final now = DateTime.now();
    final bedtime = _earliestClassDt!.subtract(
      Duration(minutes: targetSleepMinutes + 30),
    );
    final diff = bedtime.difference(now);
    if (diff.isNegative) return 0;
    return diff.inMinutes;
  }

  /// Formatted string like "Bedtime in 28 min".
  String get bedtimeCountdownText {
    final mins = minutesUntilBedtime;
    if (mins <= 0) return 'Bedtime is now!';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return 'Bedtime in ${h}h ${m}m';
    if (h > 0) return 'Bedtime in ${h}h';
    return 'Bedtime in $m min';
  }

  /// Last night's sleep minutes, or 0.
  int get lastNightMinutes => _lastNight?.actualDuration ?? 0;

  /// Formatted minutes helper.
  String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  // ======================== Lifecycle ========================

  /// Load all data: sleep stats, tomorrow's tasks, persisted toggle states.
  Future<void> loadData() async {
    _loading = true;
    notifyListeners();

    try {
      // Load sleep data
      final avg = await _db.getAverageSleepMinutes(days: 7);
      final yesterdayStr =
          DatabaseHelper.formatDate(DateTime.now().subtract(const Duration(days: 1)));
      final lastNight = await _db.getSleepLog(yesterdayStr);

    // Load tomorrow's tasks to find earliest class
    final tomorrowStr =
        DatabaseHelper.formatDate(DateTime.now().add(const Duration(days: 1)));
    final tomorrowTasks = await _db.getTasks(date: tomorrowStr);

    // Find earliest class among tomorrow's tasks
    String earliestLabel = '';
    String earliestTime = '';
    DateTime? earliestDt;
    TimeOfDay? earliestParsed;
    for (final task in tomorrowTasks) {
      final parsed = _parseTime(task.time);
      if (parsed == null) continue;
      if (earliestParsed == null ||
          parsed.hour < earliestParsed.hour ||
          (parsed.hour == earliestParsed.hour &&
              parsed.minute < earliestParsed.minute)) {
        earliestParsed = parsed;
        earliestLabel = task.title;
        earliestTime = task.time;
      }
    }
    if (earliestParsed != null) {
      earliestDt = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + 1,
        earliestParsed.hour,
        earliestParsed.minute,
      );
    }

    // Load persisted toggle states
    final dndVal = await _db.getPreference('winddown_dnd');
    final dimVal = await _db.getPreference('winddown_dim_apps');
    final alarmVal = await _db.getPreference('winddown_alarm');

    _avgSleepMinutes = avg;
    _lastNight = lastNight;
    _earliestClassLabel = earliestLabel;
    _earliestClassTime = earliestTime;
    _earliestClassDt = earliestDt;
    _dnd = dndVal != 'false';
    _dimApps = dimVal != 'false';
    _alarm = alarmVal == 'true';
    _loading = false;
    notifyListeners();
    } catch (e) {
      debugPrint('WindDownProvider: loadData failed – $e');
      _loading = false;
      notifyListeners();
    }
  }

  // ======================== Toggles ========================

  Future<void> setDnd(bool value) async {
    _dnd = value;
    await _db.setPreference('winddown_dnd', value.toString());
    notifyListeners();
  }

  Future<void> setDimApps(bool value) async {
    _dimApps = value;
    await _db.setPreference('winddown_dim_apps', value.toString());
    notifyListeners();
  }

  Future<void> setAlarm(bool value) async {
    _alarm = value;
    await _db.setPreference('winddown_alarm', value.toString());
    notifyListeners();
  }

  // ======================== Start Wind-down ========================

  /// Log tonight's sleep entry and schedule the wind-down reminder notification.
  /// Uses [insertSleepLog] which handles upsert (update existing or insert new).
  Future<void> startWindDown({required DateTime bedtime}) async {
    final todayStr = DatabaseHelper.formatDate(DateTime.now());
    final wakeTime = bedtime.add(Duration(minutes: targetSleepMinutes));

    final log = SleepLog(
      date: todayStr,
      targetDuration: targetSleepMinutes,
      bedtime: bedtime,
      wakeTime: wakeTime,
    );
    await _db.insertSleepLog(log);

    // Schedule notification reminder
    if (_earliestClassDt != null) {
      final reminderTime = DateTime.now().add(const Duration(minutes: 3));
      final minsUntilBed =
          bedtime.difference(DateTime.now()).inMinutes.clamp(1, 999);
      await _notif.scheduleWindDown(
        scheduledDate: reminderTime,
        minutesUntilBedtime: minsUntilBed,
        earliestClassLabel: '$earliestClassLabel at $earliestClassTime',
      );
    }

    notifyListeners();
  }

  // ======================== Helpers ========================

  /// Parse a time string like "8:00" or "10:30" into a TimeOfDay.
  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
