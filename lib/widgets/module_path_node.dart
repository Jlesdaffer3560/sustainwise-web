import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/responsive.dart';

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

    // Desktop web only: the chunky 3D rim and full-saturation fill read as
    // "candy"/game-like per external review — soberer here means a flat
    // white card, a left accent stripe carrying the module's color instead
    // of a solid fill, and no pressable-rim depth effect. The native app
    // and narrow web keep the exact original treatment untouched.
    final desktop = isDesktopWeb(context);
    // On web every module is actually tappable (see home_screen.dart's
    // _onModuleTap) — an "available" row rendered in the same dim,
    // low-contrast ink native uses for a module you genuinely can't reach
    // yet would still read as locked even with the padlock icon gone.
    // Reads as a plain not-started item instead, on both narrow and
    // desktop web. Native keeps the original muted treatment.
    final openOnWeb = kIsWeb && status == ModuleStatus.available;
    // Plain white for every status read as too pale/uniform in practice —
    // done and current rows now get a faint tint of their own accent
    // (the unit's color for done, amber for current) so the path still
    // shows visual progress at a glance, without going back to the
    // full-saturation "candy" fill the flattening was meant to remove.
    // Available stays plain white; it's meant to read as neutral.
    final Color cardBg = openOnWeb
        ? AppColors.surface
        : (desktop
              ? rimColor.withValues(
                  alpha: status == ModuleStatus.current ? 0.16 : 0.10,
                )
              : fillColor);
    final Color cardFg = openOnWeb
        ? AppColors.ink
        : (desktop
              ? (status == ModuleStatus.available ? lockedInk : AppColors.ink)
              : fgColor);
    final Color cardFgSoft = openOnWeb
        ? AppColors.inkSoft
        : (desktop
              ? (status == ModuleStatus.available
                    ? lockedInk
                    : AppColors.inkSoft)
              : fgSoft);
    final Color cardIconAccent = openOnWeb
        ? AppColors.inkSoft
        : (desktop
              ? (status == ModuleStatus.available ? lockedInk : rimColor)
              : iconAccent);

    // Desktop only: an available row's stripe was plain neutral gray,
    // same as every other available row regardless of unit — with most
    // modules unstarted on a first visit, that read as one long wall of
    // white cards with no color at all. Carries the unit's own (already
    // muted, on web) accent instead, so every row still identifies its
    // topic before it's ever opened. Done/current keep their existing
    // stripe color; native and narrow web are untouched.
    final Color desktopStripeColor = status == ModuleStatus.available
        ? (widget.doneRim ?? rimColor)
        : rimColor;

    // Smaller radius and calmer type weight on desktop — a review round
    // called the rounder native proportions and heavy w800 titles still
    // "Duolingo/game" adjacent even after the flat-card treatment. Native
    // and narrow web keep the original 18px/w800 exactly as they were.
    final radius = desktop ? 14.0 : 18.0;
    final row = Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        key: Key('module-node-${widget.module.id}'),
        borderRadius: BorderRadius.circular(radius),
        onTap: widget.onTap == null
            ? null
            : () {
                AppFeedback.tap();
                widget.onTap!();
              },
        onTapDown: desktop ? null : (_) => setState(() => _pressed = true),
        onTapCancel: desktop ? null : () => setState(() => _pressed = false),
        onTapUp: desktop ? null : (_) => setState(() => _pressed = false),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: desktop
                ? Border(
                    top: BorderSide(color: AppColors.border),
                    right: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border),
                    left: BorderSide(color: desktopStripeColor, width: 4),
                  )
                : (status == ModuleStatus.available
                      ? Border.all(color: AppColors.border)
                      : null),
          ),
          child: Row(
            children: [
              // The elastic scale/rotate pop is a game-like flourish native
              // earns every time a module unlocks — desktop web skips it
              // for a plain icon instead, on top of everything else this
              // branch already sobers up.
              if (desktop)
                Icon(_buildIcon(status), color: cardIconAccent, size: 24)
              else
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
                    color: cardIconAccent,
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
                        fontWeight: desktop
                            ? FontWeight.w700
                            : FontWeight.w800,
                        color: cardFg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      switch (status) {
                        // No "Start here"/"Continue" copy on this row at
                        // all — the Home screen's "Continue learning" card
                        // is the single place that owns that call-to-action
                        // wording. Here, the amber fill, play icon and
                        // chevron alone signal "this is next"; the subtitle
                        // just describes the module, same as a locked row.
                        ModuleStatus.current => widget.module.summary,
                        // Explicit, not just implied by icon color — a done
                        // row should never read as "this is where I
                        // continue," only the single current row should.
                        // It's also no longer tappable into the lesson, so
                        // the copy doesn't invite a tap either.
                        ModuleStatus.done => 'Completed',
                        ModuleStatus.available => widget.module.summary,
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cardFgSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                switch (status) {
                  // On web every module is actually reachable (see
                  // home_screen.dart's _onModuleTap), so a padlock would be
                  // a lie — use the same "open" chevron as the current
                  // module instead.
                  ModuleStatus.available => kIsWeb
                      ? Icons.chevron_right
                      : Icons.lock_outline,
                  // A forward-pointing chevron is reserved for the one
                  // truly "next" module — a done row gets a checkmark
                  // instead, so it can never be mistaken for "continue
                  // here."
                  ModuleStatus.current => Icons.chevron_right,
                  ModuleStatus.done => Icons.check_circle,
                },
                color: cardIconAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );

    // Desktop web: flat card, no pressable-rim depth. Native/mobile-web:
    // the original Stack + offset "rim" duplicate giving the row its
    // pressable, chunky lip — untouched.
    if (desktop) return row;
    return Stack(
      children: [
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
          child: row,
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
