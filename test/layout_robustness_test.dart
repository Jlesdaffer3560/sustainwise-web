import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sustainwise/data/models.dart';
import 'package:sustainwise/data/progress_store.dart';
import 'package:sustainwise/screens/glossary_screen.dart';
import 'package:sustainwise/screens/lesson_screen.dart';
import 'package:sustainwise/screens/regulatory_radar_screen.dart';
import 'package:sustainwise/screens/progress_screen.dart';
import 'package:sustainwise/theme/app_theme.dart';
import 'package:sustainwise/widgets/personal_path.dart';
import 'package:sustainwise/widgets/share_card.dart';

/// Phones come in many shapes: a small one, a large one, landscape, and
/// people who raise the system font size. Pumping each new screen in each of
/// those conditions, and failing on any overflow, is a real layout check.
///
/// Android's own "largest" font setting is about 1.3x, so 1.3 is the
/// realistic upper bound; 1.0 is the default. (2.0 is far beyond what the
/// system offers and is not tested.)
const _viewports = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'normal phone 360x740': Size(360, 740),
  'large phone 412x915': Size(412, 915),
  'landscape 740x360': Size(740, 360),
};
const _textScales = [1.0, 1.3];

/// flutter_test draws every font as the wide, square "Ahem" test font unless
/// told otherwise, which makes almost anything overflow. Load the app's real
/// body font, and a real monospace for the code-style labels, so widths here
/// match what a phone shows. (The tests also use AppTheme.light, which is
/// what selects the Outfit font in the app.)
Future<void> _loadFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Outfit', 'assets/fonts/Outfit-Variable.ttf');
  await load('LoraItalic', 'assets/fonts/Lora-Italic-Variable.ttf');
  // Android's built-in monospace is about 0.6 em per character, like Plex Mono.
  await load('monospace', 'assets/fonts/IBMPlexMono-Regular.ttf');
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pump(const Duration(milliseconds: 500));
}

/// One layout test: set the viewport and font scale, collect every framework
/// error raised while [body] runs, and fail with the offending widget named.
void layoutTest(
  String name,
  Size size,
  double scale,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => MockData.load());
    ProgressStore.instance.resetForTest();
    await ProgressStore.instance.load();

    final original = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    try {
      await body(tester);
    } finally {
      FlutterError.onError = original;
    }
    if (errors.isNotEmpty) {
      final d = errors.first;
      final where = [
        for (final n in d.informationCollector?.call() ?? const [])
          n.toString().replaceAll('\n', ' '),
      ].join(' / ');
      fail(
        '${errors.length} layout error(s). ${d.exceptionAsString()} '
        '$where',
      );
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final v in _viewports.entries) {
    for (final scale in _textScales) {
      final label = '${v.key}, text x$scale';

      layoutTest(
        'flashcard front, back and share card: $label',
        v.value,
        scale,
        (tester) async {
          // The CSRD deck has the longest terms in the app.
          final deck = MockData.lessonFor('csrd-esrs');
          await _pump(tester, LessonScreen(deck: deck, moduleId: 'csrd-esrs'));
          await tester.tap(find.byKey(const Key('flashcard')));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const Key('flashcard-share')));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byKey(const Key('share-card-face')), findsOneWidget);
        },
      );

      layoutTest('Radar with chips and share icons: $label', v.value, scale, (
        tester,
      ) async {
        await _pump(tester, const RegulatoryRadarScreen());
        for (final f in ['upcoming', 'past', 'all']) {
          await tester.tap(find.byKey(Key('radar-filter-$f')));
          await tester.pump(const Duration(milliseconds: 200));
        }
      });

      layoutTest(
        'Glossary row, favourites and expanded actions: $label',
        v.value,
        scale,
        (tester) async {
          await _pump(tester, const GlossaryScreen(initialQuery: 'Article 8'));
          await tester.tap(
            find.byKey(const Key('glossary-term-Article 8 product')),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.byKey(const Key('glossary-related-Article 8 product')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('glossary-filter-favorites')));
          await tester.pump();
        },
      );

      layoutTest('Home cards: role picker and picks: $label', v.value, scale, (
        tester,
      ) async {
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: PersonalPathCard(onOpenModule: (_) {}),
            ),
          ),
        );
        await ProgressStore.instance.setLearnerRole('finance');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PersonalPathCard(key: UniqueKey(), onOpenModule: (_) {}),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      });

      layoutTest('Progress with weak spots: $label', v.value, scale, (
        tester,
      ) async {
        await ProgressStore.instance.completeLesson(
          moduleId: 'sfdr',
          correct: 4,
          total: 10,
        );
        await _pump(tester, const ProgressScreen());
        await tester.scrollUntilVisible(
          find.byKey(const Key('weak-spots-card')),
          200,
          // The page scroller, not the (non-scrolling) milestones grid.
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(const Key('weak-spots-card')), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }

  layoutTest(
    'share sheet works for a very long term and body',
    const Size(320, 568),
    1.3,
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showShareCardSheet(
                  context,
                  eyebrow: 'ESG TERM · REGULATION',
                  title: 'Double materiality assessment (DMA) under the CSRD',
                  body: List.filled(
                    6,
                    'A long explanation sentence for the card.',
                  ).join(' '),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('share-card-face')), findsOneWidget);
    },
  );
}
