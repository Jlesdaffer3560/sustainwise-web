import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../theme/app_theme.dart';

enum ModuleStatus { done, current, available }

class ModuleProgress {
  const ModuleProgress({
    required this.id,
    required this.title,
    required this.status,
    required this.summary,
    required this.termCount,
  });

  // A stable identifier for widget keys/tests, decoupled from the display
  // title so renaming a module's copy doesn't break anything keyed on it.
  final String id;
  final String title;
  final ModuleStatus status;
  final String summary;
  final int termCount;

  // `status` here is only ever the compiled-in default for a fresh install —
  // screens resolve the real, persisted status through ProgressStore and
  // layer it on with this.
  ModuleProgress copyWith({ModuleStatus? status}) => ModuleProgress(
        id: id,
        title: title,
        status: status ?? this.status,
        summary: summary,
        termCount: termCount,
      );
}

/// A themed group of modules rendered as one colored band on Home — this is
/// what keeps the path from reading as empty space with a few circles on
/// it: each unit owns a full-width tinted section, the way Duolingo's own
/// path uses colored unit banners rather than a plain background.
class LearningUnit {
  const LearningUnit({
    required this.title,
    required this.description,
    required this.tint,
    required this.icon,
    required this.modules,
  });

  final String title;
  final String description;
  final Color tint;
  final IconData icon;
  final List<ModuleProgress> modules;

  int get totalTerms => modules.fold(0, (sum, m) => sum + m.termCount);
}

class Term {
  const Term({
    required this.moduleLabel,
    required this.term,
    required this.definition,
  });

  final String moduleLabel;
  final String term;
  final String definition;
}

class QuizQuestion {
  const QuizQuestion({
    required this.moduleLabel,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String moduleLabel;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

/// "Which is which?" hard-mode round — a clue statement describing one of
/// two easily-confused terms/acronyms. Ported from the mockup's `#view-match`.
class ConfusablePair {
  const ConfusablePair({
    required this.moduleLabel,
    required this.statement,
    required this.optionA,
    required this.optionB,
    required this.correctIndex,
    required this.explanation,
  });

  final String moduleLabel;
  final String statement;
  final String optionA;
  final String optionB;
  final int correctIndex; // 0 = optionA, 1 = optionB
  final String explanation;
}

const _iconByKey = <String, IconData>{
  'eco_outlined': Icons.eco_outlined,
  'gavel_outlined': Icons.gavel_outlined,
  'account_balance_outlined': Icons.account_balance_outlined,
  'description_outlined': Icons.description_outlined,
  'insights_outlined': Icons.insights_outlined,
  'diversity_3_outlined': Icons.diversity_3_outlined,
  'policy_outlined': Icons.policy_outlined,
  'history_edu_outlined': Icons.history_edu_outlined,
};

/// The real term database (256 terms / 16 modules / 30 confusable pairs),
/// bundled as a JSON asset and loaded once at startup. [ProgressStore]
/// layers the learner's actual progress on top of the static content held
/// here.
class MockData {
  MockData._();

  // Seed values for a fresh install — ProgressStore takes over from here
  // and persists everything as the learner actually practices.
  static const defaultStreakDays = 12;
  static const defaultLongestStreak = 18;
  static const defaultTotalXp = 1240;

  // Not yet tracked per-answer across sessions — a representative constant
  // until quiz/pair results are aggregated over time.
  static const overallAccuracy = 87.0;

  static bool _loaded = false;
  static List<LearningUnit> units = [];
  static final Map<String, List<Term>> _termsByModule = {};
  static final Map<String, List<ConfusablePair>> _pairsByModule = {};
  static final Map<String, String> _moduleLabelById = {};

  /// Loads and parses the bundled content asset. Safe to call more than
  /// once — later calls are a no-op.
  static Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/esg_content.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final modulesJson = data['modules'] as List;
    final moduleById = <String, ModuleProgress>{};
    for (var i = 0; i < modulesJson.length; i++) {
      final m = modulesJson[i] as Map<String, dynamic>;
      final id = m['id'] as String;
      moduleById[id] = ModuleProgress(
        id: id,
        title: m['title'] as String,
        summary: m['summary'] as String,
        termCount: m['termCount'] as int,
        status: ModuleStatus.values.byName(m['defaultStatus'] as String),
      );
      _moduleLabelById[id] = 'Module ${(i + 1).toString().padLeft(2, '0')} · ${m['title']}';
    }

    final unitsJson = data['units'] as List;
    units = [
      for (final u in unitsJson)
        LearningUnit(
          title: u['title'] as String,
          description: u['description'] as String,
          tint: (u['tint'] as String) == 'amberSoft' ? AppColors.amberSoft : AppColors.accentSoft,
          icon: _iconByKey[u['icon'] as String] ?? Icons.circle_outlined,
          modules: [for (final mid in (u['moduleIds'] as List)) moduleById[mid as String]!],
        ),
    ];

    final termsJson = data['terms'] as Map<String, dynamic>;
    termsJson.forEach((moduleId, list) {
      final label = _moduleLabelById[moduleId] ?? moduleId;
      _termsByModule[moduleId] = [
        for (final t in list as List)
          Term(moduleLabel: label, term: t['term'] as String, definition: t['definition'] as String),
      ];
    });

    final pairsJson = data['pairs'] as List;
    for (final p in pairsJson) {
      final moduleId = p['moduleId'] as String;
      final label = _moduleLabelById[moduleId] ?? moduleId;
      _pairsByModule.putIfAbsent(moduleId, () => []).add(ConfusablePair(
            moduleLabel: label,
            statement: p['statement'] as String,
            optionA: p['optionA'] as String,
            optionB: p['optionB'] as String,
            correctIndex: p['correctIndex'] as int,
            explanation: p['explanation'] as String,
          ));
    }

    _loaded = true;
  }

  /// The full flashcard deck for a module — every real term it has.
  static List<Term> lessonFor(String moduleId) => _termsByModule[moduleId] ?? const [];

  /// Confusable pairs assigned to this module, if any (not every module has
  /// a hard-mode round yet).
  static List<ConfusablePair> pairsFor(String moduleId) => _pairsByModule[moduleId] ?? const [];

  /// Mechanically generates a short multiple-choice quiz from a module's
  /// real terms: "which definition matches X", with 3 real distractor
  /// definitions from other terms in the same module. No content is
  /// invented — every option is a real definition from the database.
  static List<QuizQuestion> quizFor(String moduleId) {
    final terms = _termsByModule[moduleId] ?? const [];
    if (terms.length < 4) return const [];

    const quizSize = 5;
    final sampleCount = min(quizSize, terms.length);
    final sampled = [
      for (var i = 0; i < sampleCount; i++) terms[(i * terms.length) ~/ sampleCount],
    ];

    // A hand-rolled stable hash, not String.hashCode — Dart doesn't
    // guarantee hashCode is the same across runs/platforms, and this seed
    // needs to be, so the same module always quizzes the same way.
    final random = Random(_stableHash(moduleId));
    return [
      for (final term in sampled) _questionFor(term, terms, random),
    ];
  }

  // Jenkins one-at-a-time hash — deterministic across runs/platforms,
  // unlike Dart's own String.hashCode.
  static int _stableHash(String s) {
    var hash = 0;
    for (final unit in s.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  static QuizQuestion _questionFor(Term term, List<Term> pool, Random random) {
    final distractorPool = pool.where((t) => t.term != term.term).toList()..shuffle(random);
    final options = [term.definition, ...distractorPool.take(3).map((t) => t.definition)]..shuffle(random);
    return QuizQuestion(
      moduleLabel: term.moduleLabel,
      question: "Which definition matches '${term.term}'?",
      options: options,
      correctIndex: options.indexOf(term.definition),
      explanation: "'${term.term}': ${term.definition}",
    );
  }
}
