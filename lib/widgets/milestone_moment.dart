import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'confetti_burst.dart';

/// Which genuine milestone this moment marks — each gets its own icon and
/// accent so a streak milestone never looks interchangeable with finishing
/// the whole curriculum.
enum MilestoneKind { streak, courseComplete }

/// The native stand-in for a "short video clip on a key moment": a badge
/// zooming in inside a confetti burst, followed by a headline rising into
/// place — reserved for genuine milestones (streak 7/30/100, finishing
/// every module), not everyday feedback. One shot, then it sits still until
/// the caller dismisses it — never a looping animation.
class MilestoneMoment extends StatefulWidget {
  const MilestoneMoment({
    super.key,
    required this.kind,
    required this.headline,
    this.size = 220,
  });

  final MilestoneKind kind;
  final String headline;
  final double size;

  @override
  State<MilestoneMoment> createState() => _MilestoneMomentState();
}

class _MilestoneMomentState extends State<MilestoneMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, fill, ink) = switch (widget.kind) {
      MilestoneKind.streak => (
        Icons.local_fire_department,
        AppColors.amberSoft,
        AppColors.amberDeep,
      ),
      MilestoneKind.courseComplete => (
        Icons.emoji_events,
        AppColors.accentSoft,
        AppColors.tealDeep,
      ),
    };
    final badgeSize = widget.size * 0.42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConfettiBurst(
          size: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final pop = Curves.elasticOut.transform(
                _controller.value.clamp(0.0, 1.0),
              );
              return Transform.scale(
                scale: 0.3 + pop * 0.7,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                  ),
                  child: Icon(icon, color: ink, size: badgeSize * 0.52),
                ),
              );
            },
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = ((_controller.value - 0.4) / 0.6).clamp(0.0, 1.0);
            return Opacity(
              opacity: Curves.easeOut.transform(t),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 10),
                child: Text(
                  widget.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
