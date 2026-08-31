import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A one-shot confetti burst reserved for genuine milestones — plays once
/// on entry and stops, rather than looping forever, so it never blocks
/// `pumpAndSettle` in tests and doesn't distract once the moment has
/// landed. Wraps [child] when given (e.g. a ring or badge the confetti
/// should burst around); with no child, it's a free-floating overlay burst
/// you can drop over any other moment worth celebrating.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.child, this.size = 260});

  final Widget? child;
  final double size;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _particles = [
    _Particle(
      dx: -95,
      startDy: -70,
      endDy: 95,
      color: AppColors.amber,
      delay: 0.00,
      size: 8,
      spin: 3.6,
    ),
    _Particle(
      dx: -65,
      startDy: -100,
      endDy: 75,
      color: AppColors.teal,
      delay: 0.04,
      size: 6,
      spin: -3.0,
    ),
    _Particle(
      dx: -35,
      startDy: -60,
      endDy: 115,
      color: AppColors.success,
      delay: 0.08,
      size: 7,
      spin: 4.2,
    ),
    _Particle(
      dx: 0,
      startDy: -115,
      endDy: 60,
      color: AppColors.amberDeep,
      delay: 0.02,
      size: 6,
      spin: -2.6,
    ),
    _Particle(
      dx: 32,
      startDy: -80,
      endDy: 105,
      color: AppColors.tealDeep,
      delay: 0.10,
      size: 8,
      spin: 3.2,
    ),
    _Particle(
      dx: 65,
      startDy: -60,
      endDy: 85,
      color: AppColors.amber,
      delay: 0.06,
      size: 6,
      spin: -3.8,
    ),
    _Particle(
      dx: 95,
      startDy: -100,
      endDy: 68,
      color: AppColors.teal,
      delay: 0.12,
      size: 7,
      spin: 3.0,
    ),
    _Particle(
      dx: -110,
      startDy: -30,
      endDy: 135,
      color: AppColors.success,
      delay: 0.16,
      size: 6,
      spin: -4.0,
    ),
    _Particle(
      dx: 110,
      startDy: -40,
      endDy: 125,
      color: AppColors.amberDeep,
      delay: 0.14,
      size: 7,
      spin: 3.6,
    ),
    _Particle(
      dx: -15,
      startDy: -90,
      endDy: 100,
      color: AppColors.tealBright,
      delay: 0.20,
      size: 6,
      spin: -3.2,
    ),
    _Particle(
      dx: 48,
      startDy: -50,
      endDy: 110,
      color: AppColors.amber,
      delay: 0.18,
      size: 8,
      spin: 4.4,
    ),
    _Particle(
      dx: -75,
      startDy: -20,
      endDy: 145,
      color: AppColors.teal,
      delay: 0.22,
      size: 6,
      spin: -2.8,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final half = widget.size / 2;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final p in _particles)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Interval(
                  p.delay,
                  math.min(p.delay + 0.75, 1.0),
                ).transform(_controller.value);
                final fall = Curves.easeIn.transform(t);
                final fade = t < 0.75
                    ? 1.0
                    : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
                return Positioned(
                  left: half + p.dx,
                  top: half + p.startDy + fall * (p.endDy - p.startDy),
                  child: Opacity(
                    opacity: t <= 0 ? 0 : fade,
                    child: Transform.rotate(
                      angle: fall * p.spin,
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.dx,
    required this.startDy,
    required this.endDy,
    required this.color,
    required this.delay,
    required this.size,
    required this.spin,
  });

  final double dx;
  final double startDy;
  final double endDy;
  final Color color;
  final double delay;
  final double size;
  final double spin;
}

/// A bigger, full-width "cloud" reserved for the single biggest moment in
/// the app — finishing every module plus the Expert Challenge. Meant to be
/// laid over the whole screen (e.g. via `Positioned.fill`), unlike
/// [ConfettiBurst], which bursts around one widget it wraps.
class ConfettiCloud extends StatefulWidget {
  const ConfettiCloud({super.key, this.count = 34});

  final int count;

  @override
  State<ConfettiCloud> createState() => _ConfettiCloudState();
}

class _ConfettiCloudState extends State<ConfettiCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_CloudParticle> _particles;

  static const _colors = [
    AppColors.teal,
    AppColors.tealBright,
    AppColors.amber,
    AppColors.amberDeep,
    AppColors.success,
    AppColors.tealDeep,
  ];

  @override
  void initState() {
    super.initState();
    // A fixed seed — reproducible rather than genuinely random, the same
    // deterministic spirit as ConfettiBurst's hand-placed list, just too
    // many particles here to hand-write one by one.
    final rnd = math.Random(7);
    _particles = List.generate(
      widget.count,
      (i) => _CloudParticle(
        leftFraction: rnd.nextDouble(),
        color: _colors[rnd.nextInt(_colors.length)],
        delay: rnd.nextDouble() * 0.45,
        size: 6 + rnd.nextDouble() * 6,
        spin: (rnd.nextBool() ? 1 : -1) * (2.5 + rnd.nextDouble() * 2.2),
      ),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            for (final p in _particles)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = Interval(
                    p.delay,
                    math.min(p.delay + 0.7, 1.0),
                  ).transform(_controller.value);
                  final fall = Curves.easeIn.transform(t);
                  final fade = t < 0.8
                      ? 1.0
                      : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
                  return Positioned(
                    left: p.leftFraction * width,
                    top: -30 + fall * (height + 60),
                    child: Opacity(
                      opacity: t <= 0 ? 0 : fade,
                      child: Transform.rotate(
                        angle: fall * p.spin,
                        child: Container(
                          width: p.size,
                          height: p.size * 1.6,
                          decoration: BoxDecoration(
                            color: p.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _CloudParticle {
  const _CloudParticle({
    required this.leftFraction,
    required this.color,
    required this.delay,
    required this.size,
    required this.spin,
  });

  final double leftFraction;
  final Color color;
  final double delay;
  final double size;
  final double spin;
}
