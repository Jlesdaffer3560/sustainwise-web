import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_route.dart';
import 'lesson_complete_screen.dart';

/// The bonus round unlocked once every module is done — 30 hand-written,
/// deliberately harder questions (thresholds, edge cases, cross-framework
/// distinctions) rather than the mechanically generated "which definition
/// matches X" quiz. Styled in amber instead of teal so it visually reads as
/// a distinct, higher-stakes tier rather than just another module quiz.
class ExpertChallengeScreen extends StatefulWidget {
  const ExpertChallengeScreen({super.key});

  @override
  State<ExpertChallengeScreen> createState() => _ExpertChallengeScreenState();
}

class _ExpertChallengeScreenState extends State<ExpertChallengeScreen> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;

  List<QuizQuestion> get _questions => MockData.expertChallenge;
  QuizQuestion get _current => _questions[_index];
  bool get _answered => _selected != null;
  double get _progress => (_index + (_answered ? 1 : 0)) / _questions.length;

  void _selectOption(int i) {
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
    if (_index >= _questions.length - 1) {
      // The one-off 100 XP bonus only pays out the first time — check
      // before calling completeExpertChallenge(), which flips the
      // "completed" flag to true regardless of whether this is a replay.
      final isReplay = ProgressStore.instance.expertChallengeCompleted;
      // Not awaited — completeExpertChallenge() notifies listeners and
      // updates in-memory state synchronously before its own internal save
      // I/O, so navigating right away (matching QuizScreen/PairsScreen)
      // doesn't race the state the next screen reads.
      ProgressStore.instance.completeExpertChallenge(
        correct: _correctCount,
        total: _questions.length,
      );
      Navigator.of(context).pushReplacement(
        appRoute(
          LessonCompleteScreen(
            correct: _correctCount,
            total: _questions.length,
            title: 'Curriculum complete!',
            xpEarned: isReplay ? 0 : 100,
            isFinale: true,
          ),
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
                      valueColor: AppColors.amber,
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
                        const Icon(
                          Icons.workspace_premium_outlined,
                          size: 14,
                          color: AppColors.amberDeep,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _current.moduleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppColors.amberDeep,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Q${_index + 1}/${_questions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _current.question,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _current.options.length; i++)
                      Padding(
                        key: Key('expert-option-$i'),
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
                          color: AppColors.amberSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _current.explanation,
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
                          key: const Key('expert-continue-button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.amberDeep,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _continue,
                          child: Text(
                            _index >= _questions.length - 1
                                ? 'Finish'
                                : 'Continue',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
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
                  color: state == _OptionState.neutral
                      ? AppColors.bg
                      : badgeColor,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: state == _OptionState.neutral
                        ? AppColors.inkSoft
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
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
