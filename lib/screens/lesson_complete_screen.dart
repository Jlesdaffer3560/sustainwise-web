import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_ring.dart';

/// The reward screen at the end of a lesson — ported from the mockup's
/// `#view-complete`. Shows accuracy on the same [ProgressRing] used
/// elsewhere, a one-shot confetti burst, and the lesson's stats.
class LessonCompleteScreen extends StatelessWidget {
  const LessonCompleteScreen({super.key, required this.correct, required this.total});

  final int correct;
  final int total;

  static const int _xpEarned = 15;

  @override
  Widget build(BuildContext context) {
    final accuracy = total == 0 ? 0.0 : (correct / total) * 100;
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ConfettiRing(
                  child: ProgressRing(
                    percent: accuracy,
                    centerValue: '${accuracy.round()}%',
                    centerLabel: 'accuracy',
                    size: 132,
                    fillColor: accuracy >= 100 ? AppColors.success : AppColors.teal,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Lesson complete!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  '+$_xpEarned XP · ${ProgressStore.instance.streakDays}-day streak',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatTile(value: '$correct/$total', label: 'correct'),
                    const SizedBox(width: 10),
                    _StatTile(value: '${ProgressStore.instance.completedTermsCount}', label: 'terms learned'),
                    const SizedBox(width: 10),
                    _StatTile(
                      value: '${ProgressStore.instance.completedModulesCount}/${ProgressStore.instance.totalModulesCount}',
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
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
            Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.tealDeep),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-shot confetti burst around the ring — plays once on entry and
/// stops, rather than looping forever, so it never blocks `pumpAndSettle`
/// in tests and doesn't distract once the celebratory moment has landed.
class _ConfettiRing extends StatefulWidget {
  const _ConfettiRing({required this.child});

  final Widget child;

  @override
  State<_ConfettiRing> createState() => _ConfettiRingState();
}

class _ConfettiRingState extends State<_ConfettiRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _particles = [
    _Particle(dx: -60, dy: 8, color: AppColors.amber, delay: 0.0),
    _Particle(dx: 58, dy: -4, color: AppColors.teal, delay: 0.05),
    _Particle(dx: -52, dy: 46, color: AppColors.success, delay: 0.1),
    _Particle(dx: 60, dy: 50, color: AppColors.amber, delay: 0.15),
    _Particle(dx: 4, dy: -28, color: AppColors.teal, delay: 0.08),
    _Particle(dx: 10, dy: 62, color: AppColors.success, delay: 0.18),
    _Particle(dx: -30, dy: -18, color: AppColors.amberDeep, delay: 0.12),
    _Particle(dx: 34, dy: 18, color: AppColors.tealDeep, delay: 0.2),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final p in _particles)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Interval(p.delay, math.min(p.delay + 0.6, 1.0)).transform(_controller.value);
                final rise = Curves.easeOut.transform(t);
                final fade = 1 - Curves.easeIn.transform(t);
                return Positioned(
                  left: 100 + p.dx,
                  top: 100 + p.dy - rise * 46,
                  child: Opacity(
                    opacity: t <= 0 ? 0 : fade.clamp(0, 1),
                    child: Transform.rotate(
                      angle: rise * 3.4,
                      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(2))),
                    ),
                  ),
                );
              },
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _Particle {
  const _Particle({required this.dx, required this.dy, required this.color, required this.delay});

  final double dx;
  final double dy;
  final Color color;
  final double delay;
}
