import 'package:flutter/material.dart';
import '../models/sleep_log.dart';
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

  // Stats
  int _streakDays = 0;
  int _totalFocusMinutes = 0;
  double _avgSleepMinutes = 0;

  // Streak calendar data
  List<String> _dayLabels = [];
  List<String> _dayNumbers = [];
  List<bool> _daysDone = [];

  // Focus hours
  Map<String, int> _focusByDay = {};
  final List<String> _focusLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Sleep consistency
  List<SleepLog> _sleepLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final today = DateTime.now();

    // Build week days
    final weekStart = DateTime(today.year, today.month, today.day - today.weekday + 1);
    const weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    final labels = <String>[];
    final numbers = <String>[];
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      labels.add(weekdayShort[i]);
      numbers.add('${day.day}');
    }

    // Focus minutes for this week
    final focusByDay = await db.getFocusMinutesByDay();
    final totalFocus = focusByDay.values.fold(0, (sum, v) => sum + v);

    // Sleep logs (last 7 days)
    final sleepLogs = await db.getSleepLogs(days: 7);
    final avgSleep = await db.getAverageSleepMinutes(days: 7);

    // Determine "done" days — any day with completed tasks or focus sessions
    final daysDone = <bool>[];
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dateStr = DatabaseHelper.formatDate(day);
      final hasFocus = focusByDay.containsKey(dateStr) && (focusByDay[dateStr] ?? 0) > 0;
      final hasSleep = sleepLogs.any((l) => l.date == dateStr);
      daysDone.add(hasFocus || hasSleep);
    }

    // Real streak from completed tasks
    final streak = await db.getStreak();

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
        _loading = false;
      });
    }
  }

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
                      Text('Your Progress', style: AppTextStyles.heading(size: 24)),
                      const SizedBox(height: 16),

                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: AppColors.accent),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            _statMini('$_streakDays 🔥', 'Day streak', AppColors.accent),
                            const SizedBox(width: 10),
                            _statMini(_formattedFocus, 'Focus this week', AppColors.sage),
                            const SizedBox(width: 10),
                            _statMini(_formattedAvgSleep, 'Avg sleep', AppColors.textPrimary),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Streak calendar card
                        _sectionCard(
                          title: 'STREAK CALENDAR',
                          trailing: '$_streakDays-day streak 🔥',
                          trailingColor: AppColors.accent,
                          child: Row(
                            children: List.generate(7, (i) {
                              final isToday = i == _todayWeekIndex;
                              return Expanded(
                                child: Column(
                                  children: [
                                    Text(_dayLabels[i], style: AppTextStyles.body(size: 10, weight: FontWeight.w600, color: AppColors.textMuted)),
                                    const SizedBox(height: 5),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: _daysDone[i] ? AppGradients.accentButton : null,
                                        color: _daysDone[i] ? null : (isToday ? AppColors.accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06)),
                                        border: isToday ? Border.all(color: AppColors.accent, width: 1.5) : null,
                                      ),
                                      child: Center(
                                        child: _daysDone[i]
                                            ? const Icon(Icons.check, size: 13, color: AppColors.bgMid)
                                            : Text(isToday ? '·' : '', style: AppTextStyles.body(size: 11, weight: FontWeight.w700, color: AppColors.accent)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_dayNumbers[i], style: AppTextStyles.body(size: 10, color: AppColors.textMuted)),
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
                          trailing: _formattedFocus,
                          trailingColor: AppColors.accent,
                          child: SizedBox(
                            height: 90,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) {
                                final d = _weekStart.add(Duration(days: i));
                                final dateStr = DatabaseHelper.formatDate(d);
                                final minutes = _focusByDay[dateStr] ?? 0;
                                final maxMin = _focusByDay.values.fold<int>(0, (max, v) => v > max ? v : max);
                                final heightFactor = maxMin > 0 ? (minutes / maxMin).clamp(0.1, 1.0) : 0.1;
                                final isPeak = maxMin > 0 && minutes == maxMin && maxMin > 0;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: FractionallySizedBox(
                                              heightFactor: heightFactor,
                                              widthFactor: 1,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isPeak ? null : AppColors.accent.withValues(alpha: 0.5),
                                                  gradient: isPeak ? AppGradients.accentButton : null,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(_focusLabels[i], textAlign: TextAlign.center, style: AppTextStyles.body(size: 9.5, weight: FontWeight.w600, color: AppColors.textMuted)),
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
                          trailing: _sleepLogs.isNotEmpty ? 'Improving ↑' : 'No data yet',
                          trailingColor: AppColors.sage,
                          child: Row(
                            children: _sleepLogs.reversed.take(7).toList().asMap().entries.map((entry) {
                              final log = entry.value;
                              final isGoal = log.sleepDurationMinutes >= log.goalDurationMinutes;
                              return _sleepDot(
                                log.formattedDuration,
                                isGoal ? AppColors.sage : AppColors.plum.withValues(alpha: 0.6),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Insight card
                        if (_focusByDay.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.accent.withValues(alpha: 0.14), AppColors.accentSoft.withValues(alpha: 0.08)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Track your consistency', style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Your $_streakDays-day streak shows great momentum. Keep scheduling your focus blocks to build stronger habits!',
                                        style: AppTextStyles.body(size: 12, color: AppColors.textAmberLight),
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
              AppBottomNav(activeIndex: 3, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }

  int get _todayWeekIndex {
    final today = DateTime.now();
    return today.weekday - 1;
  }

  DateTime get _weekStart {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day - today.weekday + 1);
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TodayScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        break;
      case 2:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WindDownScreen()));
        break;
    }
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
            Text(value, style: AppTextStyles.body(size: 20, weight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.body(size: 10.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required String trailing, required Color trailingColor, required Widget child}) {
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
              Text(trailing, style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: trailingColor)),
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
                border: dashed ? Border.all(color: AppColors.accent, width: 1) : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.body(size: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
