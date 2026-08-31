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
            reason: 'Quiz question "${q.question}" has an out-of-range '
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
        reason: 'Expert-challenge question "${q.question}" has an '
            'out-of-range correctIndex.',
      );
    }
  });

  test('every regulatory sourceUrl is a well-formed http(s) URL', () {
    for (final unit in MockData.units) {
      for (final module in unit.modules) {
        final url = module.regulatory?.sourceUrl;
        if (url == null) continue;
        final uri = Uri.tryParse(url);
        expect(
          uri != null && uri.hasScheme && uri.scheme.startsWith('http'),
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
        uri != null && uri.hasScheme && uri.scheme.startsWith('http'),
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
}
