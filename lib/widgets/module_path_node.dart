import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

/// One step in the learning path, rendered as a full-width rounded button
/// row (icon + title + status) rather than a circular "path dot" — a
/// clearly different shape/paradigm, not a variation on the same button.
/// Done/current rows get a solid color fill with a darker "rim" beneath,
/// so it still reads as pressable, chunky and game-like; available rows
/// stay flat and quiet to read as locked/inactive.
class ModulePathNode extends StatefulWidget {
  const ModulePathNode({
    super.key,
    required this.module,
    this.horizontalOffset = 0,
    this.onTap,
    this.doneFill,
    this.doneRim,
    this.lockedFill,
  });

  final ModuleProgress module;
  final double horizontalOffset;
  final VoidCallback? onTap;

  // The unit's own accent — a saturated fill for a "done" row, and (via
  // [lockedFill]) a light tint for a still-locked one, so every module
  // reads as belonging to its topic's color from the very first open, not
  // just once it's completed. Current rows keep the fixed amber highlight
  // treatment regardless of topic, since that signals state, not identity.
  final Color? doneFill;
  final Color? doneRim;
  final Color? lockedFill;

  @override
  State<ModulePathNode> createState() => _ModulePathNodeState();
}

class _ModulePathNodeState extends State<ModulePathNode>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  // Starts already "settled" (value 1) — a module that's current on first
  // build (e.g. reopening the app) should never replay the reveal; only an
  // actual available→current transition, caught in [didUpdateWidget],
  // should.
  late final AnimationController _revealController;

  static const double _rimDepth = 5;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant ModulePathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module.status != ModuleStatus.current &&
        widget.module.status == ModuleStatus.current) {
      _revealController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.module.status;
    final Color fillColor = switch (status) {
      ModuleStatus.done => widget.doneFill ?? AppColors.teal,
      ModuleStatus.current => AppColors.amber,
      ModuleStatus.available => widget.lockedFill ?? AppColors.bg,
    };
    final Color rimColor = switch (status) {
      ModuleStatus.done => widget.doneRim ?? AppColors.tealDeep,
      ModuleStatus.current => AppColors.amberDeep,
      ModuleStatus.available => AppColors.border,
    };
    // A locked row is rendered entirely in its own unit's deep accent —
    // title, summary and both icons — rather than neutral ink/gray, so the
    // color carries the whole row instead of just a faint background tint.
    final Color lockedInk = widget.doneRim ?? AppColors.inkSoft;
    final Color fgColor = switch (status) {
      ModuleStatus.done => Colors.white,
      ModuleStatus.current => Colors.white,
      ModuleStatus.available => lockedInk,
    };
    final Color fgSoft = switch (status) {
      ModuleStatus.done => Colors.white.withValues(alpha: 0.85),
      ModuleStatus.current => Colors.white.withValues(alpha: 0.9),
      ModuleStatus.available => lockedInk,
    };
    final Color iconAccent = switch (status) {
      ModuleStatus.done => Colors.white,
      ModuleStatus.current => Colors.white,
      ModuleStatus.available => lockedInk,
    };

    return Stack(
      children: [
        // The rim: a darker duplicate sitting slightly lower, giving the
        // row a pressable, 3-dimensional lip along its bottom edge.
        Positioned.fill(
          top: _rimDepth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: rimColor,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            bottom: _pressed ? 0 : _rimDepth,
            top: _pressed ? _rimDepth : 0,
          ),
          child: Material(
            color: fillColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: Key('module-node-${widget.module.id}'),
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap == null
                  ? null
                  : () {
                      AppFeedback.tap();
                      widget.onTap!();
                    },
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: status == ModuleStatus.available
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      )
                    : null,
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _revealController,
                      builder: (context, child) {
                        final t = Curves.elasticOut.transform(
                          _revealController.value.clamp(0.0, 1.0),
                        );
                        return Opacity(
                          opacity: _revealController.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.4 + t * 0.6,
                            child: Transform.rotate(
                              angle: (1 - t) * -0.4,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Icon(
                        _buildIcon(status),
                        color: iconAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.module.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: fgColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            switch (status) {
                              // No "Start here"/"Continue" copy on this row
                              // at all — the Home screen's "Continue
                              // learning" card is the single place that
                              // owns that call-to-action wording. Here, the
                              // amber fill, play icon and chevron alone
                              // signal "this is next"; the subtitle just
                              // describes the module, same as a locked row.
                              ModuleStatus.current => widget.module.summary,
                              // Explicit, not just implied by icon color —
                              // a done row should never read as "this is
                              // where I continue," only the single current
                              // row should. It's also no longer tappable
                              // into the lesson, so the copy doesn't invite
                              // a tap either.
                              ModuleStatus.done => 'Completed',
                              ModuleStatus.available => widget.module.summary,
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: fgSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      switch (status) {
                        // On web every module is actually reachable (see
                        // home_screen.dart's _onModuleTap), so a padlock
                        // would be a lie — use the same "open" chevron as
                        // the current module instead.
                        ModuleStatus.available => kIsWeb
                            ? Icons.chevron_right
                            : Icons.lock_outline,
                        // A forward-pointing chevron is reserved for the
                        // one truly "next" module — a done row gets a
                        // checkmark instead, so it can never be mistaken
                        // for "continue here."
                        ModuleStatus.current => Icons.chevron_right,
                        ModuleStatus.done => Icons.check_circle,
                      },
                      color: iconAccent,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _buildIcon(ModuleStatus status) {
    return switch (status) {
      // A bloom instead of a plain checkmark — a finished module is a
      // grown plant on the path, not just a ticked-off task.
      ModuleStatus.done => Icons.local_florist,
      ModuleStatus.current => Icons.play_circle_fill,
      ModuleStatus.available => _topicIcon(widget.module.id),
    };
  }

  /// A distinct glyph per module (keyed by its stable id, not its display
  /// title) so every single one of the 16 modules reads as a different
  /// destination on the path — not just the handful that used to get a
  /// specific icon before every other module fell back to a bare circle.
  static const _topicIconById = <String, IconData>{
    'esg-fundamentals': Icons.school_outlined,
    'csr-ethics': Icons.balance_outlined,
    'csrd-esrs': Icons.fact_check_outlined,
    'csddd': Icons.hub_outlined,
    'sfdr': Icons.account_balance_outlined,
    'eu-taxonomy': Icons.category_outlined,
    'gri-standards': Icons.checklist_outlined,
    'other-reporting-standards': Icons.summarize_outlined,
    'sustainable-finance-ethical-investing': Icons.savings_outlined,
    'climate-carbon-accounting': Icons.co2_outlined,
    'circular-economy-biodiversity': Icons.recycling_outlined,
    'social-issues-human-rights': Icons.volunteer_activism_outlined,
    'governance-anti-corruption': Icons.verified_user_outlined,
    'greenwashing-empco-ucpd': Icons.report_problem_outlined,
    'key-players-institutions': Icons.corporate_fare_outlined,
    'timeline-milestones': Icons.timeline_outlined,
  };

  IconData _topicIcon(String moduleId) =>
      _topicIconById[moduleId] ?? Icons.circle_outlined;
}
