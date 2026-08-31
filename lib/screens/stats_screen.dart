import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_route.dart';
import '../widgets/progress_ring.dart';
import '../widgets/week_activity_chart.dart';
import 'glossary_screen.dart';
import 'profile_screen.dart';

/// Stats — the detail view behind the numbers Home/Profile only summarize:
/// the week's activity at a glance, overall accuracy, and a per-unit
/// breakdown of exactly how far along each part of the path is.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ListenableBuilder(
        listenable: ProgressStore.instance,
        builder: (context, _) {
          // Computed inside the builder (not hoisted up into the outer
          // build()) so it re-reads live on every ProgressStore
          // notification, the same as everything else on this screen —
          // not just once when the screen is first pushed.
          final weekActivity = buildWeekActivity(
            xpPerDay: ProgressStore.instance.thisWeekXp,
            todayIndex: ProgressStore.instance.todayWeekdayIndex,
            goalXp: ProgressStore.dailyGoalXp,
          );
          final activeDays = weekActivity.where((d) => d.level > 0).length;
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your stats',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'How your practice is trending, and how far you are on the path.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _HeadlineTile(
                            icon: Icons.local_fire_department,
                            iconColor: AppColors.amber,
                            value: '${ProgressStore.instance.streakDays}',
                            label: 'day streak',
                            caption:
                                'Best: ${ProgressStore.instance.longestStreak} days',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeadlineTile(
                            icon: Icons.gps_fixed,
                            iconColor: AppColors.teal,
                            value: ProgressStore.instance.esgFluency == null
                                ? '—'
                                : '${ProgressStore.instance.esgFluency!.round()}%',
                            label: 'overall accuracy',
                            caption: ProgressStore.instance.esgFluency == null
                                ? 'Complete a module to see this'
                                : 'Across completed modules & Expert Challenge',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'This week',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                '$activeDays/7 days',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          WeekActivityChart(
                            days: weekActivity,
                            trackHeight: 56,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Progress by unit',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < MockData.units.length; i++)
                      _buildUnitProgress(MockData.units[i], i),
                    _buildExpertChallengeProgress(),
                  ],
                ),
              ),
            ),
            // On web, tab navigation lives in the sidebar (DesktopShell).
            bottomNavigationBar: kIsWeb
                ? null
                : AppBottomNav(
                    current: AppTab.stats,
                    onPathTap: () => Navigator.of(context).pop(),
                    onGlossaryTap: () => Navigator.of(
                      context,
                    ).pushReplacement(appRoute(const GlossaryScreen())),
                    onStatsTap: () {},
                    onProfileTap: () => Navigator.of(
                      context,
                    ).pushReplacement(appRoute(const ProfileScreen())),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildUnitProgress(LearningUnit unit, int index) {
    // Only ModuleStatus.done counts as "learned" — a module that's merely
    // unlocked (current) hasn't actually been finished yet, even though a
    // learner can now reach it.
    final completed = unit.modules
        .where(
          (m) => ProgressStore.instance.statusFor(m.id) == ModuleStatus.done,
        )
        .length;
    final total = unit.modules.length;
    final termsLearned = unit.modules
        .where(
          (m) => ProgressStore.instance.statusFor(m.id) == ModuleStatus.done,
        )
        .fold(0, (sum, m) => sum + m.termCount);
    final accent =
        AppColors.unitAccents[index % AppColors.unitAccents.length].fill;
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ProgressRing(
            percent: progress * 100,
            centerValue: '$completed/$total',
            centerLabel: '',
            size: 52,
            fillColor: accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$termsLearned/${unit.totalTerms} terms learned',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sits outside every unit (it unlocks only once all of them are done),
  // so it gets its own row here rather than being folded into one — the
  // one place in the app that otherwise made it look like completing it
  // left no trace in the stats a learner actually checks.
  Widget _buildExpertChallengeProgress() {
    final store = ProgressStore.instance;
    final completed = store.expertChallengeCompleted;
    final unlocked = store.expertChallengeUnlocked;
    final accuracy = store.expertChallengeAccuracy;
    final subtitle = completed
        ? '${(accuracy! * MockData.expertChallenge.length).round()}/${MockData.expertChallenge.length} correct — ${(accuracy * 100).round()}% accuracy'
        : unlocked
        ? 'Unlocked — not attempted yet'
        : 'Complete every module above to unlock';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ProgressRing(
            percent: completed ? 100 : 0,
            centerValue: completed ? '✓' : '—',
            centerLabel: '',
            size: 52,
            fillColor: AppColors.amberDeep,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expert Challenge',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineTile extends StatelessWidget {
  const _HeadlineTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
