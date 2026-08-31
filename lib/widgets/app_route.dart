import 'package:flutter/material.dart';

/// The one page-transition style used everywhere instead of the default
/// `MaterialPageRoute` slide — a soft fade + scale-up so a new screen
/// feels like it grows into view, not just slides over. Applying this
/// consistently (rather than per-screen) is what makes navigation read as
/// one crafted app instead of a stack of separately-animated pages.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
