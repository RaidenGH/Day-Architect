import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary gradient CTA button — used for main actions (Get Started, Start Wind-down, etc.)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const PrimaryButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: AppGradients.accentButton,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body(
                size: 15, weight: FontWeight.w700, color: AppColors.bgMid),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const GhostButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: AppTextStyles.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textLavender)),
        ),
      ),
    );
  }
}

/// Small rounded category label (Class, Focus, Routine, Org, Sleep)
class CategoryChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const CategoryChip(
      {super.key,
      required this.label,
      required this.bgColor,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: AppTextStyles.body(
              size: 10, weight: FontWeight.w600, color: textColor)),
    );
  }
}

/// A single scheduled task card, used on the Today screen
class TaskCard extends StatelessWidget {
  final String time;
  final String title;
  final String chipLabel;
  final Color accentColor;
  final Color chipBg;
  final String? meta;
  final bool done;

  const TaskCard({
    super.key,
    required this.time,
    required this.title,
    required this.chipLabel,
    required this.accentColor,
    required this.chipBg,
    this.meta,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                time,
                textAlign: TextAlign.right,
                style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border(left: BorderSide(color: accentColor, width: 3)),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.body(
                              size: 13, weight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      CategoryChip(
                          label: chipLabel,
                          bgColor: chipBg,
                          textColor: accentColor),
                      if (meta != null) ...[
                        const SizedBox(height: 4),
                        Text(meta!,
                            style: AppTextStyles.body(
                                size: 11, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.sage : Colors.transparent,
                        border: Border.all(
                            color: AppColors.sage.withValues(alpha: 0.5),
                            width: 1.5),
                      ),
                      child: done
                          ? const Icon(Icons.check,
                              size: 11, color: AppColors.bgMid)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom navigation bar shared across all main screens
class AppBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav(
      {super.key, required this.activeIndex, required this.onTap});

  static const _items = [
    (icon: Icons.grid_view_rounded, label: 'Today'),
    (icon: Icons.track_changes_rounded, label: 'Focus'),
    (icon: Icons.nightlight_round, label: 'Sleep'),
    (icon: Icons.insights_rounded, label: 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xF20E0F26),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final active = i == activeIndex;
          final item = _items[i];
          return GestureDetector(
            onTap: () => onTap(i),
            child: Column(
              children: [
                Icon(item.icon,
                    size: 20,
                    color: active ? AppColors.accent : AppColors.textMuted),
                const SizedBox(height: 4),
                Text(item.label,
                    style: AppTextStyles.body(
                        size: 10,
                        weight: FontWeight.w500,
                        color:
                            active ? AppColors.accent : AppColors.textMuted)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
