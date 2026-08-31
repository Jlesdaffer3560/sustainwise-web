import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_route.dart';
import '../widgets/mascot.dart';
import 'home_screen.dart';

/// A brief, one-shot branded entrance shown on cold start, in place of
/// jumping straight to the content — built entirely with Flutter's own
/// animation system rather than a bundled video file. Finite and
/// self-navigating (no perpetual animation), so it settles cleanly under
/// `pumpAndSettle`/bounded test pumps just like [ConfettiBurst] and
/// [Mascot]'s own entrance.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _textController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  Timer? _navigateTimer;

  static const _dwell = Duration(milliseconds: 1300);

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );
    _textSlide = Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _textController.forward();
    });
    // Onboarding's role question is asked later, at the point the learner
    // actually starts their first lesson — not here. A cold open is not
    // the moment to interrupt with a question before anything's been seen.
    _navigateTimer = Timer(_dwell, () {
      if (mounted)
        Navigator.of(context).pushReplacement(appRoute(const HomeScreen()));
    });
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.heroDeep,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.heroDeep, AppColors.heroMid],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(mood: MascotMood.cheering, size: 84),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: const Text(
                    'SustainWise',
                    style: TextStyle(
                      fontFamily: 'LoraItalic',
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
