import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

/// Who is learning: drives the "Picked for you" suggestions on Home. The
/// order in each list is the suggested order, not a restriction: every
/// module stays open.
class LearnerRole {
  const LearnerRole(this.id, this.label, this.blurb, this.moduleIds);

  final String id;
  final String label;
  final String blurb;
  final List<String> moduleIds;

  static const all = <LearnerRole>[
    LearnerRole(
      'pro',
      'Sustainability pro',
      'You work on reporting, climate or supply chains.',
      [
        'csrd-esrs',
        'climate-carbon-accounting',
        'gri-standards',
        'other-reporting-standards',
        'circular-economy-biodiversity',
        'greenwashing-empco-ucpd',
      ],
    ),
    LearnerRole(
      'finance',
      'Compliance & finance',
      'You deal with investors, funds, risk or legal.',
      [
        'sfdr',
        'eu-taxonomy',
        'sustainable-finance-ethical-investing',
        'esg-ratings-data-providers',
        'csddd',
        'governance-anti-corruption',
      ],
    ),
    LearnerRole(
      'curious',
      'ESG-curious',
      'You want to follow the conversation.',
      [
        'esg-fundamentals',
        'csr-ethics',
        'climate-carbon-accounting',
        'social-issues-human-rights',
        'key-players-institutions',
        'timeline-milestones',
      ],
    ),
  ];

  static LearnerRole? byId(String? id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Up to [limit] modules from this role's list that are not completed yet,
  /// in the suggested order.
  List<ModuleProgress> nextModules(ProgressStore store, {int limit = 3}) {
    final out = <ModuleProgress>[];
    for (final id in moduleIds) {
      final m = MockData.moduleById(id);
      if (m == null) continue;
      if (store.statusFor(id) == ModuleStatus.done) continue;
      out.add(m);
      if (out.length == limit) break;
    }
    return out;
  }
}

/// On Home: asks once who you are, then shows the next few modules that fit.
class PersonalPathCard extends StatelessWidget {
  const PersonalPathCard({
    super.key,
    required this.onOpenModule,
    this.ledger = false,
  });

  final void Function(ModuleProgress module) onOpenModule;

  /// Desktop web's "The Ledger": the caller already provides the card frame
  /// (a titled side card), so only the content is built here, in Ledger
  /// tokens. Everything else keeps the app's own look.
  final bool ledger;

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    final role = LearnerRole.byId(store.learnerRole);
    if (ledger) {
      return role == null
          ? _buildPicker(store, true)
          : _buildPicks(store, role, true);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        key: const Key('personal-path-card'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: role == null
            ? _buildPicker(store, false)
            : _buildPicks(store, role, false),
      ),
    );
  }

  Widget _buildPicker(ProgressStore store, bool ledger) {
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    final soft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    final rowBg = ledger ? LedgerColors.neutralSoft : AppColors.bg;
    final font = ledger ? LedgerColors.fontSans : null;
    final radius = ledger ? 6.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What describes you best?',
          style: TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: ledger ? FontWeight.w600 : FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "We'll suggest where to start. Every module stays open.",
          style: TextStyle(fontFamily: font, fontSize: 12.5, color: soft),
        ),
        const SizedBox(height: 10),
        for (final r in LearnerRole.all)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: rowBg,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                key: Key('role-${r.id}'),
                borderRadius: BorderRadius.circular(radius),
                onTap: () {
                  AppFeedback.tap();
                  store.setLearnerRole(r.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.label,
                              style: TextStyle(
                                fontFamily: font,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            Text(
                              r.blurb,
                              style: TextStyle(
                                fontFamily: font,
                                fontSize: 12,
                                color: soft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: soft),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPicks(ProgressStore store, LearnerRole role, bool ledger) {
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    final soft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    final rowBg = ledger ? LedgerColors.neutralSoft : AppColors.bg;
    final font = ledger ? LedgerColors.fontSans : null;
    final radius = ledger ? 6.0 : 12.0;
    final accent = ledger ? LedgerColors.teal : AppColors.tealDeep;
    final next = role.nextModules(store);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ledger ? role.label : 'Picked for you · ${role.label}',
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 14.5,
                  fontWeight: ledger ? FontWeight.w600 : FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
            TextButton(
              key: const Key('role-change'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: ledger ? LedgerColors.teal : null,
              ),
              onPressed: () {
                AppFeedback.tap();
                store.setLearnerRole(null);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        if (next.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              ledger
                  ? "You've finished everything we suggest for you. Browse "
                        'the full path for the rest.'
                  : "You've finished everything we suggest for you. Browse "
                        'the path below for the rest.',
              style: TextStyle(fontFamily: font, fontSize: 12.5, color: soft),
            ),
          )
        else
          for (final m in next)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Material(
                color: rowBg,
                borderRadius: BorderRadius.circular(radius),
                child: InkWell(
                  key: Key('pick-${m.id}'),
                  borderRadius: BorderRadius.circular(radius),
                  onTap: () {
                    AppFeedback.tap();
                    onOpenModule(m);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: TextStyle(
                                  fontFamily: font,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              Text(
                                m.summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: font,
                                  fontSize: 12,
                                  color: soft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.play_circle_outline,
                          size: 22,
                          color: accent,
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
}
