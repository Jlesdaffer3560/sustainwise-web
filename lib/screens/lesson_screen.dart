import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/responsive.dart';
import '../web/unload_guard.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_route.dart';
import '../widgets/content_empty_state.dart';
import '../widgets/share_card.dart';
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

  // A horizontal flick on a flipped card rates it: right = "Got it", left =
  // "Still learning". Ignored while the card is face-down, so a stray swipe
  // can never rate a term the learner has not seen the answer to.
  //
  // A swipe counts when it travels far enough (a slow, deliberate drag) or is
  // flicked fast (a short, quick one). The direction comes from where the
  // finger actually went, not from the final velocity.
  double _dragDx = 0;
  static const _swipeDistance = 56.0;
  static const _swipeVelocity = 500.0;

  void _onSwipe(DragEndDetails details) {
    final dx = _dragDx;
    _dragDx = 0;
    if (!_flipped) return;
    final velocity = details.primaryVelocity ?? 0;
    if (dx.abs() < _swipeDistance && velocity.abs() < _swipeVelocity) return;
    final right = dx != 0 ? dx > 0 : velocity > 0;
    HapticFeedback.lightImpact();
    _rate(right);
  }

  void _rate(bool gotIt) {
    AppFeedback.tapSilent();
    // A "Still learning" self-rating queues the term for spaced review
    // right away, the same as a wrong quiz answer would — otherwise a
    // learner honestly flagging "I don't know this" had no actual effect,
    // which contradicted what the button claims to do.
    if (!gotIt) ProgressStore.instance.recordMiss(_current.id);
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
                  tooltip: 'Close',
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
                children: [
                  // Takes whatever the card counter and share icon leave, and
                  // gives way first on a narrow screen with large text.
                  const Expanded(
                    child: Text(
                      'FLASHCARDS',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.tealDeep,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Card ${_index + 1} of ${widget.deck.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      // Always laid out (so the header never jumps), but only
                      // visible and tappable once the answer is showing.
                      Opacity(
                        opacity: _flipped ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_flipped,
                          child: IconButton(
                            key: const Key('flashcard-share'),
                            tooltip: 'Share as image',
                            icon: Icon(
                              kIsWeb ? Icons.image_outlined : Icons.ios_share,
                              size: 19,
                              color: AppColors.tealDeep,
                            ),
                            onPressed: () => shareTermCard(context, _current),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              // Scrolls only when a small screen cannot fit the card, the
              // buttons and the swipe tip at once; otherwise the content
              // stays vertically centred exactly as before.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCard(),
                        _buildAssessRow(),
                        // Only worth saying once there is something to swipe,
                        // and not to a desktop visitor with a mouse (the
                        // swipe still works there, but nobody expects it).
                        AnimatedOpacity(
                          opacity: _flipped && !isDesktopWeb(context) ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'Tip: swipe the card right for Got it, left '
                              'for Still learning.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragCancel: () => _dragDx = 0,
      onHorizontalDragEnd: _onSwipe,
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
                      Flexible(
                        child: Text(
                          'Tap to reveal the definition',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDeep,
                          ),
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
