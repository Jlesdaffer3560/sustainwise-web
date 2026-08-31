import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/mascot.dart';
import '../widgets/moment_badge.dart';
import '../widgets/progress_ring.dart';
import '../widgets/reset_progress_dialog.dart';

/// The reward screen at the end of a lesson — ported from the mockup's
/// `#view-complete`. Shows accuracy on the same [ProgressRing] used
/// elsewhere, a one-shot confetti burst, and the lesson's stats.
class LessonCompleteScreen extends StatefulWidget {
  const LessonCompleteScreen({
    super.key,
    required this.correct,
    required this.total,
    this.title = 'Lesson complete!',
    this.xpEarned = 15,
    this.isFinale = false,
  });

  final int correct;
  final int total;
  final String title;
  final int xpEarned;

  // True only for the Expert Challenge's own completion — the one moment
  // that means the entire curriculum is done, not just one module. Adds a
  // distinct closing message and a way to reset and go through it all
  // again, on top of the regular per-lesson reward layout.
  final bool isFinale;

  @override
  State<LessonCompleteScreen> createState() => _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends State<LessonCompleteScreen> {
  @override
  void initState() {
    super.initState();
    // A one-shot celebration on arrival — not inside build(), which reruns
    // on every ProgressStore change this screen listens to and would
    // otherwise replay the sound/haptic on unrelated rebuilds. The finale
    // celebrates unconditionally — finishing the whole curriculum is worth
    // marking even on a replay that wasn't a perfect run.
    if (widget.isFinale ||
        (widget.total > 0 && widget.correct == widget.total)) {
      AppFeedback.celebrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.correct;
    final total = widget.total;
    final title = widget.title;
    final xpEarned = widget.xpEarned;
    final isFinale = widget.isFinale;
    final accuracy = total == 0 ? 0.0 : (correct / total) * 100;
    final isPerfect = total > 0 && correct == total;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ListenableBuilder(
        listenable: ProgressStore.instance,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Mascot(
                            mood: isFinale || isPerfect
                                ? MascotMood.cheering
                                : accuracy >= 70
                                ? MascotMood.happy
                                : accuracy >= 40
                                ? MascotMood.encouraging
                                : MascotMood.worried,
                            size: isFinale ? 72 : 60,
                          ),
                          const SizedBox(height: 14),
                          // The finale relies on the full-screen ConfettiCloud
                          // and its own "overall accuracy" stat tile below —
                          // showing this round's own accuracy ring on top of
                          // that would just be a second, competing percentage.
                          if (!isFinale) ...[
                            (() {
                              final ring = ProgressRing(
                                percent: accuracy,
                                centerValue: '${accuracy.round()}%',
                                centerLabel: 'accuracy',
                                size: 132,
                                fillColor: isPerfect
                                    ? AppColors.success
                                    : AppColors.teal,
                              );
                              return isPerfect
                                  ? ConfettiBurst(child: ring)
                                  : ring;
                            })(),
                            const SizedBox(height: 22),
                          ],
                          if (isPerfect && !isFinale) ...[
                            const _PerfectBadge(),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          if (isFinale) ...[
                            const SizedBox(height: 8),
                            const Text(
                              "Every module, every quiz, and the Expert "
                              "Challenge — that's real, demonstrated fluency "
                              "in the language of sustainability.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.inkSoft,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MomentBadge(
                                type: MomentType.star,
                                size: 30,
                                xpLabel: '+$xpEarned XP',
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${ProgressStore.instance.streakDays}-day streak',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isFinale)
                                _StatTile(
                                  icon: Icons.gps_fixed,
                                  value:
                                      ProgressStore.instance.esgFluency == null
                                      ? '—'
                                      : '${ProgressStore.instance.esgFluency!.round()}%',
                                  label: 'overall accuracy',
                                )
                              else
                                _StatTile(
                                  icon: Icons.check_circle_outline,
                                  value: '$correct/$total',
                                  label: 'correct',
                                ),
                              const SizedBox(width: 10),
                              _StatTile(
                                icon: Icons.menu_book_outlined,
                                value: isFinale
                                    ? '${ProgressStore.instance.completedTermsCount}/${MockData.allTerms.length}'
                                    : '${ProgressStore.instance.completedTermsCount}',
                                label: 'terms learned',
                              ),
                              const SizedBox(width: 10),
                              _StatTile(
                                icon: Icons.route_outlined,
                                value:
                                    '${ProgressStore.instance.completedModulesCount}/${ProgressStore.instance.totalModulesCount}',
                                label: 'modules',
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('lesson-complete-continue-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                AppFeedback.tap();
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                isFinale ? 'Back to Home' : 'Continue',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          if (isFinale) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const Key(
                                  'lesson-complete-reset-suggestion',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  AppFeedback.tap();
                                  showResetProgressDialog(
                                    context,
                                    onConfirmed: () =>
                                        Navigator.of(context).pop(),
                                  );
                                },
                                icon: const Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: AppColors.inkSoft,
                                ),
                                label: const Text(
                                  'Ready for a full redo? Reset progress',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Painted last so it falls in front of the cards/buttons
                // above, not behind them — Stack paints in list order.
                if (isFinale)
                  const Positioned.fill(
                    child: IgnorePointer(child: ConfettiCloud()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: AppColors.tealDeep),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.tealDeep,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small congratulatory pill shown only on a perfect score — the plain
/// accuracy ring already says "100%", this names what that means so the
/// moment reads as a deliberate reward rather than a coincidence.
class _PerfectBadge extends StatelessWidget {
  const _PerfectBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MomentBadge(type: MomentType.medal, size: 22),
          SizedBox(width: 6),
          Text(
            'Perfect score!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: AppColors.amberDeep,
            ),
          ),
        ],
      ),
    );
  }
}
