import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// "Why it matters" and "Example" for the term a quiz question tested, shown
/// after the learner has answered. The grey explanation box above it only
/// repeats the definition, so this is where the question turns into
/// learning. Renders nothing for scenario and expert questions (no single
/// term) or for a term without the richer format.
class TermInsight extends StatelessWidget {
  const TermInsight({super.key, required this.termKey});

  final String? termKey;

  @override
  Widget build(BuildContext context) {
    final term = MockData.termByKey(termKey);
    if (term == null) return const SizedBox.shrink();
    final sections = <(String, String)>[
      if (term.whyItMatters != null) ('WHY IT MATTERS', term.whyItMatters!),
      if (term.example != null) ('EXAMPLE', term.example!),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('term-insight'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(
              sections[i].$1,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: term.theme?.color ?? AppColors.tealDeep,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sections[i].$2,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.ink,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
