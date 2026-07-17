import 'package:flutter/material.dart';

/// A slide-up + fade page transition used across all screens.
Route<T> _buildRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.08);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: curve));

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

/// Navigate to a page with a smooth slide-up + fade transition.
void pushPage(BuildContext context, Widget page) {
  Navigator.of(context).push(_buildRoute<void>(page));
}

/// Replace the current page with a new one using a smooth transition.
void pushReplacementPage(BuildContext context, Widget page) {
  Navigator.of(context).pushReplacement(_buildRoute<void>(page));
}
