import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

/// Where a shared card points people to — works on every device, unlike a
/// store link.
const shareCardLink = 'https://sustainwiseapp.com';

/// Opens a preview of a square, branded card for one ESG term or Radar
/// milestone, with a Share button that sends it as an image (or, where the
/// browser cannot share files, downloads it). The card is also what ends up
/// on LinkedIn, so it carries the app name and address.
Future<void> showShareCardSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required String body,
  Color accent = const Color(0xFF86EFAC),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ShareCardSheet(
      eyebrow: eyebrow,
      title: title,
      body: body,
      accent: accent,
    ),
  );
}

/// The card content for a glossary/flashcard term.
Future<void> shareTermCard(BuildContext context, Term term) {
  final theme = term.theme;
  return showShareCardSheet(
    context,
    eyebrow: theme == null
        ? 'ESG TERM'
        : 'ESG TERM · ${theme.label.toUpperCase()}',
    title: term.term,
    body: term.plainEnglish ?? term.definition,
  );
}

/// The card content for a Regulatory Radar milestone.
Future<void> shareMilestoneCard(
  BuildContext context,
  RegulatoryMilestone milestone,
  String formattedDate,
) {
  return showShareCardSheet(
    context,
    eyebrow: 'REGULATORY RADAR · ${milestone.statusLabel}',
    title: milestone.title,
    body: '$formattedDate. ${milestone.description}',
    accent: const Color(0xFFFFD166),
  );
}

/// Renders the share card to a PNG that is 1080 px wide, whatever size the
/// preview is shown at. The Share button and the tests use this same
/// function, so what is tested is what is shared. The intermediate image is
/// released as soon as its bytes have been read.
Future<Uint8List> renderShareCardPng(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('No image data');
    // The view, not the whole underlying buffer: the buffer can be larger
    // than the data it holds.
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

class _ShareCardSheet extends StatefulWidget {
  const _ShareCardSheet({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color accent;

  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    AppFeedback.tapSilent();
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final bytes = await renderShareCardPng(boundary);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Learn ESG jargon in minutes: $shareCardLink',
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: const ['sustainwise.png'],
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Couldn't share the card. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The card is square. On a landscape phone there is not room for a 360
    // dp square plus the buttons, so it shrinks to the height that is left
    // (never below 160 dp), and the whole sheet scrolls if it still does not
    // fit, e.g. with very large system text.
    final available = MediaQuery.sizeOf(context).height - 200;
    final cardSize = available.clamp(160.0, 360.0);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardSize),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: _ShareCardFace(
                  eyebrow: widget.eyebrow,
                  title: widget.title,
                  body: widget.body,
                  accent: widget.accent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('share-card-close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const Key('share-card-share'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _busy ? null : _share,
                    icon: Icon(kIsWeb ? Icons.download : Icons.ios_share),
                    label: Text(
                      kIsWeb ? 'Share or save image' : 'Share image',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The card itself: a square, so it crops cleanly in any feed. Content that
/// is too long for the square is scaled down rather than cut off.
class _ShareCardFace extends StatelessWidget {
  const _ShareCardFace({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: AspectRatio(
        aspectRatio: 1,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: 360, height: 360, child: _face()),
        ),
      ),
    );
  }

  Widget _face() {
    return DecoratedBox(
      key: const Key('share-card-face'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2E22), Color(0xFF14573F)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eyebrow,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'SustainWise',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shareCardLink.replaceFirst('https://', ''),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
