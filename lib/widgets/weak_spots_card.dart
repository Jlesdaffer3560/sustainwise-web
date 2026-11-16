import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../screens/lesson_screen.dart';
import '../theme/app_theme.dart';
import 'app_route.dart';

/// Completed modules whose latest score is below 85%, weakest first, each
/// with a button to take it again. Renders nothing while there are none.
/// The app shows the same card on its Stats screen; on web it sits on
/// Progress, in "The Ledger" tokens on desktop.
class WeakSpotsCard extends StatelessWidget {
  const WeakSpotsCard({super.key, this.ledger = false});

  final bool ledger;

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    final weak = store.weakModuleIds().take(3).toList();
    if (weak.isEmpty) return const SizedBox.shrink();
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    final soft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    final font = ledger ? LedgerColors.fontSans : null;
    return Container(
      key: const Key('weak-spots-card'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.card : AppColors.surface,
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(ledger ? 6 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Worth another go',
            style: TextStyle(
              fontFamily: font,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Modules where you scored below 85% last time.',
            style: TextStyle(fontFamily: font, fontSize: 12, color: soft),
          ),
          const SizedBox(height: 8),
          for (final id in weak)
            _WeakRow(
              moduleId: id,
              accuracy: store.accuracyFor(id) ?? 0,
              ledger: ledger,
            ),
        ],
      ),
    );
  }
}

class _WeakRow extends StatelessWidget {
  const _WeakRow({
    required this.moduleId,
    required this.accuracy,
    required this.ledger,
  });

  final String moduleId;
  final double accuracy;
  final bool ledger;

  @override
  Widget build(BuildContext context) {
    final module = MockData.moduleById(moduleId);
    if (module == null) return const SizedBox.shrink();
    final font = ledger ? LedgerColors.fontSans : null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ledger ? LedgerColors.ink : AppColors.ink,
                  ),
                ),
                Text(
                  '${(accuracy * 100).round()}% right',
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontMono : null,
                    fontSize: 12,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            key: Key('weak-spot-practise-$moduleId'),
            style: ledger
                ? OutlinedButton.styleFrom(
                    foregroundColor: LedgerColors.teal,
                    side: const BorderSide(color: LedgerColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : null,
            onPressed: () => Navigator.of(context).push(
              appRoute(
                LessonScreen(
                  deck: MockData.lessonFor(moduleId),
                  moduleId: moduleId,
                ),
              ),
            ),
            child: const Text('Practise'),
          ),
        ],
      ),
    );
  }
}
