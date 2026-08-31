import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../widgets/confetti_burst.dart';
import '../widgets/mascot.dart';
import '../widgets/milestone_moment.dart';
import '../widgets/moment_badge.dart';
import '../widgets/module_path_node.dart';
import '../widgets/reset_progress_dialog.dart';
import 'expert_challenge_screen.dart';
import 'glossary_screen.dart';
import 'lesson_screen.dart';
import 'profile_screen.dart';
import 'regulatory_radar_screen.dart';
import 'review_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // A milestone crossed *during this session* — reached once and tracked
  // here rather than derived fresh each build, so returning to an
  // already-met state later doesn't replay the celebration. Daily-goal and
  // streak-milestone/course-complete get different treatments (a plain
  // confetti burst vs. the richer [MilestoneMoment]), so they're tracked
  // separately rather than one shared boolean.
  bool _showDailyGoalConfetti = false;
  MilestoneMoment? _activeMilestone;
  // A same-size flame flourish on *every* streak change, not just the
  // 7/30/100 milestones — those still get the bigger [MilestoneMoment].
  bool _showFlameBadge = false;
  late int _lastStreak;
  late bool _lastDailyGoalMet;
  late int _lastCompletedModules;

  static const _streakMilestones = {7, 30, 100};

  @override
  void initState() {
    super.initState();
    _lastStreak = ProgressStore.instance.streakDays;
    _lastDailyGoalMet = ProgressStore.instance.dailyGoalMet;
    _lastCompletedModules = ProgressStore.instance.completedModulesCount;
    ProgressStore.instance.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    ProgressStore.instance.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    final store = ProgressStore.instance;
    final streakChanged = store.streakDays != _lastStreak;
    final hitStreakMilestone =
        streakChanged && _streakMilestones.contains(store.streakDays);
    final hitDailyGoal = store.dailyGoalMet && !_lastDailyGoalMet;
    final hitCourseComplete =
        store.totalModulesCount > 0 &&
        store.completedModulesCount >= store.totalModulesCount &&
        _lastCompletedModules < store.totalModulesCount;
    _lastStreak = store.streakDays;
    _lastDailyGoalMet = store.dailyGoalMet;
    _lastCompletedModules = store.completedModulesCount;
    if (!mounted) return;

    if (streakChanged) {
      setState(() => _showFlameBadge = true);
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showFlameBadge = false);
      });
    }

    // Course-complete takes priority if both somehow land on the same
    // notification — it's the rarer, bigger moment of the two.
    if (hitCourseComplete || hitStreakMilestone) {
      setState(() {
        _activeMilestone = hitCourseComplete
            ? const MilestoneMoment(
                kind: MilestoneKind.courseComplete,
                headline: 'Course complete!',
              )
            : MilestoneMoment(
                kind: MilestoneKind.streak,
                headline: '${store.streakDays}-day streak!',
              );
      });
      Future.delayed(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _activeMilestone = null);
      });
    } else if (hitDailyGoal) {
      setState(() => _showDailyGoalConfetti = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showDailyGoalConfetti = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The hero card behind the status bar is dark teal, so the system
      // icons (clock, battery, wifi) need light content to stay legible.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ListenableBuilder(
        listenable: ProgressStore.instance,
        builder: (context, _) => _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const Key('module-path-scroll'),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _buildHero(context),
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildIntroCard(),
                      ),
                    ),
                    // Directly above Daily Goal, not under the hero title —
                    // "what do I do right now" and "how's today going" read
                    // as one connected pair of actionable cards this way,
                    // rather than the CTA sitting off on its own up top.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildContinueLearningCard(context),
                    ),
                    _buildDailyGoalCard(),
                    _buildMistakesCard(context),
                    _buildRegulatoryRadarCard(context),
                    const _ScrollHint(),
                    for (var i = 0; i < MockData.units.length; i++)
                      _buildUnitSection(context, MockData.units[i], i),
                    _buildExpertChallengeCard(context),
                    _buildCopyrightFooter(),
                  ],
                ),
              ),
            ),
            // A milestone just landed — burst over the top of the hero
            // where the eye already is. Daily goal keeps the plain confetti
            // (it happens near-daily); a streak milestone or finishing the
            // whole curriculum gets the richer badge+headline moment.
            if (_showDailyGoalConfetti)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: IgnorePointer(child: ConfettiBurst(size: 280)),
              ),
            if (_activeMilestone != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: IgnorePointer(child: _activeMilestone!),
              ),
          ],
        ),
      ),
      // On web, tab navigation lives in the sidebar (DesktopShell) instead
      // — but only once there's room for one; narrow web viewports keep
      // this bottom bar just like the native app.
      bottomNavigationBar: isDesktopWeb(context)
          ? null
          : _buildBottomNav(context),
    );
  }

  /// A full-bleed banner rather than a floating rounded card — the gradient
  /// dissolves straight into the page background at its own bottom edge, so
  /// there's no hard seam between the dark header and the light body below.
  /// The intro card (a sibling, not a child, so it isn't clipped to this
  /// container's bounds) is pulled up over the fade with a negative margin,
  /// bridging the two instead of sitting in a separate block underneath.
  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 46),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.heroDeep, AppColors.heroMid, AppColors.bg],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _pill(
                    Icons.local_fire_department,
                    ProgressStore.instance.streakDays,
                    AppColors.amber,
                  ),
                  // A one-shot flame flourish the moment the streak count
                  // itself changes — separate from the bigger
                  // [MilestoneMoment] reserved for the 7/30/100 milestones.
                  if (_showFlameBadge)
                    Positioned(
                      right: -10,
                      top: -14,
                      child: IgnorePointer(
                        child: MomentBadge(type: MomentType.flame, size: 30),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _resetIconButton(context),
                  const SizedBox(width: 8),
                  _pill(
                    Icons.star,
                    ProgressStore.instance.totalXp,
                    Colors.white,
                    formatter: _formatXp,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'SustainWise',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'LoraItalic',
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              fontSize: 32,
              letterSpacing: 0,
              color: Colors.white,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Master the language of sustainability',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // A small, deliberately understated icon-only button — not a labeled
  // pill like its neighbors — so a destructive action doesn't visually
  // compete with the streak/XP stats it sits between. Same confirmation
  // dialog as Profile's "Reset progress" row, via the shared helper, so
  // the two entry points can never drift apart.
  Widget _resetIconButton(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        key: const Key('home-reset-progress-button'),
        customBorder: const CircleBorder(),
        onTap: () {
          AppFeedback.tap();
          showResetProgressDialog(context);
        },
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.restart_alt, size: 17, color: Colors.white),
        ),
      ),
    );
  }

  String _formatXp(int xp) {
    final s = xp.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  /// The icon carries the accent color; the number always stays white so it
  /// reads clearly against the dark hero regardless of which accent is used
  /// (amber-on-translucent-teal was too low-contrast on its own).
  Widget _pill(
    IconData icon,
    int value,
    Color iconColor, {
    String Function(int)? formatter,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 6),
          AnimatedCounterText(
            value: value,
            formatter: formatter,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// The single dominant "what do I do now" card, placed above the full
  /// path — a returning learner needs the answer to that question before
  /// seeing every module at once, not after. Points at whichever module is
  /// currently unlocked-and-not-yet-done; if every module is finished, it
  /// points at the Expert Challenge instead of showing a dead end.
  Widget _buildContinueLearningCard(BuildContext context) {
    final next = _nextModule();
    if (next == null) {
      // Two distinct "nothing left to do" states — every module done but
      // the Expert Challenge still waiting, versus genuinely everything
      // done. Showing the Expert Challenge nudge after it's already been
      // completed would be a stale, self-contradicting instruction.
      final expertDone = ProgressStore.instance.expertChallengeCompleted;
      return Container(
        key: const Key('continue-learning-card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              expertDone ? Icons.emoji_events : Icons.workspace_premium,
              color: AppColors.amberDeep,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                expertDone
                    ? "You've completed the entire curriculum — every module and the Expert Challenge. Nice work."
                    : "You've finished every module — try the Expert Challenge below.",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.amberDeep,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Only true before the very first module has ever been completed — from
    // that point on there really is something to continue, so the card
    // reverts to "CONTINUE" for the rest of the app's lifetime.
    final isFirstEver = ProgressStore.instance.completedModulesCount == 0;
    return Material(
      key: const Key('continue-learning-card'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _onModuleTap(context, next),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFirstEver ? 'GET STARTED' : 'CONTINUE LEARNING',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.tealDeep,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      next.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${next.termCount} terms · ~${(next.termCount * 0.5).ceil()} min',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFirstEver ? 'START' : 'CONTINUE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ModuleProgress? _nextModule() {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        if (ProgressStore.instance.statusFor(module.id) ==
            ModuleStatus.current) {
          return module;
        }
      }
    }
    return null;
  }

  /// Explains the product in the hero itself instead of a stats widget —
  /// answers "what even is this" for a first-time or occasional visitor,
  /// with a wink instead of a dry mission statement.
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duolingo for Sustainability Speak',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Duolingo taught the world Spanish. This teaches you to '
            'survive a CSRD meeting. Fifteen minutes a day, real '
            "definitions — and yes, it actually sticks.",
            style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          const _HowItWorksSection(),
        ],
      ),
    );
  }

  /// The daily-goal ring Duolingo is built around — a target that resets
  /// every day, giving a reason to open the app today specifically, not
  /// just "eventually". Judged against the learner's own goal, never
  /// against other users.
  Widget _buildDailyGoalCard() {
    final today = ProgressStore.instance.todayXp;
    final met = ProgressStore.instance.dailyGoalMet;
    final progress = (today / ProgressStore.dailyGoalXp).clamp(0.0, 1.0);
    return Container(
      key: const Key('daily-goal-card'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // The mascot standing in for the old plain track_changes icon —
          // happy once today's goal is met, a little worried if the streak
          // has actually lapsed, otherwise a neutral "still to do today".
          Mascot(
            mood: met
                ? MascotMood.happy
                : ProgressStore.instance.streakDays == 0
                ? MascotMood.worried
                : MascotMood.neutral,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily goal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.ink,
                      ),
                    ),
                    met
                        ? const Text(
                            'Goal reached!',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.success,
                            ),
                          )
                        : AnimatedCounterText(
                            value: today,
                            formatter: (v) =>
                                '$v/${ProgressStore.dailyGoalXp} XP',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: AnimatedProgressBar(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: met ? AppColors.success : AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Only rendered once there's actually something to revisit — a term
  /// leaves the queue the moment it's answered correctly again, so this
  /// naturally disappears once a learner has caught up on their mistakes,
  /// rather than sitting there as a permanent, ignorable fixture.
  Widget _buildMistakesCard(BuildContext context) {
    final count = ProgressStore.instance.missedCount;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      key: const Key('mistakes-card'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AppFeedback.tap();
            Navigator.of(context).push(
              appRoute(
                ReviewScreen(
                  questions: MockData.reviewQuizFor(
                    ProgressStore.instance.missedTermIds,
                  ),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.amberDeep.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.replay, color: AppColors.amberDeep, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$count term${count == 1 ? '' : 's'} to revisit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.amberDeep,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.amberDeep,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Living content instead of static content" — a live, in-app read of
  /// which real regulatory dates are close, computed fresh against
  /// [DateTime.now()] on every open rather than baked into a fixed lesson.
  /// No push notifications/background scheduler needed for this: the same
  /// bundled dates just read differently depending on when you look.
  /// Renders nothing once nothing is in the ~200-day window either side of
  /// today, rather than showing a permanently-empty card.
  Widget _buildRegulatoryRadarCard(BuildContext context) {
    final milestones = MockData.radarMilestones();
    if (milestones.isEmpty) return const SizedBox.shrink();
    final nearest = milestones.first;
    final module = MockData.moduleById(nearest.moduleId);
    return Container(
      key: const Key('regulatory-radar-card'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.violetDeep.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('regulatory-radar-card-tap'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AppFeedback.tap();
            Navigator.of(context).push(appRoute(const RegulatoryRadarScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.violetDeep.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, color: AppColors.violetDeep, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'REGULATORY RADAR',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.violetDeep,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _radarRelativeLabel(nearest.date),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.violetDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nearest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.ink,
                        ),
                      ),
                      if (module != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          module.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (milestones.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.violetDeep.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '+${milestones.length - 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.violetDeep,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.violetDeep,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _radarRelativeLabel(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    if (days == 0) return 'TODAY';
    return days > 0 ? 'IN ${days}D' : '${-days}D AGO';
  }

  /// Each unit is a floating card on the same neutral background as the
  /// hero — a colored icon badge carries the accent instead of a full-bleed
  /// tint block, so the page reads as one connected surface rather than a
  /// stack of glued-together colored panels. Every unit gets its own hue
  /// (cycled from [AppColors.unitAccents] by position) so the path reads as
  /// a set of distinct topics rather than one repeated dark-green block.
  Widget _buildUnitSection(BuildContext context, LearningUnit unit, int index) {
    final palette = AppColors.unitAccents[index % AppColors.unitAccents.length];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(unit.icon, color: palette.deep, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UnitEyebrow(title: unit.title, palette: palette),
                    const SizedBox(height: 7),
                    Text(
                      unit.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${unit.totalTerms} terms · ${unit.modules.length} modules',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.deep,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < unit.modules.length; i++) ...[
            ModulePathNode(
              module: unit.modules[i].copyWith(
                status: ProgressStore.instance.statusFor(unit.modules[i].id),
              ),
              onTap: () => _onModuleTap(context, unit.modules[i]),
              doneFill: palette.fill,
              doneRim: palette.deep,
              lockedFill: palette.soft,
            ),
            if (i != unit.modules.length - 1)
              _VineConnector(color: palette.deep),
          ],
        ],
      ),
    );
  }

  /// Sits below every unit, styled apart from the regular teal path — an
  /// amber, trophy-badged card once every module is done, or a plainly
  /// locked one before that, so it reads as an earned bonus round rather
  /// than just one more module.
  Widget _buildExpertChallengeCard(BuildContext context) {
    final unlocked = ProgressStore.instance.expertChallengeUnlocked;
    final completed = ProgressStore.instance.expertChallengeCompleted;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: unlocked ? AppColors.amberSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: const Key('expert-challenge-card'),
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            AppFeedback.tap();
            _onExpertChallengeTap(context);
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: unlocked
                    ? AppColors.amberDeep.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked ? AppColors.amber : AppColors.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    unlocked ? Icons.workspace_premium : Icons.lock_outline,
                    color: unlocked ? Colors.white : AppColors.inkSoft,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Expert Challenge',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                              color: unlocked
                                  ? AppColors.amberDeep
                                  : AppColors.ink,
                            ),
                          ),
                          if (completed) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unlocked
                            ? '${MockData.expertChallenge.length} very hard questions across every topic — thresholds, edge cases, the fine print.'
                            : 'Complete every module above to unlock ${MockData.expertChallenge.length} expert-level questions.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.inkSoft,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  unlocked ? Icons.chevron_right : Icons.lock_outline,
                  color: unlocked ? AppColors.amberDeep : AppColors.inkSoft,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyrightFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Text(
          '© 2026 Jordi Lesaffer · Novarisq Consulting',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  void _onExpertChallengeTap(BuildContext context) {
    if (!ProgressStore.instance.expertChallengeUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Locked — complete every module above first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).push(appRoute(const ExpertChallengeScreen()));
  }

  Widget _buildBottomNav(BuildContext context) {
    return AppBottomNav(
      current: AppTab.path,
      onPathTap: () {},
      onGlossaryTap: () =>
          Navigator.of(context).push(appRoute(const GlossaryScreen())),
      onStatsTap: () =>
          Navigator.of(context).push(appRoute(const StatsScreen())),
      onProfileTap: () =>
          Navigator.of(context).push(appRoute(const ProfileScreen())),
    );
  }

  void _onModuleTap(BuildContext context, ModuleProgress module) {
    final status = ProgressStore.instance.statusFor(module.id);
    // On web, a visitor is typically here once for a specific topic, not
    // working through the app's day-by-day unlock progression — so every
    // module opens directly, regardless of status. The native app keeps
    // the real gate.
    if (!kIsWeb && status == ModuleStatus.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Locked — finish the module above to unlock "${module.title}"',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    // A completed module isn't a second "continue here" — only the single
    // current module opens a lesson directly. Tapping a done one points to
    // the Glossary instead, which is the actual tool for revisiting terms.
    if (status == ModuleStatus.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Already completed — look up any of its terms any time in Glossary',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      appRoute(
        LessonScreen(deck: MockData.lessonFor(module.id), moduleId: module.id),
      ),
    );
  }
}

/// A small cue that tells a first-time visitor there's more below the fold
/// — the hero alone can fill the viewport on shorter phones, and nothing
/// before this hinted that scrolling was necessary. The chevron nudges down
/// once on appearance (a one-shot implicit animation, not a perpetual
/// ticker) rather than looping forever.
class _ScrollHint extends StatelessWidget {
  const _ScrollHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            'Your path continues below',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppColors.inkSoft.withValues(alpha: 0.85),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, t, child) {
              final bounce = t < 1 ? (0.5 - (t - 0.5).abs()) * 2 : 0.0;
              return Transform.translate(
                offset: Offset(0, bounce * 5),
                child: child,
              );
            },
            child: const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.teal,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// A collapsed-by-default explainer for how a lesson actually plays out —
/// flashcards, then quiz, then confusable pairs — so a first-time user can
/// check it without it permanently eating space on the hero.
class _HowItWorksSection extends StatefulWidget {
  const _HowItWorksSection();

  @override
  State<_HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<_HowItWorksSection> {
  bool _expanded = false;

  static const _steps = [
    'Flip each flashcard to reveal its definition, then rate yourself '
        '"Still learning" or "Got it".',
    'Answer the quiz — a wrong pick still shows the correct definition and why.',
    'Tell the confusable pairs apart: a clue statement, you pick which of '
        'two easily-mixed-up terms it actually describes.',
    'Finish a lesson to grow your streak and XP — experience points that '
        'track how much you\'ve practiced. Modules unlock one at a time, '
        'in order.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('how-it-works-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Walk me through it',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tealDeep,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.tealDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == _steps.length - 1 ? 0 : 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.tealDeep,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _steps[i],
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// A short colored stem between two module rows — the path used to be a
/// list of otherwise-unrelated buttons; this literally connects them into
/// one continuous line, so it reads as a garden path growing downward
/// rather than a stack of separate cards.
class _VineConnector extends StatelessWidget {
  const _VineConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

/// Splits "Unit N · Topic" into a small colored "UNIT N" eyebrow pill and a
/// larger, bolder topic headline — a single plain-weight line read as just
/// another sentence of body copy; separating the two gives each unit a
/// clearly accented, colored section start to spot while scrolling.
class _UnitEyebrow extends StatelessWidget {
  const _UnitEyebrow({required this.title, required this.palette});

  final String title;
  final UnitAccent palette;

  @override
  Widget build(BuildContext context) {
    final parts = title.split(' · ');
    final label = parts.length > 1 ? parts.first : null;
    final topic = parts.length > 1 ? parts.sublist(1).join(' · ') : title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: palette.deep,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          topic,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
