import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sustainwise/data/models.dart';
import 'package:sustainwise/data/progress_store.dart';
import 'package:sustainwise/main.dart';
import 'package:sustainwise/screens/glossary_screen.dart';
import 'package:sustainwise/screens/regulatory_radar_screen.dart';
import 'package:sustainwise/theme/app_theme.dart';
import 'package:sustainwise/widgets/personal_path.dart';
import 'package:sustainwise/widgets/share_card.dart';
import 'package:sustainwise/widgets/weak_spots_card.dart';

Future<void> pumpFreshApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => MockData.load());
  ProgressStore.instance.resetForTest();
  await ProgressStore.instance.load();
  await tester.pumpWidget(const EsgJargonApp());
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Removes any snackbar on screen, so the next one is shown straight away
/// instead of waiting in the queue behind it.
Future<void> clearSnackBars(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .clearSnackBars();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> openFirstLesson(WidgetTester tester) async {
  final node = find.byKey(const Key('module-node-esg-fundamentals'));
  await tester.scrollUntilVisible(
    node,
    100,
    scrollable: find.descendant(
      of: find.byKey(const Key('module-path-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(node);
  await pumpBounded(tester);
}

Future<void> tapVisible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
}

/// Pumps a single screen with real content loaded and a clean store.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => MockData.load());
  ProgressStore.instance.resetForTest();
  await ProgressStore.instance.load();
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
}

void main() {
  tearDown(() => ProgressStore.instance.resetForTest());

  group('flashcard swipe', () {
    testWidgets('a flick only rates a card once it has been flipped', (
      tester,
    ) async {
      await pumpFreshApp(tester);
      await openFirstLesson(tester);
      expect(find.text('Card 1 of 14'), findsOneWidget);

      // Face-down: nothing happens, so a stray swipe cannot rate a term the
      // learner has not seen the answer to.
      await tester.fling(
        find.byKey(const Key('flashcard')),
        const Offset(300, 0),
        1000,
      );
      await pumpBounded(tester);
      expect(find.text('Card 1 of 14'), findsOneWidget);

      await tester.tap(find.byKey(const Key('flashcard')));
      await tester.pump();
      await tester.fling(
        find.byKey(const Key('flashcard')),
        const Offset(300, 0),
        1000,
      );
      await pumpBounded(tester);
      expect(find.text('Card 2 of 14'), findsOneWidget);
    });

    testWidgets('swiping left counts as "Still learning" and queues a review', (
      tester,
    ) async {
      await pumpFreshApp(tester);
      await openFirstLesson(tester);
      final first = MockData.lessonFor('esg-fundamentals').first;
      expect(ProgressStore.instance.isScheduled(first.id), isFalse);

      await tester.tap(find.byKey(const Key('flashcard')));
      await tester.pump();
      await tester.fling(
        find.byKey(const Key('flashcard')),
        const Offset(-300, 0),
        1000,
      );
      await pumpBounded(tester);

      expect(find.text('Card 2 of 14'), findsOneWidget);
      expect(ProgressStore.instance.isScheduled(first.id), isTrue);
    });

    testWidgets(
      'the shared image is a 1080 x 1080 PNG, whatever the preview size',
      (tester) async {
        addTearDown(tester.view.reset);
        for (final size in const [
          Size(800, 600),
          Size(740, 360),
          Size(320, 568),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showShareCardSheet(
                      context,
                      eyebrow: 'ESG TERM',
                      title: 'Double materiality',
                      body:
                          'Looks at impact on the world and risk to the company.',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pump(const Duration(milliseconds: 500));

          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find
                .ancestor(
                  of: find.byKey(const Key('share-card-face')),
                  matching: find.byType(RepaintBoundary),
                )
                .first,
          );
          // The very function the Share button uses.
          final bytes = await tester.runAsync(
            () => renderShareCardPng(boundary),
          );
          expect(bytes!.sublist(0, 4), [
            0x89,
            0x50,
            0x4E,
            0x47,
          ], reason: '$size');
          final header = ByteData.sublistView(bytes);
          // PNG: width and height are the first two numbers in the IHDR chunk.
          expect(header.getUint32(16), 1080, reason: 'width at $size');
          expect(header.getUint32(20), 1080, reason: 'height at $size');

          await tester.tap(find.byKey(const Key('share-card-close')));
          await tester.pump(const Duration(milliseconds: 500));
        }
      },
    );

    testWidgets(
      'distance or speed decides a swipe; a small slow drag does nothing',
      (tester) async {
        await pumpFreshApp(tester);
        await openFirstLesson(tester);
        await tester.tap(find.byKey(const Key('flashcard')));
        await tester.pump();

        // A small, slow drag: not a swipe.
        await tester.drag(
          find.byKey(const Key('flashcard')),
          const Offset(30, 0),
        );
        await pumpBounded(tester);
        expect(find.text('Card 1 of 14'), findsOneWidget);

        // Mostly vertical movement is for scrolling the card, not rating it.
        await tester.drag(
          find.byKey(const Key('flashcard')),
          const Offset(10, 120),
        );
        await pumpBounded(tester);
        expect(find.text('Card 1 of 14'), findsOneWidget);

        // A long, deliberate drag counts even when it is slow.
        await tester.drag(
          find.byKey(const Key('flashcard')),
          const Offset(160, 0),
        );
        await pumpBounded(tester);
        expect(find.text('Card 2 of 14'), findsOneWidget);

        // A short but fast flick counts too, and goes by direction. Built from
        // timed pointer events (50 px in 40 ms is about 1,250 px/s): the
        // distance is far below the swipe distance, so only speed can count it.
        final second = MockData.lessonFor('esg-fundamentals')[1];
        await tester.tap(find.byKey(const Key('flashcard')));
        await tester.pump();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('flashcard'))),
        );
        for (var i = 1; i <= 5; i++) {
          await gesture.moveBy(
            const Offset(-10, 0),
            timeStamp: Duration(milliseconds: i * 8),
          );
        }
        await gesture.up(timeStamp: const Duration(milliseconds: 48));
        await pumpBounded(tester);
        expect(find.text('Card 3 of 14'), findsOneWidget);
        expect(ProgressStore.instance.isScheduled(second.id), isTrue);
      },
    );

    testWidgets('the share button appears with the answer and opens a card', (
      tester,
    ) async {
      await pumpFreshApp(tester);
      await openFirstLesson(tester);

      await tester.tap(find.byKey(const Key('flashcard')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('flashcard-share')));
      await pumpBounded(tester);

      expect(find.byKey(const Key('share-card-face')), findsOneWidget);
      expect(find.byKey(const Key('share-card-share')), findsOneWidget);
      expect(find.text('sustainwiseapp.com'), findsOneWidget);
    });
  });

  testWidgets(
    'quiz answers show why the term matters, not only the definition',
    (tester) async {
      await pumpFreshApp(tester);
      await openFirstLesson(tester);
      for (var i = 0; i < 14; i++) {
        await tester.tap(find.byKey(const Key('flashcard')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('flashcard-rating-got-it')));
        await pumpBounded(tester);
      }

      expect(find.byKey(const Key('term-insight')), findsNothing);
      var insights = 0;
      for (final correctIndex in const [2, 2, 2, 2, 1, 1, 3, 2, 0]) {
        await tapVisible(tester, Key('quiz-option-$correctIndex'));
        await tester.pump();
        if (find.byKey(const Key('term-insight')).evaluate().isNotEmpty) {
          insights++;
          expect(find.text('WHY IT MATTERS'), findsOneWidget);
        }
        await tapVisible(tester, const Key('quiz-continue-button'));
        await tester.pumpAndSettle();
      }
      // 7 of the 9 questions test a term; the other 2 are scenario questions.
      expect(insights, 7);
    },
  );

  group('personal path on Home', () {
    testWidgets('asks who you are once, then suggests modules', (tester) async {
      await pumpFreshApp(tester);
      expect(find.text('What describes you best?'), findsOneWidget);

      await tapVisible(tester, const Key('role-finance'));
      await tester.pump();
      expect(find.textContaining('Picked for you'), findsOneWidget);
      expect(ProgressStore.instance.learnerRole, 'finance');
      // The first suggestion for this role that is not done yet.
      expect(find.byKey(const Key('pick-sfdr')), findsOneWidget);

      // A finished module drops out of the suggestions.
      await ProgressStore.instance.completeLesson(
        moduleId: 'sfdr',
        correct: 9,
        total: 10,
      );
      await tester.pump();
      expect(find.byKey(const Key('pick-sfdr')), findsNothing);
      expect(find.byKey(const Key('pick-eu-taxonomy')), findsOneWidget);

      await tapVisible(tester, const Key('role-change'));
      await tester.pump();
      expect(find.text('What describes you best?'), findsOneWidget);
      // Let the flame flourish Home plays when a streak starts finish, so no
      // timer is left pending when the test ends.
      await tester.pump(const Duration(seconds: 2));
    });

    test(
      'every suggested module exists and no role repeats a module',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});
        await MockData.load();
        for (final role in LearnerRole.all) {
          expect(role.moduleIds.toSet().length, role.moduleIds.length);
          for (final id in role.moduleIds) {
            expect(
              MockData.moduleById(id),
              isNotNull,
              reason: '${role.id}: $id',
            );
          }
        }
      },
    );
  });

  group('glossary favourites and related terms', () {
    testWidgets('a starred term shows up under Favourites', (tester) async {
      await pumpScreen(
        tester,
        const GlossaryScreen(initialQuery: 'materiality'),
      );
      expect(
        find.byKey(const Key('glossary-term-Materiality')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('glossary-term-Double materiality')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('glossary-favorite-Materiality')));
      await tester.pump();
      expect(
        ProgressStore.instance.isFavorite(
          MockData.allTerms.firstWhere((t) => t.term == 'Materiality').id ??
              'Materiality',
        ),
        isTrue,
      );
      expect(find.text('Favourites (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('glossary-filter-favorites')));
      await tester.pump();
      expect(
        find.byKey(const Key('glossary-term-Materiality')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('glossary-term-Double materiality')),
        findsNothing,
      );
    });

    test(
      '"Don\'t confuse with" names resolve to real glossary terms',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});
        await MockData.load();
        // The matching rule: exact name, name plus a parenthetical, or a term
        // that starts with the name.
        expect(MockData.relatedTermNamed('DNSH')?.term, startsWith('DNSH'));
        expect(MockData.relatedTermNamed('Scope 2')?.term, 'Scope 2 emissions');
        expect(MockData.relatedTermNamed('no such term at all'), isNull);

        // An exact name always wins over a longer term that merely starts
        // with it, whatever order the content file happens to list them in.
        for (final t in MockData.allTerms) {
          expect(
            MockData.relatedTermNamed(t.term)?.term,
            t.term,
            reason: '"${t.term}" must resolve to itself',
          );
        }
        // Several partial matches: the shortest, most general one.
        expect(MockData.relatedTermNamed('Scope 2')?.term, 'Scope 2 emissions');
        // The term being looked at is never offered as its own link.
        final scope2 = MockData.allTerms.firstWhere(
          (t) => t.term == 'Scope 2 emissions',
        );
        expect(
          MockData.relatedTermNamed('Scope 2', except: scope2)?.term,
          isNot('Scope 2 emissions'),
        );

        var total = 0;
        var resolved = 0;
        for (final t in MockData.allTerms) {
          final raw = t.dontConfuseWith;
          final i = raw?.indexOf(' — ') ?? -1;
          if (raw == null || i <= 0) continue;
          total++;
          if (MockData.relatedTermNamed(raw.substring(0, i), except: t) !=
              null) {
            resolved++;
          }
        }
        // Most links should work; a few point at things that are not terms.
        expect(resolved / total, greaterThan(0.8));
      },
    );
  });

  group('Regulatory Radar', () {
    // Dates relative to the real clock, so these tests never go stale.
    DateTime inDays(int days) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + days);
    }

    RegulatoryMilestone milestone(String id, int days) => RegulatoryMilestone(
      id: id,
      date: inDays(days),
      title: 'Test date $id',
      description: 'Description of $id.',
      moduleId: 'esg-fundamentals',
      type: MilestoneType.applicable,
    );

    Future<void> pumpRadar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => MockData.load());
      final original = MockData.regulatoryMilestones;
      MockData.regulatoryMilestones = [
        milestone('milestone_901', -40),
        milestone('milestone_902', -1),
        milestone('milestone_905', 0),
        milestone('milestone_903', 45),
        milestone('milestone_904', 400),
      ];
      addTearDown(() => MockData.regulatoryMilestones = original);
      ProgressStore.instance.resetForTest();
      await ProgressStore.instance.load();
      await tester.pumpWidget(const MaterialApp(home: RegulatoryRadarScreen()));
      await tester.pump();
    }

    testWidgets('filters split upcoming from past dates', (tester) async {
      await pumpRadar(tester);
      await tester.tap(find.byKey(const Key('radar-filter-upcoming')));
      await tester.pump();
      for (final id in ['milestone_903', 'milestone_904']) {
        expect(find.byKey(Key('milestone-$id')), findsOneWidget);
      }
      for (final id in ['milestone_901', 'milestone_902', 'milestone_905']) {
        expect(find.byKey(Key('milestone-$id')), findsNothing);
      }

      await tester.tap(find.byKey(const Key('radar-filter-past')));
      await tester.pump();
      // A date that is today counts as taking effect, so it is past.
      for (final id in ['milestone_901', 'milestone_902', 'milestone_905']) {
        expect(find.byKey(Key('milestone-$id')), findsOneWidget);
      }
      expect(find.text('today'), findsOneWidget);
      expect(find.text('1 day ago'), findsOneWidget);
      expect(find.text('40 days ago'), findsOneWidget);

      // The app's "Following" filter needs reminders, which web does not have.
      expect(find.byKey(const Key('radar-filter-following')), findsNothing);
    });

    testWidgets('the days left are calendar days: tomorrow is "in 1 day"', (
      tester,
    ) async {
      await pumpRadar(tester);
      await tester.tap(find.byKey(const Key('radar-filter-upcoming')));
      await tester.pump();
      expect(find.text('in 45 days'), findsOneWidget);
      expect(find.text('in 400 days'), findsOneWidget);
    });

    testWidgets('a milestone can be shared as an image card', (tester) async {
      await pumpRadar(tester);
      await tester.tap(find.byKey(const Key('milestone-milestone_903-share')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('share-card-face')), findsOneWidget);
      expect(find.textContaining('Test date milestone_903'), findsWidgets);
    });
  });

  testWidgets('weak spots lists low-scoring modules and offers to retry', (
    tester,
  ) async {
    await pumpScreen(tester, const Scaffold(body: WeakSpotsCard()));
    expect(find.byKey(const Key('weak-spots-card')), findsNothing);

    await ProgressStore.instance.completeLesson(
      moduleId: 'sfdr',
      correct: 5,
      total: 10,
    );
    await ProgressStore.instance.completeLesson(
      moduleId: 'csddd',
      correct: 10,
      total: 10,
    );
    // The card reads the store when it is built, so build a fresh one.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WeakSpotsCard(key: UniqueKey())),
      ),
    );
    expect(find.text('Worth another go'), findsOneWidget);
    expect(find.text('50% right'), findsOneWidget);
    expect(find.byKey(const Key('weak-spot-practise-sfdr')), findsOneWidget);
    expect(find.byKey(const Key('weak-spot-practise-csddd')), findsNothing);
  });
}
