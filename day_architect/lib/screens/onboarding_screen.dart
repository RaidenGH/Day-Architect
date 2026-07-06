import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'today_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo mark
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(size: const Size(28, 24), painter: _TrianglePainter()),
                        const SizedBox(height: 2),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Day Architect', style: AppTextStyles.heading(size: 34)),
                const SizedBox(height: 6),
                Text(
                  'PLAN IT · FOCUS ON IT · SLEEP ON IT',
                  style: AppTextStyles.body(size: 12, weight: FontWeight.w500, color: AppColors.textAmberLight),
                ),

                const SizedBox(height: 32),
                Container(width: 48, height: 2, color: AppColors.accent.withValues(alpha: 0.5)),
                const SizedBox(height: 32),

                Text(
                  'Build the day you actually want to live',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(size: 22, weight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  "A planner built for Filipino students — schedule in seconds, block distractions, and protect your sleep.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 13, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 40),
                PrimaryButton(
                  label: "Get Started — it's free",
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      fadeSlideRoute(const TodayScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),
                GhostButton(label: 'I already have an account', onTap: () {}),

                const SizedBox(height: 24),
                Text('No credit card needed. Works offline.', style: AppTextStyles.body(size: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
