import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sleep_log.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'today_screen.dart';
import 'focus_screen.dart';
import 'progress_screen.dart';

class WindDownScreen extends StatefulWidget {
  const WindDownScreen({super.key});

  @override
  State<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends State<WindDownScreen> {
  int _navIndex = 2;

  // ── Toggle states (persisted) ──
  bool _dnd = true;
  bool _dimApps = true;
  bool _alarm = false;

  // ── Sleep data ──
  SleepLog? _lastNight;
  int _goalMinutes = 450;
  double _avgMinutes = 0;
  bool _loading = true;
  String? _error;

  // ── Bedtime calculation ──
  Task? _earliestTomorrow;
  DateTime? _bedtimeTime;
  int _minutesUntilBedtime = 0;
  String _earliestClassLabel = '';
  bool _windDownStarted = false;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Keep the countdown fresh every 30 seconds
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshCountdown();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _refreshCountdown() {
    if (_earliestTomorrow == null || _windDownStarted) return;
    final info = _calculateBedtime(_earliestTomorrow, _goalMinutes);
    setState(() {
      _minutesUntilBedtime = info.$1;
      _bedtimeTime = info.$2;
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper();

      // Load sleep data
      final logs = await db.getSleepLogs(days: 7);
      final lastNight = logs.isNotEmpty ? logs.first : null;
      final goalMinutes = lastNight?.goalDurationMinutes ?? 450;
      final avg = logs.isNotEmpty
          ? logs.fold<int>(0, (sum, l) => sum + l.sleepDurationMinutes) /
              logs.length
          : 0.0;

      // Load persisted toggle states
      final prefs = await db.getAllPreferences();
      final dnd = prefs['wind_down_dnd'] ?? 'true';
      final dimApps = prefs['wind_down_dim_apps'] ?? 'true';
      final alarm = prefs['wind_down_alarm'] ?? 'false';
      final windDownStarted = prefs['wind_down_started'] == 'true';

      // Calculate bedtime from tomorrow's earliest class
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = DatabaseHelper.formatDate(tomorrow);
      final tomorrowTasks = await db.getTasks(date: tomorrowStr);

      Task? earliest;
      if (tomorrowTasks.isNotEmpty) {
        final sorted = List<Task>.from(tomorrowTasks)
          ..sort((a, b) =>
              _parseTimeOfDay(a.time).compareTo(_parseTimeOfDay(b.time)));
        earliest = sorted.first;
      }

      final bedtimeInfo = _calculateBedtime(earliest, goalMinutes);

      if (mounted) {
        setState(() {
          _lastNight = lastNight;
          _goalMinutes = goalMinutes;
          _avgMinutes = avg;
          _dnd = dnd == 'true';
          _dimApps = dimApps == 'true';
          _alarm = alarm == 'true';
          _windDownStarted = windDownStarted;
          _earliestTomorrow = earliest;
          _minutesUntilBedtime = bedtimeInfo.$1;
          _bedtimeTime = bedtimeInfo.$2;
          _earliestClassLabel = earliest != null
              ? '${earliest.time} ${_amPm(earliest.time)}'
              : '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Could not load wind-down data.';
        _loading = false;
      });
    }
  }

  /// Parse a time string like "7:30" into total minutes since midnight (24h).
  /// Convention: hour 1–5 → PM, hour 6–11 → AM, hour 12 → PM.
  int _parseTimeOfDay(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    int h24;
    if (hour == 12) {
      h24 = 12; // noon
    } else if (hour >= 1 && hour <= 5) {
      h24 = hour + 12; // PM
    } else {
      h24 = hour; // AM (6–11)
    }
    return h24 * 60 + minute;
  }

  String _amPm(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    if (hour == 12) return 'PM';
    if (hour >= 1 && hour <= 5) return 'PM';
    return 'AM';
  }

  /// Calculate bedtime on tonight's timeline based on the earliest class and goal.
  /// Returns (minutesUntilBedtime, bedtimeDateTime).
  (int, DateTime) _calculateBedtime(Task? earliest, int goalMinutes) {
    if (earliest == null) {
      // Default wind-down at 9:00 PM if no classes tomorrow
      final now = DateTime.now();
      final bedtime =
          DateTime(now.year, now.month, now.day, 21, 0);
      final diff = bedtime.difference(now).inMinutes;
      return (diff < 0 ? 0 : diff, bedtime);
    }

    final parts = earliest.time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    int classHour24;
    if (hour == 12) {
      classHour24 = 12;
    } else if (hour >= 1 && hour <= 5) {
      classHour24 = hour + 12;
    } else {
      classHour24 = hour;
    }

    // Class is tomorrow; bedtime is tonight
    final now = DateTime.now();
    final classTime = DateTime(
        now.year, now.month, now.day + 1, classHour24, minute);

    // Bedtime = class time − goal sleep duration
    final bedtime = classTime.subtract(Duration(minutes: goalMinutes));

    final diff = bedtime.difference(now).inMinutes;
    return (diff < 0 ? 0 : diff, bedtime);
  }

  String _formatBedtimeTime(DateTime? bedtime) {
    if (bedtime == null) return '--:--';
    final hour = bedtime.hour;
    final minute = bedtime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${h12}:${minute.toString().padLeft(2, '0')} $period';
  }

  // ── Persist toggles ──

  Future<void> _setDnd(bool v) async {
    setState(() => _dnd = v);
    await DatabaseHelper().setPreference('wind_down_dnd', v.toString());
  }

  Future<void> _setDimApps(bool v) async {
    setState(() => _dimApps = v);
    await DatabaseHelper().setPreference('wind_down_dim_apps', v.toString());
  }

  Future<void> _setAlarm(bool v) async {
    setState(() => _alarm = v);
    await DatabaseHelper().setPreference('wind_down_alarm', v.toString());
  }

  // ── Actions ──

  Future<void> _startWindDown() async {
    if (_bedtimeTime == null) return;

    final db = DatabaseHelper();
    await db.setPreference('wind_down_started', 'true');

    final label = _earliestClassLabel.isNotEmpty
        ? _earliestClassLabel
        : 'tomorrow';

    await NotificationService().scheduleWindDown(
      scheduledDate: _bedtimeTime!,
      minutesUntilBedtime: _minutesUntilBedtime,
      earliestClassLabel: label,
    );

    if (mounted) {
      setState(() => _windDownStarted = true);
    }
  }

  Future<void> _cancelWindDown() async {
    final db = DatabaseHelper();
    await db.setPreference('wind_down_started', 'false');
    await NotificationService().cancelWindDown();

    if (mounted) {
      setState(() => _windDownStarted = false);
    }
  }

  // ── Navigation ──

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const TodayScreen()));
        break;
      case 1:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const FocusScreen()));
        break;
      case 3:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const ProgressScreen()));
        break;
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: [Color(0xFF12103A), Color(0xFF1A1535), AppColors.bgMid],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wind Down', style: AppTextStyles.eyebrow()),
                      const SizedBox(height: 16),

                      // Moon
                      Center(
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.3, -0.3),
                              colors: [Color(0xFF4A4585), Color(0xFF24225A)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF958CDB)
                                    .withValues(alpha: 0.28),
                                blurRadius: 60,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bedtime countdown header
                      Text(
                        _windDownStarted
                            ? '🌙 Wind-down mode active'
                            : _earliestTomorrow != null
                                ? 'Bedtime in $_minutesUntilBedtime min'
                                : 'Set your schedule',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading(size: 28),
                      ),
                      const SizedBox(height: 8),
                      if (_earliestTomorrow != null)
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: AppTextStyles.body(
                                size: 12.5, color: AppColors.textSecondary),
                            children: [
                              TextSpan(
                                text: _windDownStarted
                                    ? 'Class at $_earliestClassLabel tomorrow. '
                                    : 'Bedtime at ${_formatBedtimeTime(_bedtimeTime)} · '
                                        'Class at $_earliestClassLabel tomorrow.\n',
                              ),
                              TextSpan(
                                text: _formatMinutes(_goalMinutes),
                                style: AppTextStyles.body(
                                    size: 12.5,
                                    weight: FontWeight.w600,
                                    color: AppColors.accent),
                              ),
                              const TextSpan(text: ' of sleep tonight'),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Add tomorrow\'s classes to get a bedtime recommendation.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                              size: 12.5, color: AppColors.textSecondary),
                        ),

                      const SizedBox(height: 22),

                      _toggleRow(
                          'Do Not Disturb',
                          'Silence all notifications',
                          _dnd,
                          _setDnd),
                      _toggleRow('Dim Social Apps',
                          'Grayscale + slow response', _dimApps, _setDimApps),
                      if (_bedtimeTime != null)
                        _toggleRow(
                          'Alarm Set',
                          '${_formatBedtimeTime(_bedtimeTime!.add(const Duration(hours: 8)))} '
                              '— ${8}h from bedtime',
                          _alarm,
                          _setAlarm,
                        )
                      else
                        _toggleRow('Alarm Set', '6:30 AM — 7h 58m from now',
                            _alarm, _setAlarm),

                      const SizedBox(height: 12),
                      Text('SLEEP COMPARISON', style: AppTextStyles.label()),
                      const SizedBox(height: 12),

                      if (_loading)
                        const LoadingIndicator()
                      else if (_error != null)
                        ErrorBanner(message: _error!, onRetry: _loadAll)
                      else
                        Row(
                          children: [
                            _sleepBar(
                              _lastNight?.formattedDuration ?? '0h',
                              'Last night',
                              _goalMinutes > 0
                                  ? (_lastNight?.fractionOfGoal ?? 0.0)
                                  : 0.0,
                              AppColors.plum,
                            ),
                            const SizedBox(width: 14),
                            _sleepBar(
                              _formatMinutes(_goalMinutes),
                              "Tonight's goal",
                              1.0,
                              null,
                              isGoal: true,
                            ),
                            const SizedBox(width: 14),
                            _sleepBar(
                              _formatAvg(_avgMinutes),
                              'Avg (7 days)',
                              _goalMinutes > 0
                                  ? (_avgMinutes / _goalMinutes).clamp(0.0, 1.0)
                                  : 0.0,
                              AppColors.textMuted,
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),
                      if (_windDownStarted)
                        GhostButton(
                            label: 'Cancel wind-down', onTap: _cancelWindDown)
                      else
                        PrimaryButton(
                            label: 'Start wind-down now',
                            onTap: _startWindDown),
                    ],
                  ),
                ),
              ),
              AppBottomNav(activeIndex: _navIndex, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  String _formatAvg(double minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m.toInt()}m';
    if (h > 0) return '${h}h';
    return '${m.toInt()}m';
  }

  Widget _toggleRow(
      String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body(
                        size: 13.5, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(desc,
                    style: AppTextStyles.body(
                        size: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }

  Widget _sleepBar(String value, String label, double heightFrac,
      Color? color,
      {bool isGoal = false}) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFrac.clamp(0.05, 1.0),
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    color: color,
                    gradient: isGoal ? AppGradients.accentButton : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                  size: 10.5,
                  color: isGoal ? AppColors.sage : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
