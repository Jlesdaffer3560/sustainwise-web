import 'package:flutter/material.dart';
import '../data/models.dart';
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
  });

  final ModuleProgress module;
  final double horizontalOffset;
  final VoidCallback? onTap;

  @override
  State<ModulePathNode> createState() => _ModulePathNodeState();
}

class _ModulePathNodeState extends State<ModulePathNode> {
  bool _pressed = false;

  static const double _rimDepth = 5;

  @override
  Widget build(BuildContext context) {
    final status = widget.module.status;
    final Color fillColor = switch (status) {
      ModuleStatus.done => AppColors.teal,
      ModuleStatus.current => AppColors.amber,
      ModuleStatus.available => AppColors.bg,
    };
    final Color rimColor = switch (status) {
      ModuleStatus.done => AppColors.tealDeep,
      ModuleStatus.current => AppColors.amberDeep,
      ModuleStatus.available => AppColors.border,
    };
    final Color fgColor = switch (status) {
      ModuleStatus.done => Colors.white,
      ModuleStatus.current => Colors.white,
      ModuleStatus.available => AppColors.inkSoft,
    };
    final Color fgSoft = switch (status) {
      ModuleStatus.done => Colors.white.withValues(alpha: 0.85),
      ModuleStatus.current => Colors.white.withValues(alpha: 0.9),
      ModuleStatus.available => AppColors.inkSoft,
    };

    return Stack(
      children: [
        // The rim: a darker duplicate sitting slightly lower, giving the
        // row a pressable, 3-dimensional lip along its bottom edge.
        Positioned.fill(
          top: _rimDepth,
          child: DecoratedBox(decoration: BoxDecoration(color: rimColor, borderRadius: BorderRadius.circular(18))),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(bottom: _pressed ? 0 : _rimDepth, top: _pressed ? _rimDepth : 0),
          child: Material(
            color: fillColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: Key('module-node-${widget.module.id}'),
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: status == ModuleStatus.available
                    ? BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border))
                    : null,
                child: Row(
                  children: [
                    Icon(_buildIcon(status), color: fgColor, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status == ModuleStatus.current ? 'Start here' : widget.module.title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fgColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status == ModuleStatus.current ? widget.module.title : widget.module.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fgSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      status == ModuleStatus.available ? Icons.lock_outline : Icons.chevron_right,
                      color: fgColor,
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
      ModuleStatus.done => Icons.check_circle,
      ModuleStatus.current => Icons.play_circle_fill,
      ModuleStatus.available => _topicIcon(widget.module.title),
    };
  }

  /// A distinct glyph per topic so upcoming modules read as different
  /// destinations rather than identical locked placeholders.
  IconData _topicIcon(String title) {
    if (title.contains('CSDDD')) return Icons.hub_outlined;
    if (title.contains('SFDR')) return Icons.account_balance_outlined;
    if (title.contains('Taxonomy')) return Icons.category_outlined;
    return Icons.circle_outlined;
  }
}
