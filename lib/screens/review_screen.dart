import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/unload_guard.dart';
import '../widgets/animated_counter.dart';
import '../widgets/moment_badge.dart';

/// The "Mistakes to revisit" queue, re-quizzed — every question here is a
/// term due for review under the spaced-repetition schedule (1/3/7-day
/// intervals). Answering one right here advances it to its next, longer
/// interval, or clears it for good once it's passed the final stage;
/// getting it wrong again resets it back to a 1-day interval. Unlike a
/// regular lesson this isn't tied to a module: no pairs round, no XP, no
/// completeLesson — its only job is working through what's due today.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.questions});

  final List<QuizQuestion> questions;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;
  int _masteredCount = 0;
  bool _justMastered = false;
  bool get _done => _index >= widget.questions.length;

  QuizQuestion get _current => widget.questions[_index];
  bool get _answered => _selected != null;

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

  void _selectOption(int i) {
    if (_answered) return;
    final isCorrect = i == _current.correctIndex;
    isCorrect ? AppFeedback.correct() : AppFeedback.incorrect();
    setState(() {
      _selected = i;
      _justMastered = false;
      if (isCorrect) {
        _correctCount++;
        ProgressStore.instance.clearMiss(_current.termId);
        // clearMiss just ran — if the term is no longer in the schedule at
        // all, that correct answer was its last stage: fully mastered,
        // not just deferred to a later date.
        if (!ProgressStore.instance.isScheduled(_current.termId)) {
          _masteredCount++;
          _justMastered = true;
        }
      } else {
        ProgressStore.instance.recordMiss(_current.termId);
      }
    });
  }

  void _continue() {
    AppFeedback.tap();
    setState(() {
      _index++;
      _selected = null;
      _justMastered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _done ? _buildComplete(context) : _buildQuestion(context),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final progress = (_index + (_answered ? 1 : 0)) / widget.questions.length;
    return Column(
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
                  value: progress.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AppColors.amberDeep,
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
                const Row(
                  children: [
                    Icon(Icons.replay, size: 14, color: AppColors.amberDeep),
                    SizedBox(width: 5),
                    Text(
                      'MISTAKES TO REVISIT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.amberDeep,
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
                    key: Key('review-option-$i'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReviewOptionTile(
                      letter: String.fromCharCode(65 + i),
                      text: _current.options[i],
                      state: _stateFor(i),
                      onTap: () => _selectOption(i),
                    ),
                  ),
                if (_answered) ...[
                  const SizedBox(height: 4),
                  if (_justMastered) ...[
                    Row(
                      children: [
                        const MomentBadge(type: MomentType.check, size: 30),
                        const SizedBox(width: 8),
                        const Text(
                          'Term fully mastered!',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.tealDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
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
                      key: const Key('review-continue-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amberDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _continue,
                      child: Text(
                        _index >= widget.questions.length - 1
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
    );
  }

  // Distinguishes three real outcomes rather than a flat right/wrong count:
  // fully mastered (cleared the last stage, gone for good), deferred (right
  // this time, but back in a few days under the spaced schedule), and still
  // due today (missed again, or a second due term in the same session).
  String _summaryText(int remaining) {
    final buffer = StringBuffer(
      '$_correctCount/${widget.questions.length} correct this round.',
    );
    final deferred = _correctCount - _masteredCount;
    if (_masteredCount > 0) {
      buffer.write(
        ' $_masteredCount term${_masteredCount == 1 ? '' : 's'} fully mastered.',
      );
    }
    if (deferred > 0) {
      buffer.write(
        ' $deferred term${deferred == 1 ? '' : 's'} back for another check in a few days.',
      );
    }
    if (remaining > 0) {
      buffer.write(
        ' $remaining term${remaining == 1 ? '' : 's'} still due today.',
      );
    } else if (_masteredCount == 0 && deferred == 0) {
      // Every answer was wrong — nothing mastered, nothing deferred, and
      // nothing due again today either (each just reset to tomorrow).
      buffer.write(" They'll come back tomorrow for another try.");
    }
    return buffer.toString();
  }

  Widget _buildComplete(BuildContext context) {
    final remaining = ProgressStore.instance.missedCount;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _masteredCount > 0
              ? const MomentBadge(type: MomentType.check, size: 56)
              : Icon(
                  remaining == 0 ? Icons.celebration_outlined : Icons.replay,
                  size: 48,
                  color: AppColors.amberDeep,
                ),
          const SizedBox(height: 16),
          const Text(
            'Review complete',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _summaryText(remaining),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('review-done-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                AppFeedback.tap();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ReviewOptionState _stateFor(int i) {
    if (!_answered) return _ReviewOptionState.neutral;
    if (i == _current.correctIndex) return _ReviewOptionState.correct;
    if (i == _selected) return _ReviewOptionState.wrong;
    return _ReviewOptionState.neutral;
  }
}

enum _ReviewOptionState { neutral, correct, wrong }

class _ReviewOptionTile extends StatelessWidget {
  const _ReviewOptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _ReviewOptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = switch (state) {
      _ReviewOptionState.correct => AppColors.success,
      _ReviewOptionState.wrong => AppColors.danger,
      _ReviewOptionState.neutral => AppColors.border,
    };
    final Color? fillColor = switch (state) {
      _ReviewOptionState.correct => AppColors.successSoft,
      _ReviewOptionState.wrong => AppColors.dangerSoft,
      _ReviewOptionState.neutral => null,
    };
    final Color badgeColor = switch (state) {
      _ReviewOptionState.correct => AppColors.success,
      _ReviewOptionState.wrong => AppColors.danger,
      _ReviewOptionState.neutral => AppColors.inkSoft,
    };
    final Color textColor = switch (state) {
      _ReviewOptionState.correct => AppColors.success,
      _ReviewOptionState.wrong => AppColors.danger,
      _ReviewOptionState.neutral => AppColors.ink,
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
                  color: state == _ReviewOptionState.neutral
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
                    color: state == _ReviewOptionState.neutral
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
