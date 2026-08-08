import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../theme/app_theme.dart';
import 'lesson_complete_screen.dart';
import 'pairs_screen.dart';

/// Multiple-choice quiz screen — ported from the mockup's `#view-quiz`.
/// Answering locks the question, always reveals the correct option, and
/// shows a one-line explanation instead of a bare right/wrong signal.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.questions, required this.moduleId});

  final List<QuizQuestion> questions;
  final String moduleId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;

  QuizQuestion get _current => widget.questions[_index];
  bool get _answered => _selected != null;
  double get _progress => (_index + (_answered ? 1 : 0)) / widget.questions.length;

  void _selectOption(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      if (i == _current.correctIndex) _correctCount++;
    });
  }

  void _continue() {
    if (_index >= widget.questions.length - 1) {
      final pairs = MockData.pairsFor(widget.moduleId);
      if (pairs.isNotEmpty) {
        // Quiz done — move on to the harder confusable-pairs round on the
        // same module, replacing this screen so Back returns to Home.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PairsScreen(
              pairs: pairs,
              moduleId: widget.moduleId,
              priorCorrect: _correctCount,
              priorTotal: widget.questions.length,
            ),
          ),
        );
        return;
      }
      // No confusable pairs for this module — the quiz is the whole lesson.
      ProgressStore.instance.completeLesson(moduleId: widget.moduleId);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LessonCompleteScreen(correct: _correctCount, total: widget.questions.length),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    const SizedBox(height: 14),
                    Text(
                      _current.question,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _current.options.length; i++)
                      Padding(
                        key: Key('quiz-option-$i'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OptionTile(
                          letter: String.fromCharCode(65 + i),
                          text: _current.options[i],
                          state: _stateFor(i),
                          onTap: () => _selectOption(i),
                        ),
                      ),
                    if (_answered) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _current.explanation,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('quiz-continue-button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _continue,
                          child: Text(
                            _index >= widget.questions.length - 1 ? 'Finish' : 'Continue',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _OptionState _stateFor(int i) {
    if (!_answered) return _OptionState.neutral;
    if (i == _current.correctIndex) return _OptionState.correct;
    if (i == _selected) return _OptionState.wrong;
    return _OptionState.neutral;
  }
}

enum _OptionState { neutral, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = switch (state) {
      _OptionState.correct => AppColors.success,
      _OptionState.wrong => AppColors.danger,
      _OptionState.neutral => AppColors.border,
    };
    final Color? fillColor = switch (state) {
      _OptionState.correct => AppColors.successSoft,
      _OptionState.wrong => AppColors.dangerSoft,
      _OptionState.neutral => null,
    };
    final Color badgeColor = switch (state) {
      _OptionState.correct => AppColors.success,
      _OptionState.wrong => AppColors.danger,
      _OptionState.neutral => AppColors.inkSoft,
    };
    final Color textColor = switch (state) {
      _OptionState.correct => AppColors.success,
      _OptionState.wrong => AppColors.danger,
      _OptionState.neutral => AppColors.ink,
    };

    return Material(
      color: fillColor ?? AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _OptionState.neutral ? AppColors.bg : badgeColor,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: state == _OptionState.neutral ? AppColors.inkSoft : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
