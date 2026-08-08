import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/progress_ring.dart';
import '../widgets/week_activity_chart.dart';
import 'stats_screen.dart';

/// Profile & stats — ported from the mockup's `#view-profile`. Combines the
/// learner's progress (modules ring, week activity, streak/XP) with the
/// app's one lead-gen touchpoint: a free greenwashing-scan offer.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                  _buildStatGrid(),
                  const SizedBox(height: 20),
                  _buildSettingsList(context),
                  const SizedBox(height: 20),
                  _buildCopyright(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            current: AppTab.profile,
            onPathTap: () => Navigator.of(context).pop(),
            onStatsTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
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
          child: const Text(
            'JL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jordi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            SizedBox(height: 2),
            Text('Level 4 · Sustainability Learner', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          ],
        ),
      ],
    );
  }

  Widget _buildXpBar() {
    final progress = (ProgressStore.instance.totalXp / 2000).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 7,
        backgroundColor: AppColors.border,
        valueColor: const AlwaysStoppedAnimation(AppColors.teal),
      ),
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
          const Expanded(child: WeekActivityChart(days: _weekActivity)),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Row(
      children: [
        Expanded(child: _StatTile(value: '${ProgressStore.instance.streakDays}', label: 'day streak')),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(value: '${ProgressStore.instance.completedTermsCount}', label: 'terms learned')),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(value: _formatXp(ProgressStore.instance.totalXp), label: 'total XP')),
      ],
    );
  }

  String _formatXp(int xp) {
    final s = xp.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  Widget _buildSettingsList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _settingsRow(context, 'Notifications', 'Daily, 6:00pm'),
          _settingsRow(context, 'Language', 'English'),
          _settingsRow(context, 'Sign out', '›'),
        ],
      ),
    );
  }

  Widget _settingsRow(BuildContext context, String label, String value) {
    return InkWell(
      onTap: () => showComingSoon(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.ink, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyright() {
    return Center(
      child: Text(
        '© 2026 Jordi Lesaffer · Novarisq Consulting',
        style: TextStyle(fontSize: 11, color: AppColors.inkSoft.withValues(alpha: 0.75)),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

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
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.tealDeep),
          ),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
