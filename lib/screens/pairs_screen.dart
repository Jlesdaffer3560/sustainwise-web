import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/unload_guard.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_route.dart';
import 'lesson_complete_screen.dart';

/// Confusable-pairs ("which is which?") round — a clue statement that
/// describes one of two easily-mixed-up terms. Ported from the mockup's
/// `#view-match`, the hard-mode follow-up to the multiple-choice quiz.
class PairsScreen extends StatefulWidget {
  const PairsScreen({
    super.key,
    required this.pairs,
    required this.moduleId,
    this.priorCorrect = 0,
    this.priorTotal = 0,
  });

  final List<ConfusablePair> pairs;
  final String moduleId;
  // Score carried over from the quiz round on the same module, so the
  // Lesson Complete summary reflects the whole lesson, not just this round.
  final int priorCorrect;
  final int priorTotal;

  @override
  State<PairsScreen> createState() => _PairsScreenState();
}

class _PairsScreenState extends State<PairsScreen> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;

  ConfusablePair get _current => widget.pairs[_index];
  bool get _answered => _selected != null;
  double get _progress => (_index + (_answered ? 1 : 0)) / widget.pairs.length;

  @override
  void initState() {
    super.initState();
    pushUnloadGuard();
  }

  @override
  void dispose() {
    popUnloadGuard();
    super.dispose();
  }

  void _select(int i) {
    if (_answered) return;
    final isCorrect = i == _current.correctIndex;
    isCorrect ? AppFeedback.correct() : AppFeedback.incorrect();
    setState(() {
      _selected = i;
      if (isCorrect) _correctCount++;
    });
  }

  void _continue() {
    AppFeedback.tap();
    if (_index >= widget.pairs.length - 1) {
      final totalCorrect = widget.priorCorrect + _correctCount;
      final totalQuestions = widget.priorTotal + widget.pairs.length;
      ProgressStore.instance.completeLesson(
        moduleId: widget.moduleId,
        correct: totalCorrect,
        total: totalQuestions,
      );
      Navigator.of(context).pushReplacement(
        appRoute(
          LessonCompleteScreen(correct: totalCorrect, total: totalQuestions),
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
                  onPressed: () {
                    AppFeedback.tap();
                    Navigator.of(context).pop();
                  },
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedProgressBar(
                      value: _progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AppColors.teal,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 4),
                    const Text(
                      'WHICH IS WHICH?',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        _current.statement,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _PairChip(
                            key: const Key('pair-chip-0'),
                            label: _current.optionA,
                            state: _stateFor(0),
                            onTap: () => _select(0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.teal, AppColors.amber],
                            ),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PairChip(
                            key: const Key('pair-chip-1'),
                            label: _current.optionB,
                            state: _stateFor(1),
                            onTap: () => _select(1),
                          ),
                        ),
                      ],
                    ),
                    if (_answered) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _current.explanation,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.ink,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('pairs-continue-button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _continue,
                          child: Text(
                            _index >= widget.pairs.length - 1
                                ? 'Finish'
                                : 'Continue',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
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

  _PairState _stateFor(int i) {
    if (!_answered) return _PairState.neutral;
    if (i == _current.correctIndex) return _PairState.correct;
    if (i == _selected) return _PairState.wrong;
    return _PairState.neutral;
  }
}

enum _PairState { neutral, correct, wrong }

class _PairChip extends StatelessWidget {
  const _PairChip({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _PairState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = switch (state) {
      _PairState.correct => AppColors.success,
      _PairState.wrong => AppColors.danger,
      _PairState.neutral => AppColors.teal,
    };
    final Color fillColor = switch (state) {
      _PairState.correct => AppColors.successSoft,
      _PairState.wrong => AppColors.dangerSoft,
      _PairState.neutral => AppColors.surface,
    };
    final Color textColor = switch (state) {
      _PairState.correct => AppColors.success,
      _PairState.wrong => AppColors.danger,
      _PairState.neutral => AppColors.tealDeep,
    };

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
