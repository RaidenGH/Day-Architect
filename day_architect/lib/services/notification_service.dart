import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Singleton service for firing local notifications (e.g. focus session complete, wind-down reminder).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _focusChannelId = 'focus_sessions';
  static const _focusChannelName = 'Focus Sessions';
  static const _focusChannelDesc = 'Notifications when a focus session ends.';

  static const _windDownChannelId = 'wind_down';
  static const _windDownChannelName = 'Wind Down';
  static const _windDownChannelDesc = 'Reminders when it\'s time to wind down for bed.';

  static const _taskChannelId = 'task_reminders';
  static const _taskChannelName = 'Task Reminders';
  static const _taskChannelDesc = 'Notifications when a scheduled task is due.';

  /// Call once from main() before runApp.
  Future<void> init() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Android channel
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    // Create notification channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _focusChannelId,
        _focusChannelName,
        description: _focusChannelDesc,
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _windDownChannelId,
        _windDownChannelName,
        description: _windDownChannelDesc,
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _taskChannelId,
        _taskChannelName,
        description: _taskChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Request permission on Android 13+
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Fire an immediate notification (not scheduled).
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _focusChannelId,
        _focusChannelName,
        channelDescription: _focusChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  /// Fire the built-in "Focus session complete!" notification.
  Future<void> showSessionComplete(int minutesFocused) async {
    final hours = minutesFocused ~/ 60;
    final mins = minutesFocused % 60;
    String durationStr;
    if (hours > 0 && mins > 0) {
      durationStr = '${hours}h ${mins}m';
    } else if (hours > 0) {
      durationStr = '${hours}h';
    } else {
      durationStr = '${mins}m';
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎯 Session Complete!',
      body: 'You focused for $durationStr. Great work!',
    );
  }

  /// Schedule a wind-down reminder notification at the given date/time.
  Future<void> scheduleWindDown({
    required DateTime scheduledDate,
    required int minutesUntilBedtime,
    required String earliestClassLabel,
  }) async {
    // Cancel any previously scheduled wind-down
    await cancelWindDown();

    final tzLocation = tz.local;
    final scheduledTz = tz.TZDateTime.from(scheduledDate, tzLocation);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _windDownChannelId,
        _windDownChannelName,
        channelDescription: _windDownChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      _windDownNotificationId,
      '🌙 Time to wind down',
      'Bedtime is in $minutesUntilBedtime min. Class starts at $earliestClassLabel tomorrow.',
      scheduledTz,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancel the scheduled wind-down notification.
  Future<void> cancelWindDown() async {
    await _plugin.cancel(_windDownNotificationId);
  }

  // ======================== Task Reminder Notifications ========================

  /// Schedule a notification for when a task is due.
  /// [taskTime] should be a string like "8:00 AM" or "2:30 PM".
  /// [notificationId] should be the task's unique ID.
  ///
  /// If the time has already passed by more than 2 minutes, fires immediately
  /// instead of scheduling (catches edge cases where the task is added late).
  Future<void> scheduleTaskReminder({
    required int notificationId,
    required String taskTitle,
    required String taskTime,
  }) async {
    // Parse the task time into a DateTime for today
    final scheduledDate = _parseTaskTime(taskTime);
    if (scheduledDate == null) {
      debugPrint('⏰ NOTIF: Could not parse time "$taskTime" — skipping');
      return;
    }

    final now = DateTime.now();
    final diff = scheduledDate.difference(now);

    // If time is more than 2 minutes in the past, fire immediately
    if (diff.inMinutes < -2) {
      debugPrint('⏰ NOTIF: "$taskTitle" at $taskTime is in the past — firing immediately');
      await _showTaskImmediate(
        id: notificationId,
        title: '⏰ $taskTitle',
        body: 'This task was scheduled for $taskTime.',
      );
      return;
    }

    // If time is within 2 minutes (past or future), fire immediately
    if (diff.inMinutes < 2) {
      debugPrint('⏰ NOTIF: "$taskTitle" at $taskTime is imminent — firing immediately');
      await _showTaskImmediate(
        id: notificationId,
        title: '⏰ $taskTitle',
        body: 'Your scheduled task is starting now.',
      );
      return;
    }

    // Schedule normally with exact alarm timing
    debugPrint('⏰ NOTIF: Scheduling "$taskTitle" for $taskTime (${diff.inMinutes} min from now)');

    final tzLocation = tz.local;
    final scheduledTz = tz.TZDateTime.from(scheduledDate, tzLocation);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        channelDescription: _taskChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        vibrationPattern: Int64List.fromList([1000, 500, 1000, 500]),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      notificationId,
      '⏰ $taskTitle',
      'Your scheduled task is starting now.',
      scheduledTz,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel a task reminder by its task ID.
  Future<void> cancelTaskReminder(int taskId) async {
    await _plugin.cancel(taskId);
  }

  /// Fire an immediate notification on the task reminder channel (alarm-style).
  /// Used when a past/imminent task fires right away instead of scheduling.
  Future<void> _showTaskImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        channelDescription: _taskChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        vibrationPattern: Int64List.fromList([1000, 500, 1000, 500]),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  /// Parse a time string like "8:00 AM" or "7am" or "14:00" into a DateTime for today.
  /// Returns null only if parsing completely fails.
  DateTime? _parseTaskTime(String timeStr) {
    final cleaned = timeStr.trim().toUpperCase();
    final isPm = cleaned.contains('PM');
    final numeric = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = numeric.split(':');

    int hour;
    int minute;
    if (parts.length >= 2) {
      hour = int.tryParse(parts[0]) ?? 0;
      minute = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      // Handle "7" or "7AM" (no colon — treat as hour, :00 minutes)
      hour = int.tryParse(parts[0]) ?? 0;
      minute = 0;
    } else {
      return null;
    }

    // Convert to 24-hour format
    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour.clamp(0, 23), minute);
  }

  static const _windDownNotificationId = 999001;
}

