import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/winddown_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/page_transitions.dart';
import 'today_screen.dart';
import 'focus_screen.dart';
import 'progress_screen.dart';

class WindDownScreen extends StatefulWidget {
  const WindDownScreen({super.key});

  @override
  State<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends State<WindDownScreen> {
  final int _navIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WindDownProvider>().loadData();
    });
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
      case 3:
        pushReplacementPage(context, const ProgressScreen());
        break;
    }
  }

  Future<void> _startWindDown(WindDownProvider provider) async {
    final now = DateTime.now();
    await provider.startWindDown(bedtime: now);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🌙 Wind-down started! Sleep well.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                child: Consumer<WindDownProvider>(
                  builder: (context, provider, _) {
                    if (provider.loading) {
                      return Center(
                        child: Semantics(
                          label: 'Loading',
                          child: const CircularProgressIndicator(),
                        ),
                      );
                    }

                    final goalMinutes = provider.targetSleepMinutes;
                    final lastNightMinutes = provider.lastNightMinutes;
                    final avgMinutes = provider.avgSleepMinutes.round();
                    final lastNightFrac =
                        goalMinutes > 0 ? lastNightMinutes / goalMinutes : 0.0;
                    final avgFrac =
                        goalMinutes > 0 ? avgMinutes / goalMinutes : 0.0;

                    return SingleChildScrollView(
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
                                  colors: [
                                    Color(0xFF4A4585),
                                    Color(0xFF24225A)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF958CDB)
                                          .withValues(alpha: 0.28),
                                      blurRadius: 60,
                                      spreadRadius: 6),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Bedtime countdown
                          Text(
                            provider.bedtimeCountdownText,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.heading(size: 28),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTextStyles.body(
                                  size: 12.5,
                                  color: AppColors.textSecondary),
                              children: [
                                if (provider.earliestClassLabel.isNotEmpty &&
                                    provider.earliestClassLabel !=
                                        'No class tomorrow') ...[
                                  TextSpan(
                                    text:
                                        '${provider.earliestClassLabel} at ',
                                  ),
                                  TextSpan(
                                    text: provider.earliestClassTime,
                                    style: AppTextStyles.body(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: AppColors.accent),
                                  ),
                                  const TextSpan(text: ' tomorrow'),
                                ] else ...[
                                  const TextSpan(text: "Let's protect\n"),
                                  TextSpan(
                                    text:
                                        provider.formatMinutes(goalMinutes),
                                    style: AppTextStyles.body(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: AppColors.accent),
                                  ),
                                  const TextSpan(text: ' of sleep tonight'),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Toggle rows
                          _toggleRow(
                              'Do Not Disturb',
                              'Silence all notifications',
                              provider.dnd,
                              (v) => provider.setDnd(v)),
                          _toggleRow('Dim Social Apps',
                              'Grayscale + slow response',
                              provider.dimApps,
                              (v) => provider.setDimApps(v)),
                          _toggleRow('Alarm Set',
                              provider.earliestClassTime.isNotEmpty
                                  ? '${provider.formatMinutes(goalMinutes)} from bedtime'
                                  : '6:30 AM — wake-up ready',
                              provider.alarm,
                              (v) => provider.setAlarm(v)),

                          // Empty state when no sleep data exists
                          if (provider.lastNight == null &&
                              provider.avgSleepMinutes == 0) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: Semantics(
                                label: 'No sleep data yet',
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.plum
                                            .withValues(alpha: 0.2),
                                      ),
                                      child: Icon(
                                          Icons.bedtime_outlined,
                                          size: 28,
                                          color: AppColors.textMuted
                                              .withValues(alpha: 0.5)),
                                    ),
                                    const SizedBox(height: 10),
                                    Text('No sleep data yet',
                                        style: AppTextStyles.body(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: AppColors.textMuted)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'Start wind-down tonight to begin tracking',
                                        style: AppTextStyles.body(
                                            size: 11,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Text('SLEEP COMPARISON',
                                style: AppTextStyles.label()),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _sleepBar(
                                    provider.formatMinutes(lastNightMinutes),
                                    'Last night',
                                    lastNightFrac.clamp(0.0, 1.0),
                                    AppColors.plum),
                                const SizedBox(width: 14),
                                _sleepBar(
                                    provider.formatMinutes(goalMinutes),
                                    "Tonight's goal",
                                    1.0,
                                    null,
                                    isGoal: true),
                                const SizedBox(width: 14),
                                _sleepBar(
                                    provider.formatMinutes(avgMinutes),
                                    'Avg (7 days)',
                                    avgFrac.clamp(0.0, 1.0),
                                    AppColors.textMuted),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),
                          PrimaryButton(
                              label: 'Start wind-down now',
                              onTap: () => _startWindDown(provider)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              AppBottomNav(activeIndex: _navIndex, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
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

  Widget _sleepBar(String value, String label, double heightFrac, Color? color,
      {bool isGoal = false}) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFrac,
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
