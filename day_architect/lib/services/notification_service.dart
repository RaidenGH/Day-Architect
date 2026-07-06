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

  static const _windDownNotificationId = 999001;
}

