import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/progress_ring.dart';
import '../widgets/week_activity_chart.dart';
import 'profile_screen.dart';

/// Stats — the detail view behind the numbers Home/Profile only summarize:
/// the week's activity at a glance, overall accuracy, and a per-unit
/// breakdown of exactly how far along each part of the path is.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _weekActivity = [
    DayActivity('Mo', 0.35),
    DayActivity('Tu', 0.55),
    DayActivity('We', 0.0),
    DayActivity('Th', 0.70),
    DayActivity('Fr', 0.45),
    DayActivity('Sa', 0.85),
    DayActivity('Su', 1.0, isToday: true),
  ];

  @override
  Widget build(BuildContext context) {
    final activeDays = _weekActivity.where((d) => d.level > 0).length;

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
                const Text('Your stats', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text(
                  'How your practice is trending, and how far you are on the path.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4),
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
                        caption: 'Best: ${ProgressStore.instance.longestStreak} days',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeadlineTile(
                        icon: Icons.gps_fixed,
                        iconColor: AppColors.teal,
                        value: '${MockData.overallAccuracy.round()}%', // not yet tracked per-session
                        label: 'overall accuracy',
                        caption: 'Across all quizzes',
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
                          const Text('This week', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Text(
                            '$activeDays/7 days',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const WeekActivityChart(days: _weekActivity, trackHeight: 56),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Progress by unit', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 12),
                for (final unit in MockData.units) _buildUnitProgress(unit),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          current: AppTab.stats,
          onPathTap: () => Navigator.of(context).pop(),
          onStatsTap: () {},
          onProfileTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildUnitProgress(LearningUnit unit) {
    final completed = unit.modules.where((m) => ProgressStore.instance.statusFor(m.id) != ModuleStatus.available).length;
    final total = unit.modules.length;
    final termsLearned = unit.modules
        .where((m) => ProgressStore.instance.statusFor(m.id) != ModuleStatus.available)
        .fold(0, (sum, m) => sum + m.termCount);
    final accent = unit.tint == AppColors.amberSoft ? AppColors.amberDeep : AppColors.tealDeep;
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
                Text(unit.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(
                  '$termsLearned/${unit.totalTerms} terms learned',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
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
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.ink)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
