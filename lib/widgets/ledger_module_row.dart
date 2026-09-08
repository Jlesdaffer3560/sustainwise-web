import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

/// "The Ledger" — a table-row rendering of a module for desktop web,
/// replacing [ModulePathNode]'s card there. Every module is reachable on
/// web regardless of status (see home_screen.dart's _onModuleTap), so this
/// never shows a padlock — only done/current/available read differently
/// through the status pill and row emphasis. Native and narrow web never
/// build this; they keep ModulePathNode exactly as it was.
class LedgerModuleRow extends StatelessWidget {
  const LedgerModuleRow({
    super.key,
    required this.module,
    required this.onTap,
    this.isLast = false,
  });

  final ModuleProgress module;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final status = module.status;
    final (dotColor, pillBg, pillFg, pillLabel) = switch (status) {
      ModuleStatus.done => (
        LedgerColors.teal,
        LedgerColors.tealSoft,
        LedgerColors.teal,
        'Completed',
      ),
      ModuleStatus.current => (
        // goldDeep, not gold — plain gold is only 2.42:1 against this
        // white card, under WCAG's 3:1 minimum for a graphical status
        // indicator (goldDeep clears it at 5.06:1).
        LedgerColors.goldDeep,
        LedgerColors.goldSoft,
        LedgerColors.goldDeep,
        'In progress',
      ),
      ModuleStatus.available => (
        LedgerColors.neutralDot,
        LedgerColors.neutralSoft,
        LedgerColors.neutralText,
        'Not started',
      ),
    };
    // A rough estimate from term count alone — a module also has a quiz and
    // confusable pairs a term count doesn't capture — so this reads as an
    // approximation ("~X min"), not a precise duration.
    final minutes = (module.termCount * 0.5).ceil();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('module-node-${module.id}'),
        onTap: onTap == null
            ? null
            : () {
                AppFeedback.tap();
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: LedgerColors.borderSoft),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        module.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: LedgerColors.fontSans,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: LedgerColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      pillLabel,
                      style: TextStyle(
                        fontFamily: LedgerColors.fontMono,
                        fontSize: 11,
                        letterSpacing: 0.2,
                        color: pillFg,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${module.termCount}',
                  style: const TextStyle(
                    fontFamily: LedgerColors.fontMono,
                    fontSize: 13,
                    color: LedgerColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  status == ModuleStatus.done ? '—' : '~$minutes min',
                  style: const TextStyle(
                    fontFamily: LedgerColors.fontMono,
                    fontSize: 13,
                    color: LedgerColors.inkSoft,
                  ),
                ),
              ),
              // A row full of plain text columns gave no visual cue that
              // tapping it does anything — this chevron is the only "open
              // this" affordance, matching the chevron ModulePathNode uses
              // for the same purpose elsewhere.
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: LedgerColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The table's own header row (Module / Status / Terms / Est. time) —
/// shared by every unit group so the columns line up down the whole page.
class LedgerTableHeader extends StatelessWidget {
  const LedgerTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: LedgerColors.fontMono,
      fontSize: 10,
      letterSpacing: 0.6,
      color: LedgerColors.inkSoft,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: LedgerColors.neutralSoft,
        border: Border(bottom: BorderSide(color: LedgerColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('MODULE', style: style)),
          Expanded(flex: 3, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('TERMS', style: style)),
          Expanded(flex: 2, child: Text('EST. TIME', style: style)),
        ],
      ),
    );
  }
}
