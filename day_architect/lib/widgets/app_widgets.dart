import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary gradient CTA button — used for main actions (Get Started, Start Wind-down, etc.)
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const PrimaryButton({super.key, required this.label, required this.onTap});

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
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
          child: Semantics(
            button: true,
            label: widget.label,
            child: Center(
              child: Text(
                widget.label,
                style: AppTextStyles.body(size: 15, weight: FontWeight.w700, color: AppColors.bgMid),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button
class GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const GhostButton({super.key, required this.label, required this.onTap});

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Semantics(
            button: true,
            label: widget.label,
            child: Center(
              child: Text(widget.label, style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: AppColors.textLavender)),
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

  const CategoryChip({super.key, required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTextStyles.body(size: 10, weight: FontWeight.w600, color: textColor)),
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
  final VoidCallback? onTap;
  final VoidCallback? onToggleDone;
  final VoidCallback? onLongPress;

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
    this.onToggleDone,
    this.onLongPress,
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
                style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
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
                        Text(title, style: AppTextStyles.body(size: 13, weight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        CategoryChip(label: chipLabel, bgColor: chipBg, textColor: accentColor),
                        if (meta != null) ...[
                          const SizedBox(height: 4),
                          Text(meta!, style: AppTextStyles.body(size: 11, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onToggleDone,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? AppColors.sage : Colors.transparent,
                            border: Border.all(color: AppColors.sage.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: done
                              ? const Icon(Icons.check, size: 13, color: AppColors.bgMid)
                              : null,
                        ),
                      ),
                    ),
                  ],
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

  const AppBottomNav({super.key, required this.activeIndex, required this.onTap});

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
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Semantics(
        label: 'Navigation',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final active = i == activeIndex;
            final item = _items[i];
            return GestureDetector(
              onTap: () => onTap(i),
              child: Semantics(
                selected: active,
                label: item.label,
                child: Column(
                  children: [
                    Icon(item.icon, size: 20, color: active ? AppColors.accent : AppColors.textMuted),
                    const SizedBox(height: 4),
                    Text(item.label, style: AppTextStyles.body(size: 10, weight: FontWeight.w500, color: active ? AppColors.accent : AppColors.textMuted)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Shared empty state ──

/// Shown when a list or section has no data yet.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    this.emoji = '📋',
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Empty state: $title',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Shown when an async operation fails.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Error: $message',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x30F26464),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF26464).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Color(0xFFF26464), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: AppTextStyles.body(size: 12, color: const Color(0xFFF26464))),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Text('Retry',
                    style: AppTextStyles.body(
                        size: 12, weight: FontWeight.w700, color: const Color(0xFFF26464))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared loading indicator ──

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Semantics(
          label: 'Loading',
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
    );
  }
}

// ── Page transition helper ──

/// A slide-from-right page route with a fade.
Route<T> fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.08, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var fadeTween = Tween(begin: 0.0, end: 1.0);

      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}
