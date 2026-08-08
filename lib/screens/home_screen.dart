import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/module_path_node.dart';
import 'lesson_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const Key('module-path-scroll'),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                _buildHero(context),
                const _ScrollHint(),
                for (final unit in MockData.units) _buildUnitSection(context, unit),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /// The hero now lives as the first card in the same scroll surface as the
  /// path below it — one continuous canvas, rather than a fixed banner
  /// glued on top of a separately-colored scrolling area.
  Widget _buildHero(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealDeep, AppColors.teal],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pill(Icons.local_fire_department, '${ProgressStore.instance.streakDays}', AppColors.amber),
              _pill(Icons.star, _formatXp(ProgressStore.instance.totalXp), Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'SustainWise',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30, color: Colors.white, height: 1.05),
          ),
          const SizedBox(height: 4),
          Text(
            'Master the language of sustainability.',
            style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          _buildIntroCard(),
        ],
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
  Widget _pill(IconData icon, String value, Color iconColor) {
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
        ],
      ),
    );
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duolingo for sustainability speak.',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bite-sized daily lessons that turn CSRD, SDGs and SFDR jargon '
            'into second nature — for sustainability pros, and for anyone '
            'who nods along in sustainability meetings without quite following.',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _AudienceChip('Sustainability pros'),
              _AudienceChip('Compliance & finance'),
              _AudienceChip('ESG-curious'),
            ],
          ),
        ],
      ),
    );
  }

  /// Each unit is a floating card on the same neutral background as the
  /// hero — a colored icon badge carries the accent instead of a full-bleed
  /// tint block, so the page reads as one connected surface rather than a
  /// stack of glued-together colored panels.
  Widget _buildUnitSection(BuildContext context, LearningUnit unit) {
    final accent = _accentFor(unit);
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
                decoration: BoxDecoration(color: unit.tint, borderRadius: BorderRadius.circular(14)),
                child: Icon(unit.icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(
                      unit.description,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${unit.totalTerms} terms · ${unit.modules.length} modules',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < unit.modules.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == unit.modules.length - 1 ? 0 : 14),
              child: ModulePathNode(
                module: unit.modules[i].copyWith(status: ProgressStore.instance.statusFor(unit.modules[i].id)),
                onTap: () => _onModuleTap(context, unit.modules[i]),
              ),
            ),
        ],
      ),
    );
  }

  Color _accentFor(LearningUnit unit) {
    return unit.tint == AppColors.amberSoft ? AppColors.amberDeep : AppColors.tealDeep;
  }

  Widget _buildBottomNav(BuildContext context) {
    return AppBottomNav(
      current: AppTab.path,
      onPathTap: () {},
      onStatsTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
      onProfileTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
    );
  }

  void _onModuleTap(BuildContext context, ModuleProgress module) {
    if (ProgressStore.instance.statusFor(module.id) == ModuleStatus.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${module.title} — not started yet'), duration: const Duration(seconds: 1)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonScreen(deck: MockData.lessonFor(module.id), moduleId: module.id)),
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
              return Transform.translate(offset: Offset(0, bounce * 5), child: child);
            },
            child: const Icon(Icons.keyboard_arrow_down, color: AppColors.teal, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tealDeep),
      ),
    );
  }
}
