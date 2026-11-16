import 'package:flutter_test/flutter_test.dart';
import 'package:sustainwise/data/models.dart';

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
}
