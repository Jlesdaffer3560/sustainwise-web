import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A user-facing fallback for the (currently only theoretical, per
/// test/content_validation_test.dart) case where a module's content is
/// empty — e.g. a future content edit drops every term for a module.
/// Without this, LessonScreen/QuizScreen index directly into their deck
/// and would crash instead of showing something a visitor can act on.
///
/// Web-only (see call sites): the native app has no way to reach this
/// screen with empty content today, and adding a branch there isn't worth
/// touching shared screens for a state that can't currently occur.
class ContentEmptyState extends StatelessWidget {
  const ContentEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: AppColors.inkSoft,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                ),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
