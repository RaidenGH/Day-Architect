import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'focus_screen.dart';
import 'winddown_screen.dart';
import 'progress_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _navIndex = 0;

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() => _navIndex = index);
    switch (index) {
      case 1:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        break;
      case 2:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const WindDownScreen()));
        break;
      case 3:
        Navigator.push(
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
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good morning, Andrea 👋',
                              style: AppTextStyles.eyebrow()),
                          const SizedBox(height: 2),
                          Text('Tuesday, Jun 23',
                              style: AppTextStyles.heading(size: 27)),
                          const SizedBox(height: 16),

                          // Streak bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  RichText(
                                    text: TextSpan(
                                      style: AppTextStyles.body(
                                          size: 13, weight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                            text: '12-day',
                                            style: AppTextStyles.body(
                                                size: 13,
                                                weight: FontWeight.w600,
                                                color: AppColors.accent)),
                                        const TextSpan(text: ' streak'),
                                      ],
                                    ),
                                  ),
                                ]),
                                Text('4 / 6 blocks done',
                                    style: AppTextStyles.body(
                                        size: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                          Text("TODAY'S SCHEDULE",
                              style: AppTextStyles.label()),
                          const SizedBox(height: 10),

                          const TaskCard(
                            time: '7:30',
                            title: 'Wake & stretch',
                            chipLabel: 'Routine',
                            accentColor: AppColors.sage,
                            chipBg: AppColors.chipSageBg,
                            done: true,
                          ),
                          const TaskCard(
                            time: '8:00',
                            title: 'Software Design Lecture',
                            chipLabel: 'Class',
                            accentColor: AppColors.accent,
                            chipBg: AppColors.chipAmberBg,
                            meta: 'CpE 205 · Rm 302',
                            done: true,
                          ),
                          const TaskCard(
                            time: '10:30',
                            title: 'Focus Block: Thesis Prep',
                            chipLabel: 'Focus',
                            accentColor: AppColors.accentSoft,
                            chipBg: AppColors.chipCoralBg,
                            meta: '30 min · Social media blocked',
                          ),
                          const TaskCard(
                            time: '2:00',
                            title: 'Org Meeting — BITS',
                            chipLabel: 'Org',
                            accentColor: AppColors.plum,
                            chipBg: AppColors.chipPlumBg,
                          ),
                          const TaskCard(
                            time: '8:30',
                            title: 'Wind-down begins',
                            chipLabel: 'Sleep',
                            accentColor: AppColors.sage,
                            chipBg: AppColors.chipSageBg,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppBottomNav(activeIndex: _navIndex, onTap: _onNavTap),
                ],
              ),

              // Floating action button
              Positioned(
                right: 22,
                bottom: 90,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.accentButton,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child:
                      const Icon(Icons.add, color: AppColors.bgMid, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
