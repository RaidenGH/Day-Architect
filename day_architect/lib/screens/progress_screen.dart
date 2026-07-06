import 'package:flutter/material.dart';
import '../models/sleep_log.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'today_screen.dart';
import 'focus_screen.dart';
import 'winddown_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _error;

  // ── Stats ──
  int _streakDays = 0;
  int _totalFocusMinutes = 0;
  double _avgSleepMinutes = 0;

  // ── Streak calendar ──
  List<String> _dayLabels = [];
  List<String> _dayNumbers = [];
  List<bool> _daysDone = [];

  // ── Focus hours ──
  Map<String, int> _focusByDay = {};
  static const _focusLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // ── Sleep consistency ──
  List<SleepLog> _sleepLogs = [];

  // ── Insight card ──
  String _peakFocusDay = '';
  String _peakFocusAvg = '';

  static const _weekdayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper();
      final today = DateTime.now();

      // ── Week range ──
      final weekStart =
          DateTime(today.year, today.month, today.day - today.weekday + 1);
      const weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

      // ── Focus minutes for this week ──
      final focusByDay = await db.getFocusMinutesByDay();
      final totalFocus = focusByDay.values.fold(0, (sum, v) => sum + v);

      // ── Sleep logs (last 7 days) ──
      final sleepLogs = await db.getSleepLogs(days: 7);
      final avgSleep = await db.getAverageSleepMinutes(days: 7);

      // ── Tasks for this week (for calendar accuracy) ──
      final tasksByDate = <String, List<Task>>{};
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dateStr = DatabaseHelper.formatDate(day);
        tasksByDate[dateStr] = await db.getTasks(date: dateStr);
      }

      // ── Build calendar ──
      final labels = <String>[];
      final numbers = <String>[];
      final daysDone = <bool>[];
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dateStr = DatabaseHelper.formatDate(day);
        labels.add(weekdayShort[i]);
        numbers.add('${day.day}');

        // A day is "done" if any task is completed, OR there's a focus session
        final dayTasks = tasksByDate[dateStr] ?? [];
        final hasCompletedTask = dayTasks.any((t) => t.done);
        final hasFocus =
            (focusByDay[dateStr] ?? 0) > 0;
        daysDone.add(hasCompletedTask || hasFocus);
      }

      // ── Streak from completed tasks ──
      final streak = await db.getStreak();

      // ── Insight: highest average focus day of week ──
      final avgByDow = await db.getAverageFocusMinutesByDayOfWeek();
      String peakDay = '';
      String peakAvg = '';
      if (avgByDow.isNotEmpty) {
        final bestEntry = avgByDow.entries.reduce(
            (a, b) => a.value >= b.value ? a : b);
        peakDay = _weekdayNames[bestEntry.key] ?? '';
        final avgMins = bestEntry.value.round();
        final h = avgMins ~/ 60;
        final m = avgMins % 60;
        peakAvg = h > 0 ? '${h}h ${m}m' : '${m}m';
      }

      if (mounted) {
        setState(() {
          _dayLabels = labels;
          _dayNumbers = numbers;
          _daysDone = daysDone;
          _focusByDay = focusByDay;
          _totalFocusMinutes = totalFocus;
          _sleepLogs = sleepLogs;
          _avgSleepMinutes = avgSleep;
          _streakDays = streak;
          _peakFocusDay = peakDay;
          _peakFocusAvg = peakAvg;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Could not load progress data.';
        _loading = false;
      });
    }
  }

  // ── Formatters ──

  String get _formattedFocus {
    final hours = _totalFocusMinutes ~/ 60;
    final minutes = _totalFocusMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String get _formattedAvgSleep {
    final hours = _avgSleepMinutes ~/ 60;
    final minutes = _avgSleepMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes.toInt()}m';
    if (hours > 0) return '${hours}h';
    return '${minutes.toInt()}m';
  }

  // ── Helpers ──

  int get _todayWeekIndex => DateTime.now().weekday - 1;

  DateTime get _weekStart {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day - today.weekday + 1);
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const TodayScreen()));
        break;
      case 1:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const FocusScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, fadeSlideRoute(const WindDownScreen()));
        break;
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This week', style: AppTextStyles.eyebrow()),
                      const SizedBox(height: 2),
                      Text('Your Progress',
                          style: AppTextStyles.heading(size: 24)),
                      const SizedBox(height: 16),

                      if (_loading)
                        const LoadingIndicator()
                      else if (_error != null)
                        ErrorBanner(message: _error!, onRetry: _loadData)
                      else ...[
                        // ── Top stats row ──
                        Row(
                          children: [
                            _statMini('$_streakDays 🔥', 'Day streak',
                                AppColors.accent),
                            const SizedBox(width: 10),
                            _statMini(_formattedFocus, 'Focus this week',
                                AppColors.sage),
                            const SizedBox(width: 10),
                            _statMini(_formattedAvgSleep, 'Avg sleep',
                                AppColors.textPrimary),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Streak calendar card ──
                        _buildStreakCalendar(),

                        const SizedBox(height: 14),

                        // ── Focus hours card ──
                        _buildFocusHoursCard(),

                        const SizedBox(height: 14),

                        // ── Sleep consistency card ──
                        _buildSleepCard(),

                        const SizedBox(height: 14),

                        // ── Insight card ──
                        _buildInsightCard(),
                      ],
                    ],
                  ),
                ),
              ),
              AppBottomNav(activeIndex: 3, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }

  // ── Streak Calendar ──

  Widget _buildStreakCalendar() {
    return _sectionCard(
      title: 'STREAK CALENDAR',
      trailing: '$_streakDays-day streak 🔥',
      trailingColor: AppColors.accent,
      child: Row(
        children: List.generate(7, (i) {
          final isToday = i == _todayWeekIndex;
          return Expanded(
            child: Column(
              children: [
                Text(_dayLabels[i],
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
                    gradient:
                        _daysDone[i] ? AppGradients.accentButton : null,
                    color: _daysDone[i]
                        ? null
                        : (isToday
                            ? AppColors.accent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06)),
                    border: isToday
                        ? Border.all(color: AppColors.accent, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: _daysDone[i]
                        ? const Icon(Icons.check,
                            size: 13, color: AppColors.bgMid)
                        : Text(isToday ? '·' : '',
                            style: AppTextStyles.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: AppColors.accent)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_dayNumbers[i],
                    style: AppTextStyles.body(
                        size: 10, color: AppColors.textMuted)),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Focus Hours ──

  Widget _buildFocusHoursCard() {
    final maxMin = _focusByDay.values.fold<int>(
        0, (max, v) => v > max ? v : max);

    String subtitle;
    if (_peakFocusDay.isNotEmpty && _focusByDay.isNotEmpty) {
      subtitle = '$_formattedFocus this week · $_peakFocusDay peak';
    } else {
      subtitle = _formattedFocus;
    }

    return _sectionCard(
      title: 'FOCUS HOURS',
      trailing: subtitle,
      trailingColor: AppColors.accent,
      child: SizedBox(
        height: 90,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final d = _weekStart.add(Duration(days: i));
            final dateStr = DatabaseHelper.formatDate(d);
            final minutes = _focusByDay[dateStr] ?? 0;
            final heightFactor = maxMin > 0
                ? (minutes / maxMin).clamp(0.1, 1.0)
                : 0.1;
            final isPeak =
                maxMin > 0 && minutes == maxMin && maxMin > 0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Minute label above tallest bars
                    if (isPeak && minutes > 0)
                      Text(
                        '${minutes}m',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                            size: 8.5,
                            weight: FontWeight.w600,
                            color: AppColors.accent),
                      )
                    else
                      const Spacer(),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isPeak
                                  ? null
                                  : AppColors.accent
                                      .withValues(alpha: 0.5),
                              gradient: isPeak
                                  ? AppGradients.accentButton
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _focusLabels[i],
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                          size: 9.5,
                          weight: FontWeight.w600,
                          color: i == _todayWeekIndex
                              ? AppColors.accent
                              : AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Sleep Consistency ──

  Widget _buildSleepCard() {
    final reversed = _sleepLogs.reversed.take(7).toList();
    final maxMinutes = reversed.fold<int>(
        0, (max, l) => l.sleepDurationMinutes > max ? l.sleepDurationMinutes : max);

    return _sectionCard(
      title: 'SLEEP CONSISTENCY',
      trailing: _sleepLogs.isNotEmpty ? 'Improving ↑' : 'No data yet',
      trailingColor: AppColors.sage,
      child: SizedBox(
        height: 90,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            if (i >= reversed.length) return const Expanded(child: SizedBox());
            final log = reversed[i];
            final barHeight = maxMinutes > 0
                ? (log.sleepDurationMinutes / maxMinutes).clamp(0.15, 1.0)
                : 0.15;
            final isGoal = log.sleepDurationMinutes >= log.goalDurationMinutes;

            // Determine which week day this log maps to
            final dateParts = log.date.split('-');
            final logDate = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]));
            final dayLabel = _focusLabels[logDate.weekday - 1];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isGoal)
                      Text(
                        log.formattedDuration,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                            size: 8,
                            weight: FontWeight.w600,
                            color: AppColors.sage),
                      )
                    else
                      const Spacer(),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: barHeight,
                          widthFactor: 0.7,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isGoal
                                  ? AppColors.sage.withValues(alpha: 0.7)
                                  : AppColors.plum.withValues(alpha: 0.5),
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                            foregroundDecoration: isGoal
                                ? BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                          color: AppColors.sage, width: 2),
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6)),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayLabel,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                          size: 9,
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
    );
  }

  // ── Insight Card ──

  Widget _buildInsightCard() {
    // Determine insight message
    String emoji;
    String title;
    String body;

    if (_peakFocusDay.isNotEmpty && _peakFocusAvg.isNotEmpty) {
      emoji = '💡';
      title = 'Peak focus day: $_peakFocusDay';
      body =
          'You average $_peakFocusAvg of focused time on $_peakFocusDay — '
          'your most productive day. Try scheduling your hardest tasks then!';
    } else if (_streakDays > 0) {
      emoji = '🔥';
      title = '$_streakDays-day streak';
      body =
          'Your streak shows great momentum. Keep completing tasks daily to '
          'build an unbreakable habit!';
    } else {
      emoji = '🌱';
      title = 'Start your streak';
      body =
          'Complete a task today to begin your streak. Consistency is the '
          'secret to making real progress.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.14),
            AppColors.accentSoft.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body(
                        size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTextStyles.body(
                      size: 12, color: AppColors.textAmberLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ──

  Widget _statMini(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
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

  Widget _sectionCard({
    required String title,
    required String trailing,
    required Color trailingColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                      size: 13,
                      weight: FontWeight.w700,
                      color: trailingColor)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

