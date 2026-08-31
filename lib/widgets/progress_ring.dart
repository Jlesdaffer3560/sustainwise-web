import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A ring/donut progress indicator, matching `.ring-wrap` in the mockup.
/// The fill percentage is drawn by [_RingPainter] — no manual circumference
/// math is duplicated anywhere else, same principle as the mockup's JS. The
/// fill sweep eases to its new value instead of snapping, so it reads as
/// filling in live rather than a static gauge.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    required this.centerValue,
    required this.centerLabel,
    this.size = 80,
    this.fillColor = AppColors.teal,
  });

  final double percent; // 0-100
  final String centerValue;
  final String centerLabel;
  final double size;
  final Color fillColor;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing> {
  late double _oldPercent;

  @override
  void initState() {
    super.initState();
    _oldPercent = 0; // always fills in from empty on first appearance
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _oldPercent = oldWidget.percent;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _oldPercent, end: widget.percent),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, percent, child) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(
                percent: percent,
                fillColor: widget.fillColor,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.centerValue,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: widget.size >= 100 ? 20 : 15,
                  color: AppColors.tealDeep,
                ),
              ),
              Text(
                widget.centerLabel,
                style: const TextStyle(fontSize: 9, color: AppColors.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent, required this.fillColor});

  final double percent;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 6.28319, false, track);

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const startAngle = -1.5708; // -90deg, matches the mockup's rotate(-90deg)
    final sweep = 6.28319 * (percent.clamp(0, 100) / 100);
    canvas.drawArc(rect, startAngle, sweep, false, fill);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.fillColor != fillColor;
}
