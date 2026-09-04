import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

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
    final milestones = MockData.radarMilestones()
      ..sort((a, b) => a.date.compareTo(b.date));
    final bg = kIsWeb ? LedgerColors.contentBg : AppColors.bg;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
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
        child: milestones.isEmpty
            ? const _EmptyRadar()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: milestones.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) return const _RadarIntro();
                  final milestone = milestones[i - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MilestoneCard(milestone: milestone),
                  );
                },
              ),
      ),
    );
  }
}

class _RadarIntro extends StatelessWidget {
  const _RadarIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        'Real EU sustainability-regulation dates, close to today — shown as '
        'they approach or just took effect.',
        style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4),
      ),
    );
  }
}

class _EmptyRadar extends StatelessWidget {
  const _EmptyRadar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 40, color: AppColors.inkSoft),
            const SizedBox(height: 14),
            const Text(
              'Nothing on the radar right now',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No tracked regulatory date falls within the next or last '
              'few months. Check back closer to a milestone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
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
  const _MilestoneCard({required this.milestone});

  final RegulatoryMilestone milestone;

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

    return Container(
      key: Key('milestone-${milestone.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
                      ? AppColors.border
                      : AppColors.violetDeep.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  milestone.statusLabel,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isPast ? AppColors.inkSoft : AppColors.violetDeep,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDate(milestone.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Text(
                isPast ? '$days d ago' : 'in $days d',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.violetDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            milestone.title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            milestone.description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          if (module != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: AppColors.tealDeep,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Covered in: ${module.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDeep,
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
            _RegulatoryMetaRow(meta: module!.regulatory!),
          if (milestone.sourceUrl != null) ...[
            const SizedBox(height: 10),
            InkWell(
              key: Key('milestone-${milestone.id}-source'),
              onTap: () => _openSource(context, milestone.sourceUrl!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: AppColors.violetDeep,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Official source',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.violetDeep,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.violetDeep,
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
  const _RegulatoryMetaRow({required this.meta});

  final RegulatoryMeta meta;

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
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: AppColors.inkSoft),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
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
