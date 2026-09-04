import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/responsive.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_route.dart';
import '../widgets/progress_ring.dart';
import '../widgets/reset_progress_dialog.dart';
import 'glossary_screen.dart';

/// Web-only merged view of what native splits across Stats and Profile —
/// per external review, "Profile" reads as artificial for a site with no
/// login/account, and the two screens otherwise cover overlapping ground
/// (modules done, accuracy) for a visitor who's really asking one question:
/// how much of the curriculum have I actually covered. Native is completely
/// unaffected — [StatsScreen] and [ProfileScreen] still exist unchanged and
/// unmerged there; this is a new, separate screen web routes to instead.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

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
        builder: (context, _) => Scaffold(
          backgroundColor: isDesktopWeb(context)
              ? LedgerColors.contentBg
              : AppColors.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  _buildLocalStorageNotice(),
                  const SizedBox(height: 18),
                  _buildXpBar(),
                  const SizedBox(height: 20),
                  _buildChartsCard(),
                  const SizedBox(height: 16),
                  _buildFluencyCard(),
                  const SizedBox(height: 16),
                  _buildStatGrid(),
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
                  const SizedBox(height: 12),
                  _buildAchievements(),
                  const SizedBox(height: 20),
                  _buildSettingsList(context),
                  const SizedBox(height: 20),
                  _buildCopyright(),
                ],
              ),
            ),
          ),
          // On desktop web, tab navigation lives in the sidebar
          // (DesktopShell) instead — but only once there's room for one.
          bottomNavigationBar: isDesktopWeb(context)
              ? null
              : AppBottomNav(
                  current: AppTab.stats,
                  onPathTap: () => Navigator.of(context).pop(),
                  onGlossaryTap: () => Navigator.of(
                    context,
                  ).pushReplacement(appRoute(const GlossaryScreen())),
                  onStatsTap: () {},
                  onProfileTap: () {},
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.teal, AppColors.amber],
            ),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Level ${ProgressStore.instance.level} · Sustainability Learner',
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ],
    );
  }

  // Web has no account/backend, so this is worth saying plainly — otherwise
  // "I switched devices and it's gone" reads as a bug, not expected
  // behavior for a browser-local app.
  Widget _buildLocalStorageNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 15, color: AppColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saved in this browser only — not synced to an account or other devices.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.inkSoft,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBar() {
    final store = ProgressStore.instance;
    final progress = store.xpIntoLevel / store.xpPerLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: AnimatedProgressBar(
            value: progress.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: AppColors.border,
            valueColor: AppColors.teal,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedCounterText(
          value: store.xpIntoLevel,
          // "Points", not "XP" — less game vocabulary for a professional
          // audience (this screen is web-only regardless).
          formatter: (v) =>
              '$v/${store.xpPerLevel} points to level ${store.level + 1}',
          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildChartsCard() {
    final completed = ProgressStore.instance.completedModulesCount;
    final total = ProgressStore.instance.totalModulesCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProgressRing(
            percent: total == 0 ? 0 : (completed / total) * 100,
            centerValue: '$completed/$total',
            centerLabel: 'modules',
          ),
          const SizedBox(width: 18),
          // A week-activity chart is near-empty for a one-time web visitor
          // — a plain read of overall completion instead. "Your progress",
          // not "This visit": completed/total is persisted browser-local
          // progress, not scoped to the current session.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your progress',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed of $total modules done',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Distinct from XP: XP measures how much a learner has *done*, this
  /// measures how much of it is actually sticking, from real quiz+pairs
  /// accuracy rather than completion alone. Per-unit chips only judge units
  /// with at least one completed module — no guessing at unstudied topics.
  Widget _buildFluencyCard() {
    final store = ProgressStore.instance;
    final fluency = store.esgFluency;
    return Container(
      key: const Key('fluency-card'),
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
            children: [
              const Icon(
                Icons.psychology_outlined,
                color: AppColors.tealDeep,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'ESG Fluency',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (fluency != null)
                Text(
                  '${fluency.round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.tealDeep,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fluency == null
                ? 'Complete a lesson to see how much is actually sticking.'
                : 'How much of what you\'ve studied is actually sticking, not just how much you\'ve done.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.inkSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < MockData.units.length; i++)
                _confidenceChip(MockData.units[i], i),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confidenceChip(LearningUnit unit, int index) {
    final accents = AppColors.unitAccentsWeb;
    final palette = accents[index % accents.length];
    final label = ProgressStore.instance.confidenceForUnit(unit);
    final parts = unit.title.split(' · ');
    final shortTitle = parts.length > 1
        ? parts.sublist(1).join(' · ')
        : unit.title;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$shortTitle — $label',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: palette.deep,
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: ProgressStore.instance.completedTermsCount,
            label: 'terms learned',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: ProgressStore.instance.totalXp,
            label: 'total points',
            formatter: _formatXp,
          ),
        ),
      ],
    );
  }

  String _formatXp(int xp) {
    final s = xp.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  Widget _buildUnitProgress(LearningUnit unit, int index) {
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
    final accents = AppColors.unitAccentsWeb;
    final accent = accents[index % accents.length].fill;
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

  // Sits outside every unit (it unlocks only once all of them are done), so
  // it gets its own row here rather than being folded into one.
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

  /// Badges judged only against the learner's own history — never other
  /// users, since this app has no accounts or backend to compare against.
  /// The two streak-length badges (7-day, 30-day) are excluded — they can
  /// never unlock within a single web visit, which reads as broken rather
  /// than aspirational the way it does in an app someone returns to daily.
  Widget _buildAchievements() {
    final achievements = ProgressStore.instance.achievements
        .where((a) => a.id != 'week-streak' && a.id != 'month-streak')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Milestones", not "Achievements" — less game vocabulary for a
        // professional audience (this screen is web-only regardless).
        const Text(
          'Milestones',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            for (final a in achievements) _AchievementTile(achievement: a),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _settingsRow(context, 'Language', 'English'),
          _buildResetProgressRow(context),
        ],
      ),
    );
  }

  /// Destructive, so it's confirmed rather than fired on a single tap.
  Widget _buildResetProgressRow(BuildContext context) {
    return InkWell(
      key: const Key('reset-progress-row'),
      onTap: () {
        AppFeedback.tap();
        showResetProgressDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reset progress',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.restart_alt, color: AppColors.danger, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _settingsRow(BuildContext context, String label, String value) {
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        showComingSoon(context, label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyright() {
    return Center(
      child: Text(
        '© 2026 Jordi Lesaffer · Novarisq Consulting',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.inkSoft.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.formatter});

  final int value;
  final String label;
  final String Function(int)? formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          AnimatedCounterText(
            value: value,
            formatter: formatter,
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
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Container(
      key: Key('achievement-${achievement.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.amberSoft : AppColors.surface,
        border: Border.all(
          color: unlocked
              ? AppColors.amberDeep.withValues(alpha: 0.35)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            color: unlocked
                ? AppColors.amberDeep
                : AppColors.inkSoft.withValues(alpha: 0.5),
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: unlocked ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
