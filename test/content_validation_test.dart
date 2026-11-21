import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sustainwise/data/models.dart';
import 'package:sustainwise/widgets/term_insight.dart';

// MockData.load() already throws on load if a module id referenced by a
// unit doesn't exist, or if a field has the wrong JSON type, or if a
// regulatory-milestone date doesn't parse — so a passing load() here is
// itself the first, broadest check. The rest of this file catches the
// content-authoring mistakes that *wouldn't* throw there: an empty deck a
// screen would then index into, an out-of-range correctIndex, or a
// malformed URL — see the flutter_local_notifications-unrelated but
// similarly "authored by hand" esg_content.json (~1800 lines).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => MockData.load());

  test('every module in the curriculum has at least one flashcard', () {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        expect(
          MockData.lessonFor(module.id),
          isNotEmpty,
          reason:
              'Module "${module.id}" (${module.title}) has no terms — '
              'LessonScreen would crash indexing into an empty deck.',
        );
      }
    }
  });

  test('every module\'s declared termCount matches its actual term list', () {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        expect(
          MockData.lessonFor(module.id).length,
          module.termCount,
          reason:
              'Module "${module.id}" declares termCount=${module.termCount} '
              'but has ${MockData.lessonFor(module.id).length} actual terms.',
        );
      }
    }
  });

  test('every generated quiz question has a valid correctIndex', () {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        for (final q in MockData.quizFor(module.id)) {
          expect(
            q.correctIndex,
            inInclusiveRange(0, q.options.length - 1),
            reason:
                'Quiz question "${q.question}" has an out-of-range '
                'correctIndex (${q.correctIndex} of ${q.options.length} options).',
          );
        }
      }
    }
  });

  test('every confusable pair has a valid correctIndex (0 or 1)', () {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        for (final pair in MockData.pairsFor(module.id)) {
          expect(
            pair.correctIndex,
            anyOf(0, 1),
            reason:
                'Confusable pair "${pair.statement}" has correctIndex='
                '${pair.correctIndex}, expected 0 or 1.',
          );
        }
      }
    }
  });

  test('every expert-challenge question has a valid correctIndex', () {
    for (final q in MockData.expertChallenge) {
      expect(
        q.correctIndex,
        inInclusiveRange(0, q.options.length - 1),
        reason:
            'Expert-challenge question "${q.question}" has an '
            'out-of-range correctIndex.',
      );
    }
  });

  test('learner-facing text never refers to the app\'s own editing history', () {
    // Editorial notes ("needed correcting", "the earlier hedge") belong in
    // commit messages, not in learning content. A plain "in this app" scope
    // statement is fine.
    const banned = [
      "app's earlier",
      "needed correcting",
      "the earlier hedge",
      "app's regulatory history",
    ];
    final texts = <String>[];
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        for (final t in MockData.lessonFor(module.id)) {
          texts.addAll([
            t.definition,
            ?t.plainEnglish,
            ?t.whyItMatters,
            ?t.example,
            ?t.dontConfuseWith,
          ]);
        }
        for (final q in MockData.quizFor(module.id)) {
          texts.addAll([q.question, q.explanation, ...q.options]);
        }
        for (final pair in MockData.pairsFor(module.id)) {
          texts.addAll([pair.statement, pair.explanation]);
        }
      }
    }
    for (final q in MockData.expertChallenge) {
      texts.addAll([q.question, q.explanation, ...q.options]);
    }
    for (final milestone in MockData.regulatoryMilestones) {
      texts.addAll([milestone.title, milestone.description]);
    }
    for (final text in texts) {
      for (final phrase in banned) {
        expect(
          text.toLowerCase().contains(phrase),
          isFalse,
          reason:
              'Learner-facing text refers to the app itself ("$phrase"): $text',
        );
      }
    }
  });

  test('the correct answer is not systematically the longest option', () {
    // Quiz answers that are clearly longer than the rest let a learner pass
    // by picking the longest option. With 4 options, chance is ~25%; this
    // guard fails well above that, so authors keep distractors comparable.
    int words(String s) => RegExp(r'\S+').allMatches(s).length;
    bool strictlyLongest(List<String> options, int correct) {
      final c = words(options[correct]);
      for (var i = 0; i < options.length; i++) {
        if (i != correct && words(options[i]) >= c) return false;
      }
      return true;
    }

    final scenarios = <QuizQuestion>[
      for (final unit in MockData.units)
        for (final module in unit.modules)
          ...MockData.quizFor(module.id).where((q) => q.termId == null),
    ];
    final scenarioHits = scenarios
        .where((q) => strictlyLongest(q.options, q.correctIndex))
        .length;
    final expertHits = MockData.expertChallenge
        .where((q) => strictlyLongest(q.options, q.correctIndex))
        .length;

    expect(scenarios, isNotEmpty);
    expect(
      scenarioHits / scenarios.length,
      lessThanOrEqualTo(0.5),
      reason:
          '$scenarioHits of ${scenarios.length} scenario questions have the '
          'longest option as the correct answer.',
    );
    expect(
      expertHits / MockData.expertChallenge.length,
      lessThanOrEqualTo(0.5),
      reason:
          '$expertHits of ${MockData.expertChallenge.length} expert questions '
          'have the longest option as the correct answer.',
    );
  });

  test('every regulatory sourceUrl is a well-formed http(s) URL', () {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        final url = module.regulatory?.sourceUrl;
        if (url == null) continue;
        final uri = Uri.tryParse(url);
        expect(
          uri != null &&
              (uri.scheme == 'http' || uri.scheme == 'https') &&
              uri.host.isNotEmpty,
          isTrue,
          reason:
              'Module "${module.id}" has a malformed regulatory sourceUrl: "$url".',
        );
      }
    }
    for (final milestone in MockData.regulatoryMilestones) {
      final url = milestone.sourceUrl;
      if (url == null) continue;
      final uri = Uri.tryParse(url);
      expect(
        uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty,
        isTrue,
        reason:
            'Milestone "${milestone.id}" has a malformed sourceUrl: "$url".',
      );
    }
  });

  test(
    'every regulatory milestone points at a module that actually exists',
    () {
      for (final milestone in MockData.regulatoryMilestones) {
        expect(
          MockData.moduleById(milestone.moduleId),
          isNotNull,
          reason:
              'Milestone "${milestone.id}" references unknown module '
              '"${milestone.moduleId}".',
        );
      }
    },
  );

  test('a milestone day count uses calendar days, not 24-hour periods', () {
    RegulatoryMilestone on(DateTime d) => RegulatoryMilestone(
      id: 'x',
      date: d,
      title: 't',
      description: 'd',
      moduleId: 'm',
      type: MilestoneType.applicable,
    );
    final afternoon = DateTime(2026, 11, 14, 15, 30);
    // Tomorrow's midnight is only 8.5 hours away, but it is still "in 1 day".
    expect(on(DateTime(2026, 11, 15)).calendarDaysFrom(afternoon), 1);
    expect(on(DateTime(2026, 11, 14)).calendarDaysFrom(afternoon), 0);
    expect(on(DateTime(2026, 11, 13)).calendarDaysFrom(afternoon), -1);
    expect(on(DateTime(2027, 1, 1)).calendarDaysFrom(afternoon), 48);
    // Across the end-of-March clock change the count must stay whole days.
    expect(
      on(DateTime(2027, 3, 29)).calendarDaysFrom(DateTime(2027, 3, 27, 23, 59)),
      2,
    );
  });

  group('quiz fairness and module 17 wording', () {
    const providerModule = 'esg-ratings-data-providers';

    test('no definition gives away its own term or acronym', () {
      // ESG and CO2 are everyday words in this app, not the answer.
      const allowedAcronyms = {'ESG', 'CO2'};
      final acronym = RegExp(r'\b[A-Z][A-Z0-9&]{2,}\b');
      for (final term in MockData.allTerms) {
        final name = term.term
            .replaceAll(RegExp(r'\s*\(.*\)'), '')
            .trim()
            .toLowerCase();
        if (name.length >= 4) {
          expect(
            RegExp(
              r'\b' + RegExp.escape(name) + r'\b',
            ).hasMatch(term.definition.toLowerCase()),
            isFalse,
            reason: '"${term.term}" is named in its own definition.',
          );
        }
        for (final a in acronym.allMatches(term.term)) {
          final value = a.group(0)!;
          if (allowedAcronyms.contains(value)) continue;
          expect(
            RegExp(
              r'\b' + RegExp.escape(value) + r'\b',
            ).hasMatch(term.definition),
            isFalse,
            reason: '"${term.term}" repeats $value in its own definition.',
          );
        }
      }
    });

    test(
      'module 17 has no "do not confuse with" text and states a country',
      () {
        const countryWords = [
          'US', 'UK', 'British', 'German', 'Germany', 'French', 'France', //
          'Dutch', 'Netherlands', 'Swiss', 'Switzerland', //
        ];
        final terms = MockData.lessonFor(providerModule);
        expect(terms, isNotEmpty);
        for (final t in terms) {
          expect(t.dontConfuseWith, isNull, reason: t.term);
          expect(t.group, anyOf('concept', 'provider'), reason: t.term);
          if (t.group == 'provider') {
            expect(
              countryWords.any(
                (c) => RegExp(r'\b' + c + r'\b').hasMatch(t.definition),
              ),
              isTrue,
              reason: '"${t.term}" does not say where the provider is from.',
            );
          }
        }
      },
    );

    test('every term question has four distinct options and one right one', () {
      for (final unit in MockData.units) {
        for (final module in unit.modules) {
          for (final term in MockData.lessonFor(module.id)) {
            expect(term.definition.trim(), isNotEmpty, reason: term.term);
            // The review route must be able to ask about every single term.
            // The same questions are then checked, so identity and options
            // come from one and the same call.
            final review = MockData.reviewQuizFor({MockData.keyOf(term)});
            expect(review.map((q) => q.termId), [
              MockData.keyOf(term),
            ], reason: '${module.id}: ${term.term}');
            for (final q in [
              for (final q in MockData.quizFor(module.id))
                if (q.termId == MockData.keyOf(term)) q,
              ...review,
            ]) {
              final reason = '${module.id}: ${q.question}';
              expect(q.options, hasLength(4), reason: reason);
              expect(
                {for (final o in q.options) o.trim().toLowerCase()},
                hasLength(4),
                reason: reason,
              );
              expect(
                q.options[q.correctIndex],
                term.definition,
                reason: reason,
              );
            }
          }
        }
      }
    });

    test('module 17 questions never mix providers and general concepts', () {
      final terms = MockData.lessonFor(providerModule);
      final byDefinition = {for (final t in terms) t.definition: t};
      for (final term in terms) {
        expect(term.group, isNotNull, reason: term.term);
        // One review call per term: it must give exactly one question, and
        // that same question is checked together with the lesson questions.
        final review = MockData.reviewQuizFor({MockData.keyOf(term)});
        expect(review, hasLength(1), reason: term.term);
        for (final q in [
          for (final q in MockData.quizFor(providerModule))
            if (q.termId == MockData.keyOf(term)) q,
          ...review,
        ]) {
          final kinds = {
            for (final o in q.options) byDefinition[o]?.group ?? 'unknown',
          };
          expect(kinds, {term.group}, reason: q.question);
        }
      }
    });

    test('the review route gives nothing for an unknown or empty request', () {
      expect(MockData.reviewQuizFor({'no-such-term'}), isEmpty);
      expect(MockData.reviewQuizFor(<String>{}), isEmpty);
    });

    test('an invalid question uses no random numbers at all', () {
      Term make(String n, String definition) => Term(
        moduleLabel: 'm',
        moduleId: 'm',
        term: n,
        id: n,
        definition: definition,
      );
      List<double> next8(Random r) => List.generate(8, (_) => r.nextDouble());

      // 1. A blank right answer.
      final bigPool = [
        make('a', 'Alpha one two three four five.'),
        for (final n in ['b', 'c', 'd', 'e'])
          make(n, '${n.toUpperCase()} one two three four.'),
      ];
      final used = Random(7);
      expect(MockData.questionForTest(make('z', ' '), bigPool, used), isNull);
      expect(next8(used), next8(Random(7)));

      // 2. Too few different wrong answers.
      final smallPool = [
        make('a', 'Alpha one two three four five.'),
        make('b', 'Bravo one two three four.'),
        make('c', 'Charlie one two three four.'),
      ];
      final used2 = Random(7);
      expect(
        MockData.questionForTest(smallPool.first, smallPool, used2),
        isNull,
      );
      expect(next8(used2), next8(Random(7)));

      // 3. A valid question does use them, so the check above can fail.
      final used3 = Random(7);
      expect(
        MockData.questionForTest(bigPool.first, bigPool, used3),
        isNotNull,
      );
      expect(next8(used3), isNot(next8(Random(7))));
    });

    group('question generator on small or awkward pools', () {
      Term t(String name, String definition, {String? group}) => Term(
        moduleLabel: 'm',
        moduleId: 'm',
        term: name,
        id: name,
        definition: definition,
        group: group,
      );

      QuizQuestion? ask(Term term, List<Term> pool) =>
          MockData.questionForTest(term, pool, Random(1));

      test('two candidates of the same kind are always used', () {
        final target = t('a', 'Alpha one two three four five.', group: 'g1');
        final pool = [
          target,
          t('b', 'Bravo alpha one two three four.', group: 'g1'),
          t('c', 'Charlie alpha one two three.', group: 'g1'),
          // Other kinds that look much more like the target.
          t('d', 'Alpha one two three four five six.', group: 'g2'),
          t('e', 'Alpha one two three four five seven.', group: 'g2'),
          t('f', 'Alpha one two three four five eight.', group: 'g2'),
        ];
        for (var seed = 0; seed < 20; seed++) {
          final q = MockData.questionForTest(target, pool, Random(seed))!;
          expect(q.options, contains(pool[1].definition), reason: '$seed');
          expect(q.options, contains(pool[2].definition), reason: '$seed');
          expect(q.options, hasLength(4));
        }
      });

      test(
        'a copy of the same kind survives an identical wording elsewhere',
        () {
          final target = t('a', 'Alpha one two three four five.', group: 'g1');
          final pool = [
            t('x', 'SHARED wording for two terms.', group: 'g2'),
            target,
            t('y', 'shared wording for two terms.', group: 'g1'),
            t('b', 'Bravo one two three four.', group: 'g1'),
            t('c', 'Charlie one two three four.', group: 'g1'),
          ];
          final q = ask(target, pool)!;
          // The identical wording appears once, and it is the copy of the same
          // kind as the term (the other kind's copy is the one left out).
          expect(
            q.options.where(
              (o) => o.toLowerCase() == 'shared wording for two terms.',
            ),
            ['shared wording for two terms.'],
          );
          expect(q.options, hasLength(4));
        },
      );

      test('a blank definition never becomes an option or a question', () {
        final target = t('a', 'Alpha one two three four five.');
        final pool = [
          target,
          t('b', '   '),
          t('c', 'Charlie one two three four.'),
          t('d', 'Delta one two three four.'),
          t('e', 'Echo one two three four.'),
        ];
        final q = ask(target, pool)!;
        expect(q.options.every((o) => o.trim().isNotEmpty), isTrue);
        expect(ask(t('z', '  '), pool), isNull);
      });

      test('fewer than three different wrong answers gives no question', () {
        final target = t('a', 'Alpha one two three four five.');
        final pool = [
          target,
          t('b', 'Alpha one two three four five.'), // same as the right answer
          t('c', 'Charlie one two three four.'),
          t('d', 'Charlie one two three four.'), // same as another candidate
          t('e', 'Echo one two three four.'),
        ];
        expect(ask(target, pool), isNull);
      });
    });

    test('a blank why-it-matters text does not hide the explanation', () {
      const blank = Term(
        moduleLabel: 'm',
        moduleId: 'm',
        term: 'x',
        definition: 'd',
        whyItMatters: '   ',
        example: '',
      );
      expect(TermInsight.sectionCountForTest(blank), 0);
    });

    test('wrong answers resemble the right one in every module', () {
      // A cheap proxy for "not obviously wrong": the wrong answers are never
      // all far shorter or longer than the correct one.
      for (final unit in MockData.units) {
        for (final module in unit.modules) {
          for (final q in MockData.quizFor(module.id)) {
            if (q.termId == null) continue;
            final correct = q.options[q.correctIndex].length;
            for (var i = 0; i < q.options.length; i++) {
              if (i == q.correctIndex) continue;
              final ratio = q.options[i].length / correct;
              expect(
                ratio,
                inInclusiveRange(0.3, 3.5),
                reason: '${module.id}: ${q.question}',
              );
            }
          }
        }
      }
    });
  });
}
