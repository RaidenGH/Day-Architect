import 'package:flutter/material.dart';
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
  final int _navIndex = 3;

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const TodayScreen()));
        break;
      case 1:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const WindDownScreen()));
        break;
    }
  }

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _dayNums = ['16', '17', '18', '19', '20', '21', '22'];
  static const _dayDone = [true, true, true, true, true, true, false];

  static const _focusHeights = [0.60, 0.80, 0.40, 1.0, 0.70, 0.55, 0.25];
  static const _focusLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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

                      Row(
                        children: [
                          _statMini('12 🔥', 'Day streak', AppColors.accent),
                          const SizedBox(width: 10),
                          _statMini(
                              '4h 20m', 'Focus this week', AppColors.sage),
                          const SizedBox(width: 10),
                          _statMini(
                              '6h 4m', 'Avg sleep', AppColors.textPrimary),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Streak calendar card
                      _sectionCard(
                        title: 'STREAK CALENDAR',
                        trailing: '12-day streak 🔥',
                        trailingColor: AppColors.accent,
                        child: Row(
                          children: List.generate(7, (i) {
                            final isToday = i == 6;
                            return Expanded(
                              child: Column(
                                children: [
                                  Text(_days[i],
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
                                      gradient: _dayDone[i]
                                          ? AppGradients.accentButton
                                          : null,
                                      color: _dayDone[i]
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
                                      child: _dayDone[i]
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
                                  Text(_dayNums[i],
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
                        trailing: '4h 20m total',
                        trailingColor: AppColors.accent,
                        child: SizedBox(
                          height: 90,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final isPeak = i == 3;
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: _focusHeights[i],
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
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(_focusLabels[i],
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.body(
                                              size: 9.5,
                                              weight: FontWeight.w600,
                                              color: AppColors.textMuted)),
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
                        trailing: 'Improving ↑',
                        trailingColor: AppColors.sage,
                        child: Row(
                          children: [
                            _sleepDot('5h 40m',
                                AppColors.plum.withValues(alpha: 0.6)),
                            _sleepDot('7h 10m', AppColors.sage),
                            _sleepDot('6h 00m',
                                AppColors.plum.withValues(alpha: 0.7)),
                            _sleepDot('7h 20m', AppColors.sage),
                            _sleepDot('6h 45m',
                                AppColors.sage.withValues(alpha: 0.8)),
                            _sleepDot('7h 30m', AppColors.sage),
                            _sleepDot(
                                'Goal', AppColors.accent.withValues(alpha: 0.3),
                                dashed: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Insight card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.14),
                              AppColors.accentSoft.withValues(alpha: 0.08)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.25)),
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
                                  Text('Thursday is your peak day',
                                      style: AppTextStyles.body(
                                          size: 13, weight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You average 72 min of focus on Thursdays — 2× your Monday average. Try scheduling harder tasks on Thursdays.',
                                    style: AppTextStyles.body(
                                        size: 12,
                                        color: AppColors.textAmberLight),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                style: AppTextStyles.body(size: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
