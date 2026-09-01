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
    this.regulatory,
  });

  // A stable identifier for widget keys/tests, decoupled from the display
  // title so renaming a module's copy doesn't break anything keyed on it.
  final String id;
  final String title;
  final ModuleStatus status;
  final String summary;
  final int termCount;

  // Only set for modules covering a specific piece of regulation (CSRD,
  // CSDDD, SFDR, ...) — ESG rules move fast enough that content needs a
  // visible "as of" date and source rather than being stated as timeless
  // fact. Null for non-regulatory modules (e.g. ESG Fundamentals).
  final RegulatoryMeta? regulatory;

  // `status` here is only ever the compiled-in default for a fresh install —
  // screens resolve the real, persisted status through ProgressStore and
  // layer it on with this.
  ModuleProgress copyWith({ModuleStatus? status}) => ModuleProgress(
    id: id,
    title: title,
    status: status ?? this.status,
    summary: summary,
    termCount: termCount,
    regulatory: regulatory,
  );
}

/// "As of" metadata for a regulation-specific module — ESG rules are
/// currently moving fast enough (see the 2026 CSRD/CSDDD Omnibus
/// simplification) that stating regulatory content as timeless fact is
/// misleading. Every field is nullable since content is migrated to this
/// gradually rather than all at once.
class RegulatoryMeta {
  const RegulatoryMeta({
    this.status,
    this.lastReviewed,
    this.effectiveDate,
    this.sourceUrl,
    this.jurisdiction,
    this.version,
  });

  // e.g. "In force", "In force — recently amended", "Proposed"
  final String? status;
  // e.g. "July 2026" — when this app's content was last checked against the rule
  final String? lastReviewed;
  // e.g. "Applies from Sep 2026" — when the rule itself takes effect
  final String? effectiveDate;
  final String? sourceUrl;
  // e.g. "EU"
  final String? jurisdiction;
  // e.g. "Post-Omnibus (2026)" — which revision of the rule this describes
  final String? version;

  bool get hasContent =>
      status != null ||
      lastReviewed != null ||
      effectiveDate != null ||
      jurisdiction != null ||
      version != null;
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

/// Which of the five ESG "families" a term belongs to — drives icon/badge
/// tinting so a learner can tell at a glance whether they're looking at an
/// environmental, social, governance, regulatory, or finance concept,
/// independent of which learning unit happens to contain it.
enum ContentTheme {
  environmental,
  social,
  governance,
  regulation,
  finance;

  Color get color => switch (this) {
    ContentTheme.environmental => AppColors.tealDeep,
    ContentTheme.social => AppColors.coralDeep,
    ContentTheme.governance => AppColors.navy,
    ContentTheme.regulation => AppColors.violetDeep,
    ContentTheme.finance => AppColors.amberDeep,
  };

  String get label => switch (this) {
    ContentTheme.environmental => 'Environmental',
    ContentTheme.social => 'Social',
    ContentTheme.governance => 'Governance',
    ContentTheme.regulation => 'Regulation',
    ContentTheme.finance => 'Finance',
  };
}

class Term {
  const Term({
    required this.moduleLabel,
    required this.moduleId,
    required this.term,
    required this.definition,
    this.id,
    this.plainEnglish,
    this.whyItMatters,
    this.example,
    this.dontConfuseWith,
    this.theme,
  });

  final String moduleLabel;
  // The module this term actually belongs to — needed to pull a coherent
  // distractor pool when regenerating a quiz question for just this one
  // term (the Mistakes review flow), since [moduleLabel] is a display
  // string, not a lookup key.
  final String moduleId;
  final String term;
  final String definition;

  // A stable identifier (e.g. "double_materiality_001") for progress
  // tracking (spaced repetition, mastery) that survives the term's display
  // name or definition being edited. Null for terms not yet migrated.
  final String? id;

  // The richer "Plain English / Why it matters / Example / Don't confuse
  // with" explanation format. All null for a term still on the older
  // definition-only format — [LessonScreen] falls back to [definition]
  // alone in that case, so migration can happen module by module.
  final String? plainEnglish;
  final String? whyItMatters;
  final String? example;
  final String? dontConfuseWith;

  final ContentTheme? theme;

  bool get hasRichFormat => plainEnglish != null;
}

class QuizQuestion {
  const QuizQuestion({
    required this.moduleLabel,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.termId,
  });

  final String moduleLabel;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  // Set only for the mechanically-generated "which definition matches X"
  // questions — the id of the [Term] this question tests. Null for
  // scenario/expert-challenge questions, which aren't about one specific
  // term. Drives the Mistakes-to-revisit tracker: a wrong answer here can
  // be traced back to a real term to add to the review queue; a scenario
  // miss can't, since there's no single term to point at.
  final String? termId;
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

/// A dated regulatory event (a rule entering into force, an application
/// deadline, ...) — the "Regulatory Radar" feature's unit of content. Unlike
/// the rest of the app's static term/quiz content, these are read against
/// [DateTime.now()] at render time so the same bundled data reads as
/// "upcoming" or "just passed" depending on when the app is opened, rather
/// than needing a content update or a push-notification backend.
/// What kind of date a milestone marks — a passed date means something
/// legally different depending on which: only [inForce] actually means a
/// rule is in force. An application date or a transposition deadline
/// passing doesn't, even though all three read as "done" to a learner
/// glancing at a calendar.
enum MilestoneType { inForce, applicable, deadline }

class RegulatoryMilestone {
  const RegulatoryMilestone({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.moduleId,
    required this.type,
    this.sourceUrl,
  });

  final String id;
  final DateTime date;
  final String title;
  final String description;
  final String moduleId;
  final MilestoneType type;
  final String? sourceUrl;

  bool get isPast => date.isBefore(DateTime.now());

  // The status badge label a learner actually needs — legally correct per
  // [type] rather than a blanket "IN FORCE" for any date in the past.
  String get statusLabel {
    if (!isPast) return 'UPCOMING';
    return switch (type) {
      MilestoneType.inForce => 'IN FORCE',
      MilestoneType.applicable => 'APPLICABLE',
      MilestoneType.deadline => 'DEADLINE PASSED',
    };
  }
}

/// A locally-computed milestone badge — derived entirely from the learner's
/// own [ProgressStore] state, never from other users, since this app has no
/// accounts or backend to compare against.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
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
  'public_outlined': Icons.public_outlined,
  'campaign_outlined': Icons.campaign_outlined,
};

/// The real term database (261 terms / 16 modules / 30 confusable pairs),
/// bundled as a JSON asset and loaded once at startup. [ProgressStore]
/// layers the learner's actual progress on top of the static content held
/// here.
class MockData {
  MockData._();

  static bool _loaded = false;
  static List<LearningUnit> units = [];
  static List<QuizQuestion> expertChallenge = [];
  static List<RegulatoryMilestone> regulatoryMilestones = [];
  static final Map<String, List<Term>> _termsByModule = {};
  static final Map<String, List<ConfusablePair>> _pairsByModule = {};
  static final Map<String, List<QuizQuestion>> _scenariosByModule = {};
  static final Map<String, String> _moduleLabelById = {};
  static final Map<String, ModuleProgress> _moduleById = {};

  /// Loads and parses the bundled content asset. Safe to call more than
  /// once — later calls are a no-op.
  static Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/esg_content.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final modulesJson = data['modules'] as List;
    final modulesById = <String, ModuleProgress>{};
    for (var i = 0; i < modulesJson.length; i++) {
      final m = modulesJson[i] as Map<String, dynamic>;
      final id = m['id'] as String;
      final regJson = m['regulatory'] as Map<String, dynamic>?;
      modulesById[id] = ModuleProgress(
        id: id,
        title: m['title'] as String,
        summary: m['summary'] as String,
        termCount: m['termCount'] as int,
        status: ModuleStatus.values.byName(m['defaultStatus'] as String),
        regulatory: regJson == null
            ? null
            : RegulatoryMeta(
                status: regJson['status'] as String?,
                lastReviewed: regJson['lastReviewed'] as String?,
                effectiveDate: regJson['effectiveDate'] as String?,
                sourceUrl: regJson['sourceUrl'] as String?,
                jurisdiction: regJson['jurisdiction'] as String?,
                version: regJson['version'] as String?,
              ),
      );
      _moduleLabelById[id] =
          'Module ${(i + 1).toString().padLeft(2, '0')} · ${m['title']}';
      _moduleById[id] = modulesById[id]!;
    }

    final unitsJson = data['units'] as List;
    units = [
      for (final u in unitsJson)
        LearningUnit(
          title: u['title'] as String,
          description: u['description'] as String,
          tint: (u['tint'] as String) == 'amberSoft'
              ? AppColors.amberSoft
              : AppColors.accentSoft,
          icon: _iconByKey[u['icon'] as String] ?? Icons.circle_outlined,
          modules: [
            for (final mid in (u['moduleIds'] as List))
              modulesById[mid as String]!,
          ],
        ),
    ];

    final termsJson = data['terms'] as Map<String, dynamic>;
    termsJson.forEach((moduleId, list) {
      final label = _moduleLabelById[moduleId] ?? moduleId;
      _termsByModule[moduleId] = [
        for (final t in list as List)
          Term(
            moduleLabel: label,
            moduleId: moduleId,
            term: t['term'] as String,
            definition: t['definition'] as String,
            id: t['id'] as String?,
            plainEnglish: t['plainEnglish'] as String?,
            whyItMatters: t['whyItMatters'] as String?,
            example: t['example'] as String?,
            dontConfuseWith: t['dontConfuseWith'] as String?,
            theme: t['theme'] == null
                ? null
                : ContentTheme.values.byName(t['theme'] as String),
          ),
      ];
    });

    final pairsJson = data['pairs'] as List;
    for (final p in pairsJson) {
      final moduleId = p['moduleId'] as String;
      final label = _moduleLabelById[moduleId] ?? moduleId;
      _pairsByModule
          .putIfAbsent(moduleId, () => [])
          .add(
            ConfusablePair(
              moduleLabel: label,
              statement: p['statement'] as String,
              optionA: p['optionA'] as String,
              optionB: p['optionB'] as String,
              correctIndex: p['correctIndex'] as int,
              explanation: p['explanation'] as String,
            ),
          );
    }

    final scenariosJson =
        data['scenarios'] as Map<String, dynamic>? ?? const {};
    scenariosJson.forEach((moduleId, list) {
      final label = _moduleLabelById[moduleId] ?? moduleId;
      _scenariosByModule[moduleId] = [
        for (final q in list as List)
          QuizQuestion(
            moduleLabel: label,
            question: q['question'] as String,
            options: [for (final o in q['options'] as List) o as String],
            correctIndex: q['correctIndex'] as int,
            explanation: q['explanation'] as String,
          ),
      ];
    });

    final expertJson = data['expertChallenge'] as List? ?? const [];
    expertChallenge = [
      for (final q in expertJson)
        QuizQuestion(
          moduleLabel: 'EXPERT · ${q['moduleLabel']}',
          question: q['question'] as String,
          options: [for (final o in q['options'] as List) o as String],
          correctIndex: q['correctIndex'] as int,
          explanation: q['explanation'] as String,
        ),
    ];

    final milestonesJson = data['regulatoryMilestones'] as List? ?? const [];
    regulatoryMilestones = [
      for (final r in milestonesJson)
        RegulatoryMilestone(
          id: r['id'] as String,
          date: DateTime.parse(r['date'] as String),
          title: r['title'] as String,
          description: r['description'] as String,
          moduleId: r['moduleId'] as String,
          type: MilestoneType.values.byName(r['type'] as String),
          sourceUrl: r['sourceUrl'] as String?,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    _loaded = true;
  }

  /// The module a milestone belongs to, for display (title, unit color) —
  /// null only if content data is inconsistent (a milestone referencing a
  /// module id that doesn't exist).
  static ModuleProgress? moduleById(String id) => _moduleById[id];

  /// Milestones within [windowDays] of today (past or future), nearest first
  /// — the cutoff that keeps the Regulatory Radar to "what's actually
  /// relevant right now" instead of listing every dated milestone the app
  /// has ever had, however far off.
  static List<RegulatoryMilestone> radarMilestones({int windowDays = 200}) {
    final now = DateTime.now();
    final inWindow =
        regulatoryMilestones
            .where((m) => m.date.difference(now).inDays.abs() <= windowDays)
            .toList()
          ..sort(
            (a, b) => a.date
                .difference(now)
                .abs()
                .compareTo(b.date.difference(now).abs()),
          );
    return inWindow;
  }

  /// The full flashcard deck for a module — every real term it has.
  static List<Term> lessonFor(String moduleId) =>
      _termsByModule[moduleId] ?? const [];

  // Matches a Timeline & Milestones-style entry ("1987 - Brundtland
  // Report", "2015 (Dec) - Paris Agreement") — a plain alphabetical sort
  // would otherwise stack every one of these ahead of the entire rest of
  // the alphabet, since digits sort before letters.
  static final RegExp _leadingYear = RegExp(r'^\d{4}\b');

  /// Every term across every module, sorted alphabetically — the source
  /// list for the Glossary tab, independent of module lock/unlock state so
  /// a learner can always look something up, whether or not they've
  /// reached that module in the path yet.
  ///
  /// Dated timeline entries are pulled out and appended at the end instead
  /// of being sorted in-place: sorting them alongside everything else would
  /// put all 24 of them first (digits sort before letters), so the
  /// alphabet would never actually start with an A-term. They keep their
  /// authored chronological order rather than being re-sorted by their
  /// "YYYY - " prefix.
  static List<Term> get allTerms {
    final dated = <Term>[];
    final undated = <Term>[];
    for (final t in _termsByModule.values.expand((list) => list)) {
      (_leadingYear.hasMatch(t.term) ? dated : undated).add(t);
    }
    undated.sort((a, b) => _sortKey(a.term).compareTo(_sortKey(b.term)));
    return [...undated, ...dated];
  }

  // Ignores a leading non-alphanumeric character (e.g. the opening quote in
  // "'Towards Sustainability' label") so it alphabetizes by its first real
  // letter instead of sorting ahead of the entire alphabet on punctuation
  // alone.
  static String _sortKey(String term) =>
      term.toLowerCase().replaceFirst(RegExp(r"^[^a-z0-9]+"), '');

  /// Confusable pairs assigned to this module, if any (not every module has
  /// a hard-mode round yet).
  static List<ConfusablePair> pairsFor(String moduleId) =>
      _pairsByModule[moduleId] ?? const [];

  /// Mechanically generates a short multiple-choice quiz from a module's
  /// real terms: "which definition matches X", with 3 real distractor
  /// definitions from other terms in the same module, then mixes in any
  /// hand-authored scenario/application questions for that module — real
  /// workplace situations ("your CFO says X, is that right?") rather than
  /// pure definition recall, so a lesson isn't 100% terminology.
  static List<QuizQuestion> quizFor(String moduleId) {
    final terms = _termsByModule[moduleId] ?? const [];
    if (terms.length < 4) return const [];

    const quizSize = 7;
    final sampleCount = min(quizSize, terms.length);
    final sampled = [
      for (var i = 0; i < sampleCount; i++)
        terms[(i * terms.length) ~/ sampleCount],
    ];

    // A hand-rolled stable hash, not String.hashCode — Dart doesn't
    // guarantee hashCode is the same across runs/platforms, and this seed
    // needs to be, so the same module always quizzes the same way.
    final random = Random(_stableHash(moduleId));
    final mechanical = [
      for (final term in sampled) _questionFor(term, terms, random),
    ];

    final scenarios = _scenariosByModule[moduleId] ?? const [];
    // No scenarios authored for this module yet — return exactly the old
    // mechanical-only, unshuffled order so existing behavior (and any
    // deterministic seed built against it) doesn't shift underneath it.
    if (scenarios.isEmpty) return mechanical;
    return [...mechanical, ...scenarios]..shuffle(random);
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

  // Matches definitions that open by naming a person rather than defining a
  // concept/document/risk — "A person who...", "Someone who...", or a named
  // attribution like "R. Edward Freeman's view that...". A definition like
  // this is instantly identifiable as the wrong answer for any *other* term
  // by grammatical shape alone ("a code of conduct" is never "a person"),
  // regardless of how well its definition's length happens to match.
  static final RegExp _personLikeDefinition = RegExp(
    r"^(A |An )?(person|individual|someone)\b"
    r"|^([A-Z][a-zA-Z.]*\s){1,3}[A-Z][a-zA-Z]+'s\s(view|theory|idea|concept)\b",
  );

  static QuizQuestion _questionFor(Term term, List<Term> pool, Random random) {
    // Distractors are drawn from definitions of similar length/shape to the
    // correct one, not purely at random — a one-line "X's view that..."
    // attribution next to a technical definition is trivially guessable by
    // shape alone, without knowing any actual content. Person-attributed
    // definitions are excluded from the candidate pool entirely (unless the
    // correct answer is itself person-attributed) for the same reason.
    final targetLength = term.definition.length;
    final targetIsPersonLike = _personLikeDefinition.hasMatch(term.definition);
    final candidates =
        pool
            .where((t) => t.term != term.term)
            .where(
              (t) =>
                  targetIsPersonLike ||
                  !_personLikeDefinition.hasMatch(t.definition),
            )
            .toList()
          ..shuffle(random);
    candidates.sort(
      (a, b) => (a.definition.length - targetLength).abs().compareTo(
        (b.definition.length - targetLength).abs(),
      ),
    );
    final distractors = candidates.take(3).toList()..shuffle(random);
    final options = [term.definition, ...distractors.map((t) => t.definition)]
      ..shuffle(random);
    return QuizQuestion(
      moduleLabel: term.moduleLabel,
      question: "Which definition matches '${term.term}'?",
      options: options,
      correctIndex: options.indexOf(term.definition),
      explanation: "'${term.term}': ${term.definition}",
      termId: term.id ?? term.term,
    );
  }

  /// Regenerates a fresh single-term question for each id in [termIds] —
  /// the Mistakes-to-revisit queue. Each term draws its distractors from its
  /// own module's pool (same logic as [quizFor]), so a review question is
  /// exactly as fair/hard as it would have been in the original lesson,
  /// not thrown together from unrelated topics.
  static List<QuizQuestion> reviewQuizFor(Set<String> termIds) {
    final random = Random();
    final questions = <QuizQuestion>[];
    for (final id in termIds) {
      Term? term;
      for (final t in allTerms) {
        if ((t.id ?? t.term) == id) {
          term = t;
          break;
        }
      }
      if (term == null) continue;
      final pool = _termsByModule[term.moduleId] ?? const [];
      if (pool.length < 4) continue;
      questions.add(_questionFor(term, pool, random));
    }
    questions.shuffle(random);
    return questions;
  }
}
