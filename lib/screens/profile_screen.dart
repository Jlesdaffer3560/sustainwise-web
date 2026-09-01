import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../web/responsive.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_route.dart';
import '../widgets/progress_ring.dart';
import '../widgets/reset_progress_dialog.dart';
import '../widgets/week_activity_chart.dart';
import 'glossary_screen.dart';
import 'stats_screen.dart';

/// Profile & stats — ported from the mockup's `#view-profile`. Combines the
/// learner's progress (modules ring, week activity, streak/XP) with the
/// app's one lead-gen touchpoint: a free greenwashing-scan offer.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildXpBar(),
                  const SizedBox(height: 20),
                  _buildChartsCard(),
                  const SizedBox(height: 16),
                  _buildFluencyCard(),
                  const SizedBox(height: 16),
                  _buildStatGrid(),
                  const SizedBox(height: 20),
                  _buildAchievements(),
                  const SizedBox(height: 20),
                  _buildSettingsList(context),
                  const SizedBox(height: 20),
                  _buildCopyright(),
                ],
              ),
            ),
          ),
          // On web, tab navigation lives in the sidebar (DesktopShell) —
          // but only once there's room for one.
          bottomNavigationBar: isDesktopWeb(context)
              ? null
              : AppBottomNav(
                  current: AppTab.profile,
                  onPathTap: () => Navigator.of(context).pop(),
                  onGlossaryTap: () => Navigator.of(
                    context,
                  ).pushReplacement(appRoute(const GlossaryScreen())),
                  onStatsTap: () => Navigator.of(
                    context,
                  ).pushReplacement(appRoute(const StatsScreen())),
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
              'You',
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
          formatter: (v) =>
              '$v/${store.xpPerLevel} XP to level ${store.level + 1}',
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
          // A week-activity chart is near-empty for a one-time web
          // visitor — swapped for a plain read of overall completion
          // instead. Native keeps the real weekly chart. Labeled "Your
          // progress", not "This visit" — completed/total is the same
          // persisted browser-local progress shown everywhere else on
          // this page, not scoped to the current session.
          Expanded(
            child: kIsWeb
                ? Column(
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
                  )
                : WeekActivityChart(
                    days: buildWeekActivity(
                      xpPerDay: ProgressStore.instance.thisWeekXp,
                      todayIndex: ProgressStore.instance.todayWeekdayIndex,
                      goalXp: ProgressStore.dailyGoalXp,
                    ),
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
    final accents = unitAccentsFor(kIsWeb);
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
        // A day-streak tile is either 0 or 1 for a one-time web visitor —
        // never the meaningful number it is in the native app. Dropped
        // rather than shown alongside two tiles that are genuinely
        // informative either way.
        if (!kIsWeb) ...[
          Expanded(
            child: _StatTile(
              value: ProgressStore.instance.streakDays,
              label: 'day streak',
            ),
          ),
          const SizedBox(width: 8),
        ],
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
            label: 'total XP',
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

  /// Badges judged only against the learner's own history — streaks,
  /// modules, the Expert Challenge — never against other users, since this
  /// app has no accounts or backend to compare against.
  Widget _buildAchievements() {
    // The two streak-length badges (7-day, 30-day) can never unlock within
    // a single web visit — they'd sit permanently locked, which reads as
    // broken rather than aspirational the way it does in an app someone
    // returns to daily. Native shows the full set unchanged.
    final achievements = kIsWeb
        ? ProgressStore.instance.achievements
              .where((a) => a.id != 'week-streak' && a.id != 'month-streak')
              .toList()
        : ProgressStore.instance.achievements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievements',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: kIsWeb ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // Extra headroom over a tighter ratio — a 2-line title at larger
          // accessibility text sizes needs the room, since this grid can't
          // scroll to absorb overflow.
          childAspectRatio: kIsWeb ? 1.5 : 0.74,
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
          // AppFeedback._play() is suppressed entirely on web (a website
          // playing sounds on tap reads as broken, not delightful) — this
          // toggle would otherwise be a dead control with no audible
          // effect either way, same reasoning as hiding Notifications.
          if (!kIsWeb) _buildSoundToggleRow(),
          // The daily reminder is built on flutter_local_notifications'
          // zonedSchedule(), which throws UnsupportedError on the web
          // platform — hide the row on web rather than expose a control
          // that always fails to save.
          if (!kIsWeb) _buildNotificationsRow(context),
          _settingsRow(context, 'Language', 'English'),
          _buildResetProgressRow(context),
        ],
      ),
    );
  }

  Widget _buildSoundToggleRow() {
    final enabled = ProgressStore.instance.soundEnabled;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sound effects',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          Switch(
            key: const Key('sound-toggle'),
            value: enabled,
            activeThumbColor: AppColors.teal,
            onChanged: (value) {
              AppFeedback.tap();
              ProgressStore.instance.setSoundEnabled(value);
            },
          ),
        ],
      ),
    );
  }

  /// A once-a-day local reminder — genuinely wired to
  /// [NotificationService], not a stub. The row's own value line always
  /// reflects the real, persisted state ("Off" / "Daily, 6:00 PM"), so it
  /// never claims a schedule that isn't actually active.
  Widget _buildNotificationsRow(BuildContext context) {
    final store = ProgressStore.instance;
    final enabled = store.notificationsEnabled;
    return InkWell(
      key: const Key('notifications-row'),
      onTap: () {
        AppFeedback.tap();
        _showNotificationsSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              enabled
                  ? 'Daily, ${_formatTime(store.notificationHour, store.notificationMinute)}'
                  : 'Off',
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $period';
  }

  /// A bottom sheet rather than an immediate toggle: turning this on also
  /// means requesting a runtime permission (Android 13+) and picking a
  /// time, which doesn't fit a single tap the way "Sound effects" does.
  Future<void> _showNotificationsSheet(BuildContext context) async {
    final store = ProgressStore.instance;
    var enabled = store.notificationsEnabled;
    var hour = store.notificationHour;
    var minute = store.notificationMinute;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // SafeArea, not just the keyboard-inset padding above — without
            // it, the Save button rendered right up against (or under) the
            // system nav bar on devices with 3-button/gesture navigation,
            // barely visible and awkward to tap.
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily reminder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Switch(
                          key: const Key('notifications-toggle'),
                          value: enabled,
                          activeThumbColor: AppColors.teal,
                          onChanged: (value) async {
                            if (!value) {
                              setSheetState(() => enabled = false);
                              return;
                            }
                            bool granted;
                            try {
                              granted = await NotificationService.instance
                                  .requestPermission();
                            } catch (e) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Couldn't request notification permission ($e).",
                                    ),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                              return;
                            }
                            if (!granted) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Notifications permission was denied — enable it in your phone's settings to use this.",
                                    ),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                              return;
                            }
                            setSheetState(() => enabled = true);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A daily practice reminder at a time you choose — once a day, regardless of whether you already practiced.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
                    ),
                    if (enabled) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        key: const Key('notifications-time-row'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: sheetContext,
                            initialTime: TimeOfDay(hour: hour, minute: minute),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              hour = picked.hour;
                              minute = picked.minute;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                _formatTime(hour, minute),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.tealDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('notifications-save-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          // The platform call goes first, and only a
                          // success persists the setting — a silent
                          // scheduling failure must never leave the UI
                          // claiming "Daily, 6:00 PM" when nothing was
                          // actually scheduled. Any platform-side error
                          // (rejected by the OS, a plugin/channel failure)
                          // is caught here instead of crashing the app.
                          try {
                            if (enabled) {
                              // Re-verified on every Save, not just the
                              // toggle's off->on transition — Android
                              // resets this runtime permission on every
                              // reinstall, and the switch can still read
                              // "on" from a previous session even though
                              // the OS has since revoked it. Scheduling
                              // an alarm without it "succeeds" (the
                              // alarm fires) but the OS silently drops
                              // the notification itself.
                              final granted = await NotificationService.instance
                                  .requestPermission();
                              if (!granted) {
                                if (sheetContext.mounted) {
                                  setSheetState(() => enabled = false);
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Notifications permission isn't granted — enable it in your phone's settings to use this.",
                                      ),
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                                return;
                              }
                              await NotificationService.instance.scheduleDaily(
                                hour: hour,
                                minute: minute,
                                body: NotificationService.instance.reminderBody(
                                  store.streakDays,
                                ),
                              );
                            } else {
                              await NotificationService.instance.cancelDaily();
                            }
                            await store.setNotificationSettings(
                              enabled: enabled,
                              hour: hour,
                              minute: minute,
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          } catch (e) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Couldn't save the reminder ($e) — please try again.",
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Destructive, so it's confirmed rather than fired on a single tap — a
  /// learner asking to "start over" should get exactly that, not a silent
  /// irreversible wipe from one mis-tap.
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
