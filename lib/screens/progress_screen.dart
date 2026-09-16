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
    // "The Ledger" tokens only ever apply at the desktop-web breakpoint —
    // narrow web keeps the exact same look as native, per the standing
    // requirement that a small screen should still feel like the app.
    final ledger = isDesktopWeb(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ListenableBuilder(
        listenable: ProgressStore.instance,
        builder: (context, _) => Scaffold(
          backgroundColor: ledger ? LedgerColors.contentBg : AppColors.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ledger) _buildEyebrow(),
                  _buildHeader(ledger),
                  const SizedBox(height: 10),
                  _buildLocalStorageNotice(ledger),
                  const SizedBox(height: 18),
                  _buildXpBar(ledger),
                  const SizedBox(height: 20),
                  _buildChartsCard(ledger),
                  const SizedBox(height: 16),
                  _buildFluencyCard(ledger),
                  const SizedBox(height: 16),
                  _buildStatGrid(ledger),
                  const SizedBox(height: 24),
                  Text(
                    'Progress by unit',
                    style: TextStyle(
                      fontFamily: ledger ? LedgerColors.fontSans : null,
                      fontSize: 15.5,
                      fontWeight: ledger ? FontWeight.w600 : FontWeight.w800,
                      color: ledger ? LedgerColors.ink : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < MockData.units.length; i++)
                    _buildUnitProgress(MockData.units[i], i, ledger),
                  _buildExpertChallengeProgress(ledger),
                  const SizedBox(height: 12),
                  _buildAchievements(ledger),
                  const SizedBox(height: 20),
                  _buildSettingsList(context, ledger),
                  const SizedBox(height: 20),
                  _buildCopyright(ledger),
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

  /// Matches Glossary's and Home's top-of-content mono label + hairline
  /// divider — the one piece of "The Ledger" this screen was missing
  /// entirely, since everything below it already at least switched
  /// backgrounds.
  Widget _buildEyebrow() {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LedgerColors.border)),
      ),
      child: const Text(
        'PROGRESS',
        style: TextStyle(
          fontFamily: LedgerColors.fontMono,
          fontSize: 11,
          letterSpacing: 0.6,
          color: LedgerColors.inkSoft,
        ),
      ),
    );
  }

  Widget _buildHeader(bool ledger) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ledger
                  ? const [LedgerColors.teal, LedgerColors.gold]
                  : const [AppColors.teal, AppColors.amber],
            ),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your progress',
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontSize: 18,
                fontWeight: ledger ? FontWeight.w600 : FontWeight.w800,
                color: ledger ? LedgerColors.ink : AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Level ${ProgressStore.instance.level} · Sustainability Learner',
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontMono : null,
                fontSize: 12.5,
                color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Web has no account/backend, so this is worth saying plainly — otherwise
  // "I switched devices and it's gone" reads as a bug, not expected
  // behavior for a browser-local app.
  Widget _buildLocalStorageNotice(bool ledger) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.neutralSoft : AppColors.bg,
        borderRadius: BorderRadius.circular(ledger ? 6 : 10),
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saved in this browser only — not synced to an account or other devices.',
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontSize: 11.5,
                color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBar(bool ledger) {
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
            backgroundColor: ledger ? LedgerColors.border : AppColors.border,
            valueColor: ledger ? LedgerColors.teal : AppColors.teal,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedCounterText(
          value: store.xpIntoLevel,
          // "Points", not "XP" — less game vocabulary for a professional
          // audience (this screen is web-only regardless).
          formatter: (v) =>
              '$v/${store.xpPerLevel} points to level ${store.level + 1}',
          style: TextStyle(
            fontFamily: ledger ? LedgerColors.fontMono : null,
            fontSize: 11,
            color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildChartsCard(bool ledger) {
    final completed = ProgressStore.instance.completedModulesCount;
    final total = ProgressStore.instance.totalModulesCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.card : AppColors.surface,
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(ledger ? 6 : 16),
      ),
      child: Row(
        children: [
          ProgressRing(
            percent: total == 0 ? 0 : (completed / total) * 100,
            centerValue: '$completed/$total',
            centerLabel: 'modules',
            fillColor: ledger ? LedgerColors.teal : AppColors.teal,
            centerValueColor: ledger
                ? LedgerColors.teal
                : AppColors.tealDeep,
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
                Text(
                  'Your progress',
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontSans : null,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ledger ? LedgerColors.ink : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed of $total modules done',
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontSans : null,
                    fontSize: 12.5,
                    color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
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
  Widget _buildFluencyCard(bool ledger) {
    final store = ProgressStore.instance;
    final fluency = store.esgFluency;
    final accent = ledger ? LedgerColors.teal : AppColors.tealDeep;
    return Container(
      key: const Key('fluency-card'),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'ESG Fluency',
                style: TextStyle(
                  fontFamily: ledger ? LedgerColors.fontSans : null,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: ledger ? LedgerColors.ink : AppColors.ink,
                ),
              ),
              const Spacer(),
              if (fluency != null)
                Text(
                  '${fluency.round()}%',
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontMono : null,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fluency == null
                ? 'Complete a lesson to see how much is actually sticking.'
                : 'How much of what you\'ve studied is actually sticking, not just how much you\'ve done.',
            style: TextStyle(
              fontFamily: ledger ? LedgerColors.fontSans : null,
              fontSize: 12,
              color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < MockData.units.length; i++)
                _confidenceChip(MockData.units[i], i, ledger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confidenceChip(LearningUnit unit, int index, bool ledger) {
    final label = ProgressStore.instance.confidenceForUnit(unit);
    final parts = unit.title.split(' · ');
    final shortTitle = parts.length > 1
        ? parts.sublist(1).join(' · ')
        : unit.title;
    // "The Ledger" reads status, not per-unit hue — Home's own desktop
    // table dropped the rainbow unit accents for the same plain
    // teal/gold/neutral status language every other Ledger surface uses
    // (see LedgerModuleRow), so this card follows suit instead of being
    // the one place on the page that's still rainbow-colored.
    if (ledger) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: LedgerColors.neutralSoft,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: LedgerColors.border),
        ),
        child: Text(
          '$shortTitle — $label',
          style: const TextStyle(
            fontFamily: LedgerColors.fontSans,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: LedgerColors.inkSoft,
          ),
        ),
      );
    }
    final accents = AppColors.unitAccentsWeb;
    final palette = accents[index % accents.length];
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

  Widget _buildStatGrid(bool ledger) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: ProgressStore.instance.completedTermsCount,
            label: 'terms learned',
            ledger: ledger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: ProgressStore.instance.totalXp,
            label: 'total points',
            formatter: _formatXp,
            ledger: ledger,
          ),
        ),
      ],
    );
  }

  static String _formatXp(int xp) {
    final s = xp.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  Widget _buildUnitProgress(LearningUnit unit, int index, bool ledger) {
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
    final progress = total == 0 ? 0.0 : completed / total;
    // Status-driven ring color on the Ledger (teal once every module in
    // the unit is done, gold while it's partway through, neutral before
    // it's started) instead of the per-unit rainbow accent — same reasoning
    // as _confidenceChip above.
    final ringColor = ledger
        ? (progress >= 1
              ? LedgerColors.teal
              : progress > 0
              ? LedgerColors.goldDeep
              : LedgerColors.neutralDot)
        : AppColors.unitAccentsWeb[index % AppColors.unitAccentsWeb.length]
              .fill;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.card : AppColors.surface,
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(ledger ? 6 : 14),
      ),
      child: Row(
        children: [
          ProgressRing(
            percent: progress * 100,
            centerValue: '$completed/$total',
            centerLabel: '',
            size: 52,
            fillColor: ringColor,
            centerValueColor: ringColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.title,
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontSans : null,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ledger ? LedgerColors.ink : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$termsLearned/${unit.totalTerms} terms learned',
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontMono : null,
                    fontSize: 12,
                    color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
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
  Widget _buildExpertChallengeProgress(bool ledger) {
    final store = ProgressStore.instance;
    final completed = store.expertChallengeCompleted;
    final unlocked = store.expertChallengeUnlocked;
    final accuracy = store.expertChallengeAccuracy;
    final subtitle = completed
        ? '${(accuracy! * MockData.expertChallenge.length).round()}/${MockData.expertChallenge.length} correct — ${(accuracy * 100).round()}% accuracy'
        : unlocked
        ? 'Unlocked — not attempted yet'
        : 'Complete every module above to unlock';
    final gold = ledger ? LedgerColors.goldDeep : AppColors.amberDeep;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.card : AppColors.surface,
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(ledger ? 6 : 14),
      ),
      child: Row(
        children: [
          ProgressRing(
            percent: completed ? 100 : 0,
            centerValue: completed ? '✓' : '—',
            centerLabel: '',
            size: 52,
            fillColor: gold,
            centerValueColor: gold,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expert Challenge',
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontSans : null,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ledger ? LedgerColors.ink : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: ledger ? LedgerColors.fontMono : null,
                    fontSize: 12,
                    color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
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
  Widget _buildAchievements(bool ledger) {
    final achievements = ProgressStore.instance.achievements
        .where((a) => a.id != 'week-streak' && a.id != 'month-streak')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Milestones", not "Achievements" — less game vocabulary for a
        // professional audience (this screen is web-only regardless).
        Text(
          'Milestones',
          style: TextStyle(
            fontFamily: ledger ? LedgerColors.fontSans : null,
            fontSize: 15,
            fontWeight: ledger ? FontWeight.w600 : FontWeight.w800,
            color: ledger ? LedgerColors.ink : AppColors.ink,
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
            for (final a in achievements)
              _AchievementTile(achievement: a, ledger: ledger),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsList(BuildContext context, bool ledger) {
    final border = ledger ? LedgerColors.border : AppColors.border;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
      child: Column(
        children: [
          // The real Play Store link once that listing is public — it's
          // in closed testing right now, and linking to a non-public
          // listing would deny access for most visitors. Reuses
          // _settingsRow's existing "coming soon" tap, same as every
          // other not-yet-available setting here.
          _settingsRow(context, 'Get the app', 'Google Play', ledger),
          _settingsRow(context, 'Language', 'English', ledger),
          _buildResetProgressRow(context, ledger),
        ],
      ),
    );
  }

  /// Destructive, so it's confirmed rather than fired on a single tap.
  Widget _buildResetProgressRow(BuildContext context, bool ledger) {
    final border = ledger ? LedgerColors.border : AppColors.border;
    return InkWell(
      key: const Key('reset-progress-row'),
      onTap: () {
        AppFeedback.tap();
        showResetProgressDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reset progress',
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontSize: 14,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.restart_alt, color: AppColors.danger, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _settingsRow(
    BuildContext context,
    String label,
    String value,
    bool ledger,
  ) {
    final border = ledger ? LedgerColors.border : AppColors.border;
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        showComingSoon(context, label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontSize: 14,
                color: ledger ? LedgerColors.ink : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontMono : null,
                fontSize: 13.5,
                color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyright(bool ledger) {
    return Center(
      child: Text(
        '© 2026 Jordi Lesaffer · Novarisq Consulting',
        style: TextStyle(
          fontFamily: ledger ? LedgerColors.fontMono : null,
          fontSize: 11,
          color: (ledger ? LedgerColors.inkSoft : AppColors.inkSoft)
              .withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.ledger,
    this.formatter,
  });

  final int value;
  final String label;
  final bool ledger;
  final String Function(int)? formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.card : AppColors.surface,
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(ledger ? 6 : 14),
      ),
      child: Column(
        children: [
          AnimatedCounterText(
            value: value,
            formatter: formatter,
            style: TextStyle(
              fontFamily: ledger ? LedgerColors.fontMono : 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: ledger ? LedgerColors.teal : AppColors.tealDeep,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ledger ? LedgerColors.fontSans : null,
              fontSize: 11.5,
              color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.ledger});

  final Achievement achievement;
  final bool ledger;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final bg = ledger
        ? (unlocked ? LedgerColors.goldSoft : LedgerColors.card)
        : (unlocked ? AppColors.amberSoft : AppColors.surface);
    final border = ledger
        ? (unlocked ? LedgerColors.gold : LedgerColors.border)
        : (unlocked
              ? AppColors.amberDeep.withValues(alpha: 0.35)
              : AppColors.border);
    final iconColor = ledger
        ? (unlocked ? LedgerColors.goldDeep : LedgerColors.inkSoft)
        : (unlocked
              ? AppColors.amberDeep
              : AppColors.inkSoft.withValues(alpha: 0.5));
    final textColor = ledger
        ? (unlocked ? LedgerColors.ink : LedgerColors.inkSoft)
        : (unlocked ? AppColors.ink : AppColors.inkSoft);
    return Container(
      key: Key('achievement-${achievement.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(ledger ? 6 : 14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(achievement.icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ledger ? LedgerColors.fontSans : null,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
