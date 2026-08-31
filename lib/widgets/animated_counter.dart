import 'package:flutter/material.dart';

/// A number that tweens smoothly to its new value instead of snapping —
/// used anywhere XP/streak/level jumps on rebuild, so progress reads as
/// something that just *happened* rather than a static label.
class AnimatedCounterText extends StatefulWidget {
  const AnimatedCounterText({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.duration = const Duration(milliseconds: 600),
  });

  final int value;
  final TextStyle? style;
  final String Function(int value)? formatter;
  final Duration duration;

  @override
  State<AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<AnimatedCounterText> {
  late int _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _oldValue = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final format = widget.formatter ?? (v) => '$v';
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _oldValue, end: widget.value),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Text(format(value), style: widget.style),
    );
  }
}

/// A [LinearProgressIndicator] whose value eases to its new target instead
/// of jumping — the same "this just happened" motion as [AnimatedCounterText],
/// for the daily-goal and lesson progress bars.
class AnimatedProgressBar extends StatefulWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.minHeight,
    required this.backgroundColor,
    required this.valueColor,
    this.duration = const Duration(milliseconds: 600),
  });

  final double value;
  final double? minHeight;
  final Color backgroundColor;
  final Color valueColor;
  final Duration duration;

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> {
  late double _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _oldValue = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _oldValue, end: widget.value),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: widget.minHeight,
        backgroundColor: widget.backgroundColor,
        valueColor: AlwaysStoppedAnimation(widget.valueColor),
      ),
    );
  }
}
