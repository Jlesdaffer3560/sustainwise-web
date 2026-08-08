import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A ring/donut progress indicator, matching `.ring-wrap` in the mockup.
/// The fill percentage is drawn by [_RingPainter] — no manual circumference
/// math is duplicated anywhere else, same principle as the mockup's JS.
class ProgressRing extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(percent: percent, fillColor: fillColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: size >= 100 ? 20 : 15,
                  color: AppColors.tealDeep,
                ),
              ),
              Text(
                centerLabel,
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
