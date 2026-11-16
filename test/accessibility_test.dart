import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sustainwise/data/models.dart';
import 'package:sustainwise/data/progress_store.dart';
import 'package:sustainwise/screens/glossary_screen.dart';
import 'package:sustainwise/screens/lesson_screen.dart';
import 'package:sustainwise/screens/regulatory_radar_screen.dart';
import 'package:sustainwise/screens/stats_screen.dart';
import 'package:sustainwise/theme/app_theme.dart';
import 'package:sustainwise/widgets/personal_path.dart';
import 'package:sustainwise/widgets/share_card.dart';

/// Android's accessibility rules, applied to every new screen: tap targets of
/// at least 48 x 48 dp and a label on every tappable thing. Contrast is
/// checked separately, from the actual colours (the framework's own contrast
/// guideline samples rendered pixels and reports false failures on thin text,
/// even on long-standing screens).
Future<void> _loadFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Outfit', 'assets/fonts/Outfit-Variable.ttf');
  await load('LoraItalic', 'assets/fonts/Lora-Italic-Variable.ttf');
  await load('monospace', 'assets/fonts/IBMPlexMono-Regular.ttf');
}

Future<void> _setUp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => MockData.load());
  ProgressStore.instance.resetForTest();
  await ProgressStore.instance.load();
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _check(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colours (1 to 21).
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('Radar: filters, bells and share icons', (tester) async {
    final handle = tester.ensureSemantics();
    await _setUp(tester);
    await _pump(tester, const RegulatoryRadarScreen());
    await _check(tester);
    handle.dispose();
  });

  testWidgets('Glossary: stars, filters, expanded actions', (tester) async {
    final handle = tester.ensureSemantics();
    await _setUp(tester);
    await _pump(tester, const GlossaryScreen(initialQuery: 'Article 8'));
    await tester.tap(find.byKey(const Key('glossary-term-Article 8 product')));
    await tester.pump(const Duration(milliseconds: 400));
    await _check(tester);
    handle.dispose();
  });

  testWidgets('Flashcard: tap targets, and the share icon is labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _setUp(tester);
    await _pump(
      tester,
      LessonScreen(
        deck: MockData.lessonFor('csrd-esrs'),
        moduleId: 'csrd-esrs',
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byKey(const Key('flashcard')));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(find.byTooltip('Share as image'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Share sheet', (tester) async {
    final handle = tester.ensureSemantics();
    await _setUp(tester);
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showShareCardSheet(
              context,
              eyebrow: 'ESG TERM',
              title: 'Double materiality',
              body: 'Looks at impact on the world and risk to the company.',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 500));
    await _check(tester);
    handle.dispose();
  });

  testWidgets('Home cards: role picker and picks', (tester) async {
    final handle = tester.ensureSemantics();
    await _setUp(tester);
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PersonalPathCard(onOpenModule: (_) {}),
        ),
      ),
    );
    await _check(tester);
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
    await _check(tester);
    handle.dispose();
  });

  testWidgets('Stats: weekly recap and weak spots', (tester) async {
    final handle = tester.ensureSemantics();
    await _setUp(tester);
    await ProgressStore.instance.completeLesson(
      moduleId: 'sfdr',
      correct: 4,
      total: 10,
    );
    await _pump(tester, const StatsScreen());
    await _check(tester);
    await tester.pump(const Duration(seconds: 2));
    handle.dispose();
  });

  test('text colours used by the new screens reach WCAG AA (4.5:1)', () {
    const white = Colors.white;
    final pairs = <String, (Color, Color)>{
      'soft text on white cards': (AppColors.inkSoft, AppColors.surface),
      'soft text on the page': (AppColors.inkSoft, AppColors.bg),
      'main text on white': (AppColors.ink, AppColors.surface),
      'teal label on the page': (AppColors.tealDeep, AppColors.bg),
      'teal label on white': (AppColors.tealDeep, AppColors.surface),
      'violet label on white': (AppColors.violetDeep, AppColors.surface),
      'amber label on white': (AppColors.amberDeep, AppColors.surface),
      'danger score on white': (AppColors.danger, AppColors.surface),
      'white on the green button': (white, AppColors.teal),
      'green "Change" link on white': (AppColors.teal, AppColors.surface),
      'share card: white on dark green': (white, const Color(0xFF14573F)),
      'share card: green accent on dark green': (
        const Color(0xFF86EFAC),
        const Color(0xFF14573F),
      ),
      'share card: gold accent on dark green': (
        const Color(0xFFFFD166),
        const Color(0xFF14573F),
      ),
    };
    for (final e in pairs.entries) {
      expect(
        contrast(e.value.$1, e.value.$2),
        greaterThanOrEqualTo(4.5),
        reason: e.key,
      );
    }
  });
}
