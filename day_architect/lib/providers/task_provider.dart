import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Reactive state provider for tasks on the Today screen.
/// Wraps DatabaseHelper CRUD, notifies listeners so the UI rebuilds automatically.
/// Also schedules / cancels task reminder notifications.
class TaskProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final NotificationService _notif = NotificationService();

  List<Task> _tasks = [];
  int _streak = 0;
  int _totalDone = 0;
  bool _loading = true;

  List<Task> get tasks => _tasks;
  int get streak => _streak;
  int get totalDone => _totalDone;
  int get totalBlocks => _tasks.length;
  bool get loading => _loading;

  /// Load today's tasks, streak, and completion count.
  Future<void> loadToday() async {
    _loading = true;
    notifyListeners();

    final todayStr = DatabaseHelper.formatDate(DateTime.now());
    _tasks = await _db.getTasks(date: todayStr);
    // Sort tasks by time (chronologically), not by insertion order
    _tasks.sort((a, b) => _timeToMinutes(a.time).compareTo(_timeToMinutes(b.time)));
    _streak = await _db.getStreak();
    _totalDone = _tasks.where((t) => t.done).length;

    _loading = false;
    notifyListeners();
    // Re-schedule reminders for all incomplete tasks.
    // This is needed after app restart because zonedSchedule
    // notifications are fire-once and don't persist across restarts.
    try {
      await scheduleAllReminders();
    } catch (e) {
      debugPrint('TaskProvider: scheduleAllReminders failed: $e');
    }
  }

  /// Convert a time string ("8:00 AM", "2:30 PM") to minutes since midnight.
  int _timeToMinutes(String timeStr) {
    final cleaned = timeStr.trim().toUpperCase();
    final isPm = cleaned.contains('PM');
    final numeric = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = numeric.split(':');
    if (parts.length < 2) return 0;

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  /// Toggle a task's done state.
  Future<void> toggleDone(Task task) async {
    final updated = task.copyWith(done: !task.done);
    await _db.updateTask(updated);

    // Cancel the notification if the task is now done
    if (updated.done && updated.id != null) {
      await _notif.cancelTaskReminder(updated.id!);
    }

    // Optimistic local update
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updated;
      _totalDone = _tasks.where((t) => t.done).length;
    }
    // Refresh streak — it may have changed
    _streak = await _db.getStreak();
    notifyListeners();
  }

  /// Add a new task for today.
  Future<void> addTask(Task task) async {
    final todayStr = DatabaseHelper.formatDate(DateTime.now());
    final newTask = task.copyWith(
      date: todayStr,
      sortOrder: _tasks.length,
    );
    final newId = await _db.insertTask(newTask);

    // Schedule a reminder notification for this task
    if (!newTask.done) {
      await _notif.scheduleTaskReminder(
        notificationId: newId,
        taskTitle: newTask.title,
        taskTime: newTask.time,
      );
    }

    await loadToday();
  }

  /// Update an existing task.
  Future<void> updateTask(Task task) async {
    if (task.id != null) {
      // Cancel the old notification first
      await _notif.cancelTaskReminder(task.id!);

      // Re-schedule if the task isn't done
      if (!task.done && task.time.isNotEmpty) {
        await _notif.scheduleTaskReminder(
          notificationId: task.id!,
          taskTitle: task.title,
          taskTime: task.time,
        );
      }
    }

    await _db.updateTask(task);
    await loadToday();
  }

  /// Delete a task by id.
  Future<void> deleteTask(int id) async {
    // Cancel the notification first
    await _notif.cancelTaskReminder(id);

    await _db.deleteTask(id);
    await loadToday();
  }

  /// Schedule reminders for all incomplete tasks today.
  /// Called when the app starts to ensure notifications are set.
  Future<void> scheduleAllReminders() async {
    for (final task in _tasks) {
      if (!task.done && task.id != null && task.time.isNotEmpty) {
        await _notif.scheduleTaskReminder(
          notificationId: task.id!,
          taskTitle: task.title,
          taskTime: task.time,
        );
      }
    }
  }
}
