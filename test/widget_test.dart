import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:regulingo/data/models.dart';
import 'package:regulingo/data/progress_store.dart';
import 'package:regulingo/main.dart';

// The CSRD & ESRS module's real content, from assets/data/esg_content.json.
// Quiz option shuffling is seeded deterministically per module (see
// MockData._stableHash), so these positions are stable across runs.
const _csrdTermCount = 24;
const _quizCorrectIndices = [2, 2, 1, 1, 3]; // Q0..Q4
const _pairsCorrectIndices = [0, 1]; // CSRD-vs-NFRD, Limited-vs-Reasonable assurance

Future<void> pumpFreshApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // rootBundle.loadString does real file I/O in the test environment, which
  // hangs forever inside testWidgets' fake-async zone unless run for real.
  await tester.runAsync(() => MockData.load());
  ProgressStore.instance.resetForTest();
  await ProgressStore.instance.load();
  await tester.pumpWidget(const EsgJargonApp());
}

Future<void> openCurrentLesson(WidgetTester tester) async {
  final startNode = find.byKey(const Key('module-node-csrd-esrs'));
  await tester.scrollUntilVisible(
    startNode,
    100,
    scrollable: find.descendant(
      of: find.byKey(const Key('module-path-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(startNode);
  await tester.pumpAndSettle();
}

Future<void> completeFlashcards(WidgetTester tester) async {
  for (var i = 0; i < _csrdTermCount; i++) {
    await tester.tap(find.byKey(const Key('flashcard')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('flashcard-rating-got-it')));
    await tester.pumpAndSettle();
  }
}

// Full-sentence quiz/pair options run taller than the default test
// viewport, so the Continue button can end up scrolled out of view —
// ensureVisible scrolls its nearest Scrollable ancestor before tapping.
Future<void> tapAndEnsureVisible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
}

Future<void> answerAllQuizQuestions(WidgetTester tester) async {
  for (final correctIndex in _quizCorrectIndices) {
    await tapAndEnsureVisible(tester, Key('quiz-option-$correctIndex'));
    await tester.pump();
    await tapAndEnsureVisible(tester, const Key('quiz-continue-button'));
    await tester.pumpAndSettle();
  }
}

Future<void> answerAllPairs(WidgetTester tester) async {
  for (final correctIndex in _pairsCorrectIndices) {
    await tapAndEnsureVisible(tester, Key('pair-chip-$correctIndex'));
    await tester.pump();
    await tapAndEnsureVisible(tester, const Key('pairs-continue-button'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('Home screen shows streak, XP and the module path', (WidgetTester tester) async {
    await pumpFreshApp(tester);

    expect(find.text('12'), findsOneWidget); // streak days
    expect(find.text('1,240'), findsOneWidget); // total XP
    expect(find.text('ESG Fundamentals'), findsOneWidget);
    expect(find.text('CSDDD'), findsOneWidget);
    // The current module's row leads with a "Start here" prompt and shows
    // its own title as the subtitle underneath.
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('CSRD & ESRS'), findsOneWidget);
  });

  testWidgets('Tapping an unstarted module shows a snackbar, not a crash', (WidgetTester tester) async {
    await pumpFreshApp(tester);

    final sfdrNode = find.byKey(const Key('module-node-sfdr'));
    await tester.scrollUntilVisible(sfdrNode, 100, scrollable: find.descendant(
      of: find.byKey(const Key('module-path-scroll')),
      matching: find.byType(Scrollable),
    ));
    await tester.tap(sfdrNode);
    await tester.pump();

    expect(find.text('SFDR — not started yet'), findsOneWidget);
  });

  testWidgets('Flashcard rating buttons are inert until the card is flipped', (WidgetTester tester) async {
    await pumpFreshApp(tester);
    await openCurrentLesson(tester);

    // The real deck's first term.
    expect(find.text('NFRD'), findsOneWidget);
    expect(find.text('Tap card to reveal definition'), findsOneWidget);

    // Tapping "Got it" before flipping is blocked by an IgnorePointer —
    // confirm it truly does nothing rather than just checking it works
    // after the flip.
    await tester.tap(find.byKey(const Key('flashcard-rating-got-it')));
    await tester.pump();
    expect(find.text('NFRD'), findsOneWidget);
    expect(find.text('Tap card to reveal definition'), findsOneWidget);

    await tester.tap(find.text('NFRD'));
    await tester.pump();
    expect(find.textContaining('Non-Financial Reporting Directive'), findsOneWidget);

    // Now that the card is flipped, the same button should work and move
    // on to the deck's second term.
    await tester.tap(find.byKey(const Key('flashcard-rating-got-it')));
    await tester.pump();
    expect(find.text('CSRD'), findsOneWidget);
  });

  testWidgets('Finishing the flashcard deck leads into a quiz generated from the real terms', (WidgetTester tester) async {
    await pumpFreshApp(tester);
    await openCurrentLesson(tester);
    await completeFlashcards(tester);

    expect(find.text("Which definition matches 'NFRD'?"), findsOneWidget);

    // Tap the correct (deterministically shuffled) answer and confirm
    // feedback + explanation appear.
    await tester.tap(find.byKey(Key('quiz-option-${_quizCorrectIndices[0]}')));
    await tester.pump();
    // The explanation is prefixed with the term name in quotes, unlike the
    // option tile itself — a substring that's unique to it.
    expect(find.textContaining("'NFRD':"), findsOneWidget);

    await tapAndEnsureVisible(tester, const Key('quiz-continue-button'));
    await tester.pumpAndSettle();
    expect(find.text("Which definition matches 'ESRS 1'?"), findsOneWidget);
  });

  testWidgets('Answering a quiz question incorrectly still shows the explanation and a working Continue', (WidgetTester tester) async {
    await pumpFreshApp(tester);
    await openCurrentLesson(tester);
    await completeFlashcards(tester);

    // Deliberately tap a wrong option (anything other than the correct one).
    final wrongIndex = (_quizCorrectIndices[0] + 1) % 4;
    await tester.tap(find.byKey(Key('quiz-option-$wrongIndex')));
    await tester.pump();
    expect(find.textContaining("'NFRD':"), findsOneWidget);
    expect(find.byKey(const Key('quiz-continue-button')), findsOneWidget);

    await tapAndEnsureVisible(tester, const Key('quiz-continue-button'));
    await tester.pumpAndSettle();
    expect(find.text("Which definition matches 'ESRS 1'?"), findsOneWidget);
  });

  testWidgets('Finishing the quiz leads into confusable pairs, which can be answered', (WidgetTester tester) async {
    await pumpFreshApp(tester);
    await openCurrentLesson(tester);
    await completeFlashcards(tester);
    await answerAllQuizQuestions(tester);

    expect(find.text('WHICH IS WHICH?'), findsOneWidget);
    expect(find.text('CSRD'), findsOneWidget);
    expect(find.text('NFRD'), findsOneWidget);

    // Answer the first confusable pair and confirm feedback appears.
    await tester.tap(find.byKey(Key('pair-chip-${_pairsCorrectIndices[0]}')));
    await tester.pump();
    expect(find.textContaining('Replaced and expanded the 2014 NFRD'), findsOneWidget);

    await tapAndEnsureVisible(tester, const Key('pairs-continue-button'));
    await tester.pumpAndSettle();
    expect(find.text('Limited assurance'), findsOneWidget);
  });

  testWidgets('Answering every quiz question and pair correctly gives a perfect Lesson Complete score', (WidgetTester tester) async {
    await pumpFreshApp(tester);
    await openCurrentLesson(tester);
    await completeFlashcards(tester);
    await answerAllQuizQuestions(tester);
    await answerAllPairs(tester);

    expect(find.text('Lesson complete!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget); // accuracy
    expect(find.text('7/7'), findsOneWidget); // correct (5 quiz + 2 pairs)
    expect(find.text('48'), findsOneWidget); // cumulative terms learned
    expect(find.text('3/16'), findsOneWidget); // modules done, out of the full 16-module curriculum
    // The seeded 12-day streak should extend to 13, not reset to 1 — a
    // fresh install seeds "last practiced" as yesterday for exactly this.
    expect(find.textContaining('13-day streak'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lesson-complete-continue-button')));
    await tester.pumpAndSettle();

    // Back on Home, with the streak pill reflecting the same update.
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
  });

  testWidgets('Profile tab opens the Profile screen and Path returns to Home', (WidgetTester tester) async {
    await pumpFreshApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Jordi'), findsOneWidget);

    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();
    expect(find.text('Start here'), findsOneWidget);
  });

  testWidgets('Stats tab shows weekly activity and per-unit progress, and tabs switch cleanly', (WidgetTester tester) async {
    await pumpFreshApp(tester);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Your stats'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Progress by unit'), findsOneWidget);
    expect(find.text('Unit 1 · Foundations'), findsOneWidget);

    // Switching to Profile from Stats should replace the screen, not stack it.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Jordi'), findsOneWidget);

    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();
    expect(find.text('Start here'), findsOneWidget);
  });
}
