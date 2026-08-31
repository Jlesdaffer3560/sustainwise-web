import 'package:flutter/material.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

/// Shared between Profile's settings row, Home's quick-access icon, and the
/// finale screen's reset suggestion, so the copy and behavior can never
/// drift between entry points. [onConfirmed] runs right after a confirmed
/// reset (dialog already dismissed) — the finale screen uses it to pop
/// itself, since staying there would otherwise show "Curriculum complete!"
/// next to a freshly-zeroed progress count.
void showResetProgressDialog(
  BuildContext context, {
  VoidCallback? onConfirmed,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Reset all progress?'),
      content: const Text(
        'This clears your streak, XP, completed modules, and mistakes queue, and starts you back at the '
        'very first module. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            AppFeedback.tap();
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('reset-progress-confirm'),
          onPressed: () {
            AppFeedback.tap();
            ProgressStore.instance.resetProgress();
            Navigator.of(dialogContext).pop();
            onConfirmed?.call();
          },
          child: const Text(
            'Reset',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
