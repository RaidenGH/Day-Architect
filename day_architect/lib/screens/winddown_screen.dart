import 'package:flutter/material.dart';
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
  final int _navIndex = 2;
  bool _dnd = true;
  bool _dimApps = true;
  bool _alarm = false;

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
      case 3:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ProgressScreen()));
        break;
    }
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
                                  spreadRadius: 6),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Bedtime in 28 min',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading(size: 28)),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTextStyles.body(
                              size: 12.5, color: AppColors.textSecondary),
                          children: [
                            const TextSpan(
                                text:
                                    "Class starts at 8:00 AM — let's protect\n"),
                            TextSpan(
                                text: '7h 30m',
                                style: AppTextStyles.body(
                                    size: 12.5,
                                    weight: FontWeight.w600,
                                    color: AppColors.accent)),
                            const TextSpan(text: ' of sleep tonight'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      _toggleRow('Do Not Disturb', 'Silence all notifications',
                          _dnd, (v) => setState(() => _dnd = v)),
                      _toggleRow('Dim Social Apps', 'Grayscale + slow response',
                          _dimApps, (v) => setState(() => _dimApps = v)),
                      _toggleRow('Alarm Set', '6:30 AM — 7h 58m from now',
                          _alarm, (v) => setState(() => _alarm = v)),

                      const SizedBox(height: 12),
                      Text('SLEEP COMPARISON', style: AppTextStyles.label()),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          _sleepBar(
                              '5h 40m', 'Last night', 0.58, AppColors.plum),
                          const SizedBox(width: 14),
                          _sleepBar("7h 30m", "Tonight's goal", 1.0, null,
                              isGoal: true),
                          const SizedBox(width: 14),
                          _sleepBar('6h 15m', 'Avg (7 days)', 0.76,
                              AppColors.textMuted),
                        ],
                      ),

                      const SizedBox(height: 24),
                      PrimaryButton(label: 'Start wind-down now', onTap: () {}),
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
