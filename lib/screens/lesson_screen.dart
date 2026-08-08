import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';

/// The flashcard study screen — flip to reveal the definition, then
/// self-rate with a Leitner-style "Still learning" / "Got it" choice.
/// Ported from the mockup's `#view-lesson` screen.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.deck, required this.moduleId});

  final List<Term> deck;
  final String moduleId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _index = 0;
  bool _flipped = false;

  Term get _current => widget.deck[_index];
  double get _progress => (_index + (_flipped ? 1 : 0)) / (widget.deck.length * 1.0);

  void _rate(bool gotIt) {
    if (_index >= widget.deck.length - 1) {
      // Flashcards done — move straight into the quiz on the same terms,
      // replacing this screen so its own back button returns to Home.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizScreen(questions: MockData.quizFor(widget.moduleId), moduleId: widget.moduleId),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // This screen has a light background, unlike Home's dark hero panel —
      // the status bar needs dark icons here for contrast.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCard(),
                    _buildAssessRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return GestureDetector(
      key: const Key('flashcard'),
      onTap: () => setState(() => _flipped = !_flipped),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        constraints: const BoxConstraints(minHeight: 170),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description_outlined, size: 14, color: AppColors.tealDeep),
                const SizedBox(width: 5),
                Text(
                  _current.moduleLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.tealDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _current.term,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _flipped ? 16 : 22,
                fontWeight: FontWeight.w700,
                color: _flipped ? AppColors.ink : AppColors.tealDeep,
              ),
            ),
            if (_flipped) ...[
              const SizedBox(height: 10),
              Text(
                _current.definition,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: AppColors.ink, height: 1.45),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Tap card to reveal definition',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssessRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: IgnorePointer(
        ignoring: !_flipped,
        child: AnimatedOpacity(
          opacity: _flipped ? 1 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('flashcard-rating-still-learning'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _rate(false),
                  child: const Text('Still learning', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const Key('flashcard-rating-got-it'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _rate(true),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
