import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../web/responsive.dart';

/// "Living content instead of static content" — the one screen in the app
/// that reads differently depending on when you open it. Every date here is
/// real (EU sustainability regulation entering into force / becoming
/// applicable), bundled the same way as the rest of the content, but
/// evaluated fresh against [DateTime.now()] rather than stated as a fixed
/// fact — so it stays accurate without a content update every time a date
/// passes.
class RegulatoryRadarScreen extends StatelessWidget {
  const RegulatoryRadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // radarMilestones() already orders soonest-upcoming first, then
    // most-recent-past — re-sorting here by plain date.compareTo() would
    // put the oldest past milestone at the very top instead, which is
    // exactly the ordering bug this screen was showing.
    final milestones = MockData.radarMilestones();
    // Desktop-web only, matching Glossary/Progress — narrow web keeps the
    // exact same look as native (see the "small screen should feel like
    // the app" requirement), so only the >=900px breakpoint switches to
    // "The Ledger" tokens. This used to key off plain kIsWeb, which quietly
    // painted narrow web with LedgerColors.contentBg too (invisible in
    // practice — it's a hair's difference from AppColors.bg — but wrong).
    final ledger = isDesktopWeb(context);
    final bg = ledger ? LedgerColors.contentBg : AppColors.bg;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: ledger ? LedgerColors.ink : AppColors.ink,
        title: Text(
          'Regulatory Radar',
          style: TextStyle(
            fontFamily: kIsWeb ? LedgerColors.fontSans : null,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        // This screen sits outside DesktopShell entirely (see
        // home_screen.dart — it's a drill-down, not a sidebar peer), so it
        // never got the same max-width constraint every other desktop-web
        // page has. Without it, cards stretched edge-to-edge across the
        // full browser width, with description text wrapping into single
        // lines far past a comfortable reading width. Native and narrow
        // web are untouched — this list was always meant to fill a phone
        // screen's width.
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ledger ? 640 : double.infinity),
            child: milestones.isEmpty
                ? _EmptyRadar(ledger: ledger)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: milestones.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _RadarIntro(ledger: ledger);
                      final milestone = milestones[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MilestoneCard(
                          milestone: milestone,
                          ledger: ledger,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _RadarIntro extends StatelessWidget {
  const _RadarIntro({required this.ledger});

  final bool ledger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        'Real EU sustainability-regulation dates, close to today — shown as '
        'they approach or just took effect.',
        style: TextStyle(
          fontFamily: ledger ? LedgerColors.fontSans : null,
          fontSize: 13,
          color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
          height: 1.4,
        ),
      ),
    );
  }
}

class _EmptyRadar extends StatelessWidget {
  const _EmptyRadar({required this.ledger});

  final bool ledger;

  @override
  Widget build(BuildContext context) {
    final soft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 40, color: soft),
            const SizedBox(height: 14),
            Text(
              'Nothing on the radar right now',
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No tracked regulatory date falls within the next or last '
              'few months. Check back closer to a milestone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontSize: 13,
                color: soft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone, required this.ledger});

  final RegulatoryMilestone milestone;
  final bool ledger;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec', //
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _openSource(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = MockData.moduleById(milestone.moduleId);
    final isPast = milestone.isPast;
    final days = milestone.date.difference(DateTime.now()).inDays.abs();

    // Ledger status color: goldDeep for what's still ahead (same tone
    // LedgerModuleRow uses for "in progress"), a plain neutral for what's
    // already passed — status-driven, not the violetDeep accent this card
    // uses everywhere else. Matches the rest of "The Ledger": modules on
    // Home's desktop table read by status color, not by a fixed hue.
    final accent = ledger
        ? (isPast ? LedgerColors.inkSoft : LedgerColors.goldDeep)
        : AppColors.violetDeep;
    final cardColor = ledger ? LedgerColors.card : AppColors.surface;
    final borderColor = ledger ? LedgerColors.border : AppColors.border;
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    final inkSoft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    final sansFont = ledger ? LedgerColors.fontSans : null;
    final monoFont = ledger ? LedgerColors.fontMono : 'monospace';

    return Container(
      key: Key('milestone-${milestone.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(ledger ? 6 : 18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isPast
                      ? (ledger ? LedgerColors.neutralSoft : AppColors.border)
                      : (ledger
                            ? LedgerColors.goldSoft
                            : AppColors.violetDeep.withValues(alpha: 0.14)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  milestone.statusLabel,
                  style: TextStyle(
                    fontFamily: monoFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isPast ? inkSoft : accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDate(milestone.date),
                  style: TextStyle(
                    fontFamily: sansFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: inkSoft,
                  ),
                ),
              ),
              Text(
                isPast ? '$days d ago' : 'in $days d',
                style: TextStyle(
                  fontFamily: sansFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            milestone.title,
            style: TextStyle(
              fontFamily: sansFont,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            milestone.description,
            style: TextStyle(
              fontFamily: sansFont,
              fontSize: 13.5,
              color: inkSoft,
              height: 1.4,
            ),
          ),
          if (module != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: ledger ? LedgerColors.teal : AppColors.tealDeep,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Covered in: ${module.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: sansFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ledger ? LedgerColors.teal : AppColors.tealDeep,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Web only: source/jurisdiction/status/last-reviewed detail, per
          // direct request for the Radar to "look more credible" to an
          // ESG/regulatory audience — this is real metadata the app
          // already carries on the module (RegulatoryMeta), just not shown
          // anywhere before. The native app's card is unchanged.
          if (kIsWeb && module?.regulatory?.hasContent == true)
            _RegulatoryMetaRow(meta: module!.regulatory!, ledger: ledger),
          if (milestone.sourceUrl != null) ...[
            const SizedBox(height: 10),
            InkWell(
              key: Key('milestone-${milestone.id}-source'),
              onTap: () => _openSource(context, milestone.sourceUrl!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: ledger ? LedgerColors.teal : AppColors.violetDeep,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Official source',
                    style: TextStyle(
                      fontFamily: sansFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ledger ? LedgerColors.teal : AppColors.violetDeep,
                      decoration: TextDecoration.underline,
                      decorationColor: ledger
                          ? LedgerColors.teal
                          : AppColors.violetDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Web only: a small labeled-chip row for the module's regulatory
/// metadata (jurisdiction, status, last reviewed, version) — real data the
/// app already carries, just newly surfaced here for a regulatory/ESG
/// audience that wants to see provenance, not only a date and a title.
class _RegulatoryMetaRow extends StatelessWidget {
  const _RegulatoryMetaRow({required this.meta, required this.ledger});

  final RegulatoryMeta meta;
  final bool ledger;

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String)>[
      if (meta.jurisdiction != null) (Icons.public, meta.jurisdiction!),
      if (meta.status != null) (Icons.verified_outlined, meta.status!),
      if (meta.lastReviewed != null)
        (Icons.fact_check_outlined, 'Reviewed ${meta.lastReviewed}'),
      if (meta.version != null) (Icons.history, meta.version!),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    final chipBg = ledger ? LedgerColors.neutralSoft : AppColors.bg;
    final chipBorder = ledger ? LedgerColors.border : AppColors.border;
    final chipText = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (icon, label) in chips)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: chipBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: chipText),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: ledger ? LedgerColors.fontSans : null,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: chipText,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
