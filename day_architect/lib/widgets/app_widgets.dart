import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary gradient CTA button — used for main actions (Get Started, Start Wind-down, etc.)
/// Includes scale animation on tap and ripple effect.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const PrimaryButton({super.key, required this.label, required this.onTap});

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) {
            _scaleController.reverse();
            widget.onTap();
          },
          onTapCancel: () => _scaleController.reverse(),
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
                widget.label,
                style: AppTextStyles.body(
                    size: 15, weight: FontWeight.w700, color: AppColors.bgMid),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button with scale-on-tap feedback.
class GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const GhostButton({super.key, required this.label, required this.onTap});

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) {
            _scaleController.reverse();
            widget.onTap();
          },
          onTapCancel: () => _scaleController.reverse(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(widget.label,
                  style: AppTextStyles.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textLavender)),
            ),
          ),
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

/// A single scheduled task card, used on the Today screen.
/// When [onTap] is provided, tapping the card triggers it (e.g. toggle done).
/// When [onLongPress] is provided, long-pressing opens the edit sheet.
/// When [onStartFocus] is provided, a small focus icon appears to jump into
/// a focus session with this task's title pre-filled.
class TaskCard extends StatelessWidget {
  final String time;
  final String title;
  final String chipLabel;
  final Color accentColor;
  final Color chipBg;
  final String? meta;
  final bool done;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStartFocus;

  const TaskCard({
    super.key,
    required this.time,
    required this.title,
    required this.chipLabel,
    required this.accentColor,
    required this.chipBg,
    this.meta,
    this.done = false,
    this.onTap,
    this.onLongPress,
    this.onStartFocus,
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
              child: Semantics(
                label: 'Time: $time',
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: '${done ? "Completed: " : ""}$title, $chipLabel',
              button: true,
              child: GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                        left: BorderSide(color: accentColor, width: 3)),
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
                        child: Semantics(
                          label: done ? 'Completed' : 'Not completed',
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done ? AppColors.sage : Colors.transparent,
                              border: Border.all(
                                  color: AppColors.sage.withValues(alpha: 0.5),
                                  width: 1.5),
                            ),
                            child: done
                                ? const Icon(Icons.check,
                                    size: 13, color: AppColors.bgMid)
                                : null,
                          ),
                        ),
                      ),
                      // Focus shortcut button
                      if (onStartFocus != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Semantics(
                            label: 'Start focus session: $title',
                            button: true,
                            child: GestureDetector(
                              onTap: onStartFocus,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.track_changes_rounded,
                                    size: 14, color: accentColor),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
    return Semantics(
      label: 'Bottom navigation',
      child: Container(
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
            return Semantics(
              label: '${item.label} tab',
              selected: active,
              button: true,
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon,
                          size: 22,
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
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
