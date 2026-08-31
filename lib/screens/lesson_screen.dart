import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/unload_guard.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_route.dart';
import '../widgets/content_empty_state.dart';
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

class _LessonScreenState extends State<LessonScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _flipped = false;
  late final AnimationController _pulseController;

  Term get _current => widget.deck[_index];
  double get _progress =>
      (_index + (_flipped ? 1 : 0)) / (widget.deck.length * 1.0);

  @override
  void initState() {
    super.initState();
    pushUnloadGuard();
    // A gentle continuous pulse on the "tap to flip" hint — the card is the
    // only interactive element on an otherwise near-empty screen, so it
    // needs an ongoing cue, not just a one-shot hint that's easy to miss.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    popUnloadGuard();
    _pulseController.dispose();
    super.dispose();
  }

  void _rate(bool gotIt) {
    AppFeedback.tapSilent();
    if (_index >= widget.deck.length - 1) {
      // Flashcards done — move straight into the quiz on the same terms,
      // replacing this screen so its own back button returns to Home.
      Navigator.of(context).pushReplacement(
        appRoute(
          QuizScreen(
            questions: MockData.quizFor(widget.moduleId),
            moduleId: widget.moduleId,
          ),
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
    // Guards against widget.deck[_index] below indexing into nothing — not
    // reachable with today's content (every module has ≥10 terms, per
    // test/content_validation_test.dart), but a future content edit could
    // change that, and a crash isn't an acceptable way for a web visitor to
    // find out. Web-only: see ContentEmptyState's own doc comment.
    if (kIsWeb && widget.deck.isEmpty) {
      return const ContentEmptyState(
        message: 'No lesson content available for this module yet.',
      );
    }
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
                  onPressed: () {
                    AppFeedback.tapSilent();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FLASHCARDS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.tealDeep,
                    ),
                  ),
                  Text(
                    'Card ${_index + 1} of ${widget.deck.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildCard(), _buildAssessRow()],
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
      onTap: () {
        AppFeedback.tapSilent();
        setState(() => _flipped = !_flipped);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        constraints: const BoxConstraints(minHeight: 170, maxHeight: 420),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // Wrapped in its own scroll view — the richer flipped-side format
        // (plain English + why it matters + example + confuse-with) can run
        // longer than the card's max height on some terms, and this keeps
        // that overflow contained to the card instead of pushing the rating
        // buttons below it off screen.
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: _current.theme?.color ?? AppColors.tealDeep,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _current.theme == null
                          ? _current.moduleLabel
                          : '${_current.moduleLabel} · ${_current.theme!.label}',
                      textAlign: TextAlign.center,
                      // Longer module + theme combinations (e.g. "Governance
                      // & Anti-Corruption · Governance") don't fit one line
                      // — 2 lines avoids cutting a word off mid-way, with
                      // ellipsis as a last resort only.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: _current.theme?.color ?? AppColors.tealDeep,
                      ),
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
                const SizedBox(height: 12),
                if (_current.hasRichFormat)
                  _buildRichBack()
                else
                  _buildPlainBack(),
              ] else ...[
                const SizedBox(height: 14),
                FadeTransition(
                  opacity: Tween(
                    begin: 0.45,
                    end: 1.0,
                  ).animate(_pulseController),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 17,
                        color: AppColors.tealDeep,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Tap to reveal the definition',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // The original single-paragraph format — still used for every term not
  // yet migrated to the plain-English format below.
  Widget _buildPlainBack() {
    return Text(
      _current.definition,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14.5,
        color: AppColors.ink,
        height: 1.45,
      ),
    );
  }

  Widget _buildRichBack() {
    final term = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _richSection(
          'IN PLAIN ENGLISH',
          term.plainEnglish!,
          AppColors.tealDeep,
        ),
        if (term.whyItMatters != null) ...[
          const SizedBox(height: 14),
          _richSection(
            'WHY IT MATTERS',
            term.whyItMatters!,
            AppColors.tealDeep,
          ),
        ],
        if (term.example != null) ...[
          const SizedBox(height: 14),
          _richSection('EXAMPLE', term.example!, AppColors.tealDeep),
        ],
        if (term.dontConfuseWith != null) ...[
          const SizedBox(height: 14),
          _richSection(
            "DON'T CONFUSE WITH",
            term.dontConfuseWith!,
            AppColors.amberDeep,
          ),
        ],
      ],
    );
  }

  Widget _richSection(String label, String body, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.ink,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAssessRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // While the card is still face-down these buttons are disabled via
        // IgnorePointer below, which otherwise swallows the tap silently —
        // this outer detector catches that tap and explains why nothing
        // happened, instead of leaving it looking broken.
        onTap: _flipped
            ? null
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tap the card above to reveal the definition first',
                  ),
                  duration: Duration(seconds: 2),
                ),
              ),
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
                      side: const BorderSide(
                        color: AppColors.danger,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _rate(false),
                    child: const Text(
                      'Still learning',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('flashcard-rating-got-it'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(
                        color: AppColors.success,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _rate(true),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
