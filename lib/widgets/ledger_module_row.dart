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
        LedgerColors.gold,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        module.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: LedgerColors.fontSans,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      pillLabel,
                      style: TextStyle(
                        fontFamily: LedgerColors.fontMono,
                        fontSize: 10,
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
                    fontSize: 12,
                    color: LedgerColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  status == ModuleStatus.done ? '—' : '$minutes min',
                  style: const TextStyle(
                    fontFamily: LedgerColors.fontMono,
                    fontSize: 12,
                    color: LedgerColors.inkSoft,
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
