import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'today_screen.dart';
import 'winddown_screen.dart';
import 'progress_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final int _navIndex = 1;

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const TodayScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const WindDownScreen()));
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
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.arrow_back,
                              color: AppColors.textSecondary),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('● LIVE SESSION',
                                style: AppTextStyles.body(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.accent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Focus Mode', style: AppTextStyles.eyebrow()),
                      const SizedBox(height: 4),
                      Text('Studying: Thesis Defense Prep',
                          style: AppTextStyles.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: AppColors.textLavender)),

                      const SizedBox(height: 24),

                      // Timer ring
                      Center(
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: CustomPaint(
                                    painter: _RingPainter(progress: 0.75)),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('18:24',
                                      style: AppTextStyles.heading(size: 42)),
                                  const SizedBox(height: 4),
                                  Text('remaining',
                                      style: AppTextStyles.body(
                                          size: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          _infoPill('47 min', 'Focused today'),
                          const SizedBox(width: 12),
                          _infoPill('3', 'Sessions'),
                          const SizedBox(width: 12),
                          _infoPill('0', 'Interruptions'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Blocklist card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BLOCKING RIGHT NOW',
                                style: AppTextStyles.label(size: 10.5)),
                            const SizedBox(height: 12),
                            _blockRow('Instagram', Icons.camera_alt_outlined,
                                const Color(0xFFDC2743)),
                            _blockRow('TikTok', Icons.music_note, Colors.black),
                            _blockRow('Facebook', Icons.facebook,
                                const Color(0xFF1877F2)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('🏆 Personal best — keep going!',
                                style: AppTextStyles.body(
                                    size: 12.5,
                                    weight: FontWeight.w600,
                                    color: AppColors.sage)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.sage.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('+5 min',
                                  style: AppTextStyles.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: AppColors.sage)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      GhostButton(label: 'End session early', onTap: () {}),
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

  Widget _infoPill(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.body(size: 15, weight: FontWeight.w700)),
            Text(label,
                style: AppTextStyles.body(
                    size: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _blockRow(String name, IconData icon, Color iconBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(name,
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0x30F26464),
                borderRadius: BorderRadius.circular(20)),
            child: Text('Blocked',
                style: AppTextStyles.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color: const Color(0xFFF26464))),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..shader =
          const LinearGradient(colors: [AppColors.accent, AppColors.accentSoft])
              .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
