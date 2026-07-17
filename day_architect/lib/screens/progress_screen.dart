import 'package:flutter/material.dart';
import '../models/sleep_log.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/page_transitions.dart';
import 'today_screen.dart';
import 'focus_screen.dart';
import 'winddown_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final int _navIndex = 3;
  bool _loading = true;

  int _streak = 0;
  int _totalFocusMinutes = 0;
  Map<String, int> _focusByDay = {};
  Set<String> _completedTaskDates = {};
  List<SleepLog> _sleepLogs = [];
  double _avgSleepMinutes = 0;
  Map<int, double> _avgFocusByDayOfWeek = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = DatabaseHelper();
      final streak = await db.getStreak();
      final focusByDay = await db.getFocusMinutesByDay();
      final completedDates = await db.getCompletedTaskDates(days: 7);
      final sleepLogs = await db.getSleepLogs(days: 7);
      final avgSleep = await db.getAverageSleepMinutes(days: 7);
      final avgFocusByDOW = await db.getAverageFocusMinutesByDayOfWeek();

      // Calculate total focus minutes this week
      int totalFocus = 0;
      for (final v in focusByDay.values) {
        totalFocus += v;
      }

      if (mounted) {
        setState(() {
          _streak = streak;
          _totalFocusMinutes = totalFocus;
          _focusByDay = focusByDay;
          _completedTaskDates = completedDates;
          _sleepLogs = sleepLogs;
          _avgSleepMinutes = avgSleep;
          _avgFocusByDayOfWeek = avgFocusByDOW;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ProgressScreen: Failed to load data – $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load progress data'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        pushReplacementPage(context, const TodayScreen());
        break;
      case 1:
        pushReplacementPage(context, const FocusScreen());
        break;
      case 2:
        pushReplacementPage(context, const WindDownScreen());
        break;
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _formatDoubleMinutes(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// Generate the last 7 days as strings (most recent last)
  List<DateTime> _last7Days() {
    final today = DateTime.now();
    return List.generate(7, (i) => DateTime(today.year, today.month, today.day - (6 - i)));
  }

  /// Get the day-of-week labels (short)
  String _dowShort(int weekday) {
    const labels = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[weekday];
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _last7Days();
    // Find max focus minutes for scaling bars
    final maxFocus = _focusByDay.values.fold<int>(
      1, (max, v) => v > max ? v : max);

    // Sleep dot data for the last 7 days
    final sleepDots = _sleepLogs.take(7).toList();

    // Find peak day insight
    String peakDay = 'Thursday';
    double peakAvg = 0;
    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (final entry in _avgFocusByDayOfWeek.entries) {
      if (entry.value > peakAvg) {
        peakAvg = entry.value;
        peakDay = dayNames[entry.key];
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? Center(
                        child: Semantics(
                          label: 'Loading progress data',
                          child: const CircularProgressIndicator(),
                        ),
                      )
                    : _streak == 0 &&
                            _totalFocusMinutes == 0 &&
                            _sleepLogs.isEmpty
                        ? Center(
                            child: Semantics(
                              label: 'No progress data yet',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.1),
                                    ),
                                    child: Icon(Icons.insights_rounded,
                                        size: 36,
                                        color: AppColors.textMuted
                                            .withValues(alpha: 0.5)),
                                  ),
                                  const SizedBox(height: 14),
                                  Text('Nothing tracked yet',
                                      style: AppTextStyles.body(
                                          size: 14,
                                          weight: FontWeight.w600,
                                          color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Complete tasks and focus sessions to see your progress',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.body(
                                        size: 12,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('This week', style: AppTextStyles.eyebrow()),
                            const SizedBox(height: 2),
                            Text('Your Progress',
                                style: AppTextStyles.heading(size: 24)),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                _statMini('$_streak 🔥', 'Day streak',
                                    AppColors.accent),
                                const SizedBox(width: 10),
                                _statMini(
                                    _formatMinutes(_totalFocusMinutes),
                                    'Focus this week',
                                    AppColors.sage),
                                const SizedBox(width: 10),
                                _statMini(
                                    _formatDoubleMinutes(_avgSleepMinutes),
                                    'Avg sleep',
                                    AppColors.textPrimary),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Streak calendar card
                            _sectionCard(
                              title: 'STREAK CALENDAR',
                              trailing: '$_streak-day streak 🔥',
                              trailingColor: AppColors.accent,
                              child: Row(
                                children: List.generate(7, (i) {
                                  final dateStr = DatabaseHelper.formatDate(weekDays[i]);
                                  final isToday = i == 6;
                                  final isDone = _completedTaskDates.contains(dateStr);
                                  return Expanded(
                                    child: Column(
                                      children: [
                                        Text(_dowShort(weekDays[i].weekday),
                                            style: AppTextStyles.body(
                                                size: 10,
                                                weight: FontWeight.w600,
                                                color: AppColors.textMuted)),
                                        const SizedBox(height: 5),
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: isDone
                                                ? AppGradients.accentButton
                                                : null,
                                            color: isDone
                                                ? null
                                                : (isToday
                                                    ? AppColors.accent
                                                        .withValues(alpha: 0.18)
                                                    : Colors.white
                                                        .withValues(alpha: 0.06)),
                                            border: isToday
                                                ? Border.all(
                                                    color: AppColors.accent,
                                                    width: 1.5)
                                                : null,
                                          ),
                                          child: Center(
                                            child: isDone
                                                ? const Icon(Icons.check,
                                                    size: 13,
                                                    color: AppColors.bgMid)
                                                : Text(isToday ? '·' : '',
                                                    style: AppTextStyles.body(
                                                        size: 11,
                                                        weight: FontWeight.w700,
                                                        color:
                                                            AppColors.accent)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${weekDays[i].day}',
                                            style: AppTextStyles.body(
                                                size: 10,
                                                color: AppColors.textMuted)),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Focus hours card
                            _sectionCard(
                              title: 'FOCUS HOURS',
                              trailing: '${_formatMinutes(_totalFocusMinutes)} total',
                              trailingColor: AppColors.accent,
                              child: SizedBox(
                                height: 90,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(7, (i) {
                                    final dateStr =
                                        DatabaseHelper.formatDate(weekDays[i]);
                                    final focusMin =
                                        _focusByDay[dateStr] ?? 0;
                                    final heightFrac = maxFocus > 0
                                        ? focusMin / maxFocus
                                        : 0.0;
                                    final isPeak = focusMin == maxFocus && focusMin > 0;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: FractionallySizedBox(
                                                  heightFactor: heightFrac,
                                                  widthFactor: 1,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: isPeak
                                                          ? null
                                                          : AppColors.accent
                                                              .withValues(
                                                                  alpha: 0.5),
                                                      gradient: isPeak
                                                          ? AppGradients
                                                              .accentButton
                                                          : null,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              weekDays[i].weekday == 1
                                                  ? 'M'
                                                  : weekDays[i].weekday == 2
                                                      ? 'T'
                                                      : weekDays[i].weekday == 3
                                                          ? 'W'
                                                          : weekDays[i].weekday ==
                                                                  4
                                                              ? 'T'
                                                              : weekDays[i]
                                                                          .weekday ==
                                                                      5
                                                                  ? 'F'
                                                                  : weekDays[i].weekday ==
                                                                          6
                                                                      ? 'S'
                                                                      : 'S',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.body(
                                                  size: 9.5,
                                                  weight: FontWeight.w600,
                                                  color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Sleep consistency card
                            _sectionCard(
                              title: 'SLEEP CONSISTENCY',
                              trailing: sleepDots.length >= 7 &&
                                      _sleepLogs.length >= 2
                                  ? 'Improving ↑'
                                  : 'Track to see trends',
                              trailingColor: AppColors.sage,
                              child: Row(
                                children: [
                                  ...List.generate(6, (i) {
                                    if (i < sleepDots.length) {
                                      final log = sleepDots[i];
                                      final frac = log.fractionOfGoal.clamp(0.0, 1.0);
                                      final color = frac >= 0.9
                                          ? AppColors.sage
                                          : AppColors.plum.withValues(alpha: 0.5 + frac * 0.5);
                                      return _sleepDot(log.formattedDuration, color);
                                    } else {
                                      return _sleepDot('--',
                                          Colors.white.withValues(alpha: 0.1));
                                    }
                                  }),
                                  _sleepDot('Goal',
                                      AppColors.accent.withValues(alpha: 0.3),
                                      dashed: true),
                                ],
                              ),
                            ),

                            if (peakAvg > 0) ...[
                              const SizedBox(height: 14),

                              // Insight card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.accent.withValues(alpha: 0.14),
                                      AppColors.accentSoft
                                          .withValues(alpha: 0.08)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('💡',
                                        style: TextStyle(fontSize: 22)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$peakDay is your peak day',
                                            style: AppTextStyles.body(
                                                size: 13,
                                                weight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'You average ${_formatDoubleMinutes(peakAvg)} of focus on $peakDay — keep that momentum going!',
                                            style: AppTextStyles.body(
                                                size: 12,
                                                color: AppColors
                                                    .textAmberLight),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  Widget _statMini(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.body(
                    size: 20, weight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.body(
                    size: 10.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
      {required String title,
      required String trailing,
      required Color trailingColor,
      required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.label()),
              Text(trailing,
                  style: AppTextStyles.body(
                      size: 13, weight: FontWeight.w700, color: trailingColor)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sleepDot(String label, Color color, {bool dashed = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: dashed
                    ? Border.all(color: AppColors.accent, width: 1)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.body(
                    size: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
