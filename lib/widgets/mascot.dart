import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The mascot's expression is derived entirely from local [ProgressStore]
/// state (daily goal met, lesson score) — never anything server-side, since
/// this app has no accounts or backend to react to.
enum MascotMood { neutral, happy, cheering, encouraging, worried }

/// A small pointed-leaf character, drawn rather than shipped as an image
/// asset, so its expression can be swapped per mood without needing a
/// sprite sheet. Plays a one-shot bouncy entrance (plus a mid-way blink)
/// on mount instead of just appearing static — finite and non-repeating,
/// like [ConfettiBurst], so it never blocks `pumpAndSettle` in tests.
class Mascot extends StatefulWidget {
  const Mascot({super.key, required this.mood, this.size = 56});

  final MascotMood mood;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _scale = Tween(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(curve: Curves.elasticOut, parent: _controller));
    // A single mid-entrance blink — a static face reads as a sticker; one
    // blink is enough to read as alive without becoming a distracting loop.
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _blinking = true);
      Future.delayed(const Duration(milliseconds: 110), () {
        if (mounted) setState(() => _blinking = false);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _MascotPainter(widget.mood, blink: _blinking),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood, {this.blink = false});

  final MascotMood mood;
  final bool blink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final ink = AppColors.tealDeep;

    // A pointed leaf silhouette (not a circle) — the previous round body
    // with a straight stem on top read as an apple, not a leaf.
    final tip = Offset(c.dx, c.dy - r * 1.02);
    final bottomPoint = Offset(c.dx, c.dy + r * 0.92);
    final leaf = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        c.dx + r * 1.05,
        c.dy - r * 0.35,
        bottomPoint.dx,
        bottomPoint.dy,
      )
      ..quadraticBezierTo(c.dx - r * 1.05, c.dy - r * 0.35, tip.dx, tip.dy)
      ..close();

    // Stem leans off the tip at a slight angle, like a real leaf stalk.
    canvas.drawLine(
      tip,
      Offset(tip.dx + r * 0.22, tip.dy - r * 0.22),
      Paint()
        ..color = ink
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(leaf, Paint()..color = AppColors.tealBright);
    // A faint center vein sells the leaf read without competing with the face.
    canvas.drawLine(
      Offset(tip.dx, tip.dy + r * 0.12),
      Offset(bottomPoint.dx, bottomPoint.dy - r * 0.12),
      Paint()
        ..color = ink.withValues(alpha: 0.28)
        ..strokeWidth = r * 0.035
        ..strokeCap = StrokeCap.round,
    );

    final eyeDx = r * 0.32;
    final eyeY = c.dy - r * 0.08;
    final eyeR = r * 0.08;

    if (mood == MascotMood.cheering) {
      // Closed, upward "^" eyes for the biggest celebratory moment.
      final archPaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round;
      for (final side in [-1, 1]) {
        final ex = c.dx + side * eyeDx;
        final path = Path()
          ..moveTo(ex - eyeR, eyeY + eyeR * 0.5)
          ..quadraticBezierTo(
            ex,
            eyeY - eyeR * 0.9,
            ex + eyeR,
            eyeY + eyeR * 0.5,
          );
        canvas.drawPath(path, archPaint);
      }
    } else if (blink) {
      final blinkPaint = Paint()
        ..color = ink
        ..strokeWidth = r * 0.045
        ..strokeCap = StrokeCap.round;
      for (final side in [-1, 1]) {
        final ex = c.dx + side * eyeDx;
        canvas.drawLine(
          Offset(ex - eyeR, eyeY),
          Offset(ex + eyeR, eyeY),
          blinkPaint,
        );
      }
    } else {
      final eyePaint = Paint()..color = ink;
      canvas.drawCircle(Offset(c.dx - eyeDx, eyeY), eyeR, eyePaint);
      canvas.drawCircle(Offset(c.dx + eyeDx, eyeY), eyeR, eyePaint);
    }

    if (mood == MascotMood.worried) {
      // Short angled brows read as concern without touching the eyes.
      final browPaint = Paint()
        ..color = ink
        ..strokeWidth = r * 0.045
        ..strokeCap = StrokeCap.round;
      for (final side in [-1, 1]) {
        final ex = c.dx + side * eyeDx;
        canvas.drawLine(
          Offset(ex - side * eyeR * 0.2, eyeY - eyeR * 2.2),
          Offset(ex + side * eyeR * 1.4, eyeY - eyeR * 1.1),
          browPaint,
        );
      }
    }

    final mouthY = c.dy + r * 0.34;
    final mw = r * 0.5;
    final mouthStroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case MascotMood.cheering:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx, mouthY - r * 0.05),
            width: mw * 0.85,
            height: mw * 0.7,
          ),
          Paint()..color = ink,
        );
      case MascotMood.happy:
        final path = Path()
          ..moveTo(c.dx - mw / 2, mouthY - r * 0.05)
          ..quadraticBezierTo(
            c.dx,
            mouthY + r * 0.22,
            c.dx + mw / 2,
            mouthY - r * 0.05,
          );
        canvas.drawPath(path, mouthStroke);
      case MascotMood.encouraging:
        final path = Path()
          ..moveTo(c.dx - mw * 0.35, mouthY)
          ..quadraticBezierTo(c.dx, mouthY + r * 0.1, c.dx + mw * 0.35, mouthY);
        canvas.drawPath(path, mouthStroke);
      case MascotMood.worried:
        final path = Path()
          ..moveTo(c.dx - mw * 0.35, mouthY + r * 0.08)
          ..quadraticBezierTo(
            c.dx,
            mouthY - r * 0.08,
            c.dx + mw * 0.35,
            mouthY + r * 0.08,
          );
        canvas.drawPath(path, mouthStroke);
      case MascotMood.neutral:
        canvas.drawLine(
          Offset(c.dx - mw * 0.3, mouthY),
          Offset(c.dx + mw * 0.3, mouthY),
          mouthStroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.blink != blink;
}
