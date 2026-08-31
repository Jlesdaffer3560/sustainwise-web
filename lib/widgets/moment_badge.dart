import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Which small, one-shot "micro-moment" this badge celebrates. Each has its
/// own distinct motion — a drawn checkmark, a flickering flame, a bursting
/// star with a floating XP label, or a dropped-in medal — rather than one
/// generic pop reused everywhere, so the moment it marks stays legible.
enum MomentType { check, flame, star, medal }

/// A small, self-contained celebratory badge for a specific in-app moment
/// (a term mastered, a streak day logged, XP earned, a perfect score) —
/// the "Lottie-style" layer sitting between plain haptics/sound and the
/// bigger [MilestoneMoment] overlay reserved for genuine milestones.
///
/// Plays once on mount and settles into its resting frame — never loops —
/// so it never blocks `pumpAndSettle` in tests, matching [Mascot] and
/// [ConfettiBurst].
class MomentBadge extends StatefulWidget {
  const MomentBadge({
    super.key,
    required this.type,
    this.size = 44,
    this.xpLabel,
  });

  final MomentType type;
  final double size;

  /// Only meaningful for [MomentType.star] — the text ("+15 XP") that
  /// floats up and fades above the badge.
  final String? xpLabel;

  @override
  State<MomentBadge> createState() => _MomentBadgeState();
}

class _MomentBadgeState extends State<MomentBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: switch (widget.type) {
        MomentType.check => const Duration(milliseconds: 550),
        MomentType.flame => const Duration(milliseconds: 750),
        MomentType.star => const Duration(milliseconds: 950),
        MomentType.medal => const Duration(milliseconds: 600),
      },
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => switch (widget.type) {
        MomentType.check => _buildCheck(),
        MomentType.flame => _buildFlame(),
        MomentType.star => _buildStar(),
        MomentType.medal => _buildMedal(),
      },
    );
  }

  Widget _ring(Color fill, Widget child) {
    // The ring itself pops in with the same elastic entrance every variant
    // shares — only what's drawn inside it differs.
    final pop = Curves.elasticOut.transform(_controller.value.clamp(0.0, 1.0));
    return Transform.scale(
      scale: 0.4 + pop * 0.6,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildCheck() {
    // A hand-drawn tick stroked in over the first ~60% of the timeline,
    // rather than a static Icons.check — the "drawing itself" motion is
    // what reads as a deliberate, crafted moment instead of a plain pop.
    final drawT = (_controller.value / 0.6).clamp(0.0, 1.0);
    return _ring(
      AppColors.tealDeep,
      CustomPaint(
        size: Size(widget.size * 0.5, widget.size * 0.5),
        painter: _CheckPainter(
          progress: Curves.easeOut.transform(drawT),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFlame() {
    // A couple of quick over/undershoots on scale+rotation right after the
    // pop, reading as a flicker rather than a single smooth settle.
    final t = _controller.value;
    final flicker = t < 0.35
        ? 1.0
        : t < 0.55
        ? 1.25
        : t < 0.75
        ? 0.92
        : t < 0.9
        ? 1.08
        : 1.0;
    final wobble = t < 0.55 ? -0.07 : (t < 0.75 ? 0.05 : 0.0);
    return _ring(
      AppColors.amberSoft,
      Transform.scale(
        scale: flicker,
        child: Transform.rotate(
          angle: wobble,
          child: Icon(
            Icons.local_fire_department,
            color: AppColors.amberDeep,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStar() {
    final floatT = ((_controller.value - 0.15) / 0.85).clamp(0.0, 1.0);
    return SizedBox(
      // Wide enough for a 3-digit "+100 XP" (the Expert Challenge finale's
      // one-off bonus), not just the usual 2-digit "+15 XP" — the label
      // isn't clipped by the Stack (clipBehavior: Clip.none) so a too-narrow
      // box just meant the overflow bled into whatever sat next to it.
      width: widget.size * 2.4,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          _ring(
            AppColors.accentSoft,
            Icon(
              Icons.star_rounded,
              color: AppColors.tealDeep,
              size: widget.size * 0.55,
            ),
          ),
          if (widget.xpLabel != null)
            Positioned(
              top: (1 - floatT) * 14,
              child: Opacity(
                opacity: floatT < 0.15
                    ? 0
                    : (floatT > 0.8
                          ? (1 - (floatT - 0.8) / 0.2).clamp(0.0, 1.0)
                          : 1.0),
                child: Text(
                  widget.xpLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.tealDeep,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedal() {
    // Drops in from above with a slight overshoot rotation that settles —
    // distinct from the other three, which all pop in place.
    final t = Curves.elasticOut.transform(_controller.value.clamp(0.0, 1.0));
    final dropOffset = (1 - t.clamp(0.0, 1.0)) * -18;
    return Transform.translate(
      offset: Offset(0, dropOffset),
      child: Transform.rotate(
        angle: (1 - t) * -0.35,
        child: _ring(
          AppColors.amberSoft,
          Icon(
            Icons.military_tech,
            color: AppColors.amberDeep,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.55)
      ..lineTo(size.width * 0.4, size.height * 0.85)
      ..lineTo(size.width * 0.95, size.height * 0.18);

    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
