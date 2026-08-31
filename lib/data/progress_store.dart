import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// The single source of truth for everything that changes as the learner
/// actually uses the app — streak, XP, and per-module status — persisted
/// locally so progress survives an app restart instead of always showing
/// the same static numbers. [MockData] stays the source of the *static*
/// content (titles, term counts, order); this only tracks state.
class ProgressStore extends ChangeNotifier {
  ProgressStore._();
  static final ProgressStore instance = ProgressStore._();

  static const _xpPerLesson = 15;
  static const _xpExpertChallenge = 100;

  // Duolingo-style daily goal — enough for roughly two lessons, so it's a
  // real but reachable target rather than a rubber-stamp.
  static const dailyGoalXp = 30;
  static const _xpPerLevel = 250;

  static const _keyStreak = 'streak_days';
  static const _keyLongestStreak = 'longest_streak';
  static const _keyXp = 'total_xp';
  static const _keyLastPractice = 'last_practice_date';
  static const _keyStatuses = 'module_statuses';
  static const _keyAccuracy = 'module_accuracy';
  static const _keyReviewSchedule = 'review_schedule';
  static const _keyExpertDone = 'expert_challenge_done';
  static const _keyTodayXp = 'today_xp';
  static const _keyTodayXpDate = 'today_xp_date';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyDailyXpHistory = 'daily_xp_history';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyNotificationHour = 'notification_hour';
  static const _keyNotificationMinute = 'notification_minute';

  // Not a real module id — a sentinel key so the Expert Challenge's own
  // accuracy can share the existing per-module [_accuracy] map (and its
  // persistence) without colliding with any actual module.
  static const _expertChallengeAccuracyKey = 'expert_challenge';

  bool _loaded = false;
  bool get isLoaded => _loaded;

  int _streakDays = 0;
  int _longestStreak = 0;
  int _totalXp = 0;
  DateTime? _lastPracticeDate;
  final Map<String, ModuleStatus> _statuses = {};
  // Quiz + pairs accuracy (0.0-1.0) from the most recent completion of each
  // module — the raw data behind ESG Fluency and per-unit confidence.
  // Overwritten (not averaged) on repeat completions, since a learner's most
  // recent attempt is the more honest signal of where they stand today.
  final Map<String, double> _accuracy = {};
  // The "Mistakes to revisit" spaced-repetition schedule — a Leitner-style
  // 1/3/7-day cycle, not an instant retest. A wrong answer resets a term to
  // stage 0 (due tomorrow); each correct review advances it to the next,
  // longer interval; a correct review at the last stage removes it for
  // good (mastered). Only entries whose due date has arrived actually
  // surface as "to revisit" — see [missedTermIds].
  final Map<String, _ReviewEntry> _reviewSchedule = {};
  static const _reviewIntervalDays = [1, 3, 7];
  bool _expertChallengeCompleted = false;
  int _todayXpRaw = 0;
  DateTime? _todayXpDate;
  bool _soundEnabled = true;
  // Real XP earned per calendar day ("yyyy-MM-dd" -> XP) — the actual data
  // behind the "This week" activity chart. Kept separately from
  // [_todayXpRaw]/[_todayXpDate] (which only ever track the single most
  // recent day) so a day's activity survives past midnight instead of
  // being silently discarded the moment the next day starts.
  final Map<String, int> _dailyXpHistory = {};
  // The daily-reminder setting is pure data here — actually scheduling or
  // cancelling the platform notification is the caller's job (see
  // NotificationService), the same way sound playback lives outside this
  // store even though [_soundEnabled] does not.
  bool _notificationsEnabled = false;
  int _notificationHour = 18;
  int _notificationMinute = 0;

  int get streakDays => _streakDays;
  int get longestStreak => _longestStreak;
  int get totalXp => _totalXp;
  bool get expertChallengeCompleted => _expertChallengeCompleted;
  // The most recent attempt's accuracy (0.0-1.0) — null until it's been
  // completed at least once. Also folded into [esgFluency] automatically,
  // since that average simply reads every value in the same map.
  double? get expertChallengeAccuracy => _accuracy[_expertChallengeAccuracyKey];
  bool get soundEnabled => _soundEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  int get notificationHour => _notificationHour;
  int get notificationMinute => _notificationMinute;
  // Only terms whose review is actually due today — a term that was missed
  // yesterday and is scheduled to come back in 3 days doesn't show up here
  // in the meantime, by design.
  Set<String> get missedTermIds {
    final today = _dateOnly(DateTime.now());
    return _reviewSchedule.entries
        .where((e) => !e.value.dueDate.isAfter(today))
        .map((e) => e.key)
        .toSet();
  }

  int get missedCount => missedTermIds.length;

  /// Whether a term is still anywhere in the spaced-repetition schedule —
  /// including stages not due yet. Lets a caller (the review flow) tell a
  /// "fully mastered, removed for good" correct answer apart from one
  /// that's merely been deferred to its next, longer interval.
  bool isScheduled(String? termId) =>
      termId != null && _reviewSchedule.containsKey(termId);

  /// A quiz question tied to a real term ([QuizQuestion.termId]) was
  /// answered wrong — add it to the review queue. A no-op for scenario or
  /// expert-challenge questions, which have no single term to point at.
  Future<void> recordMiss(String? termId) async {
    if (termId == null) return;
    _reviewSchedule[termId] = _ReviewEntry(
      stage: 0,
      dueDate: _dateOnly(
        DateTime.now(),
      ).add(Duration(days: _reviewIntervalDays[0])),
    );
    notifyListeners();
    await _save();
  }

  /// The term was answered correctly — advance it to the next, longer
  /// interval, or remove it for good once it's cleared the final (7-day)
  /// stage. A no-op for a term that was never in the schedule to begin
  /// with (i.e. it was never missed).
  Future<void> clearMiss(String? termId) async {
    if (termId == null) return;
    final entry = _reviewSchedule[termId];
    if (entry == null) return;
    final nextStage = entry.stage + 1;
    if (nextStage >= _reviewIntervalDays.length) {
      _reviewSchedule.remove(termId);
    } else {
      _reviewSchedule[termId] = _ReviewEntry(
        stage: nextStage,
        dueDate: _dateOnly(
          DateTime.now(),
        ).add(Duration(days: _reviewIntervalDays[nextStage])),
      );
    }
    notifyListeners();
    await _save();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    await _save();
  }

  /// Persists the daily-reminder toggle/time. Purely data — the caller
  /// (the Profile screen) is responsible for actually requesting
  /// permission and scheduling/cancelling the notification itself via
  /// [NotificationService].
  Future<void> setNotificationSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    _notificationsEnabled = enabled;
    _notificationHour = hour;
    _notificationMinute = minute;
    notifyListeners();
    await _save();
  }

  // A simple Duolingo-style level, purely a function of lifetime XP — no
  // separate state to track or drift out of sync.
  int get level => (_totalXp ~/ _xpPerLevel) + 1;
  int get xpIntoLevel => _totalXp % _xpPerLevel;
  int get xpPerLevel => _xpPerLevel;

  // Stored XP only counts if it was actually earned today — reading this on
  // a new day before any practice correctly reads as 0 without needing an
  // explicit reset step.
  int get todayXp {
    final today = _dateOnly(DateTime.now());
    if (_todayXpDate == null || _dateOnly(_todayXpDate!) != today) return 0;
    return _todayXpRaw;
  }

  bool get dailyGoalMet => todayXp >= dailyGoalXp;

  /// Real XP earned on each day of the current calendar week (Monday
  /// first, index 0..6) — the actual data behind the "This week" activity
  /// chart on Stats and Profile. A day that hasn't happened yet this week
  /// reads as 0, exactly like a day with no practice; there's no
  /// fabricated shape to it either way.
  List<int> get thisWeekXp {
    final today = _dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        _dailyXpHistory[_dateKey(monday.add(Duration(days: i)))] ?? 0,
    ];
  }

  /// 0 = Monday .. 6 = Sunday, for highlighting "today" in the weekly chart.
  int get todayWeekdayIndex => DateTime.now().weekday - 1;

  // Only worth attempting once every real module has actually been learned
  // — this is meant to reward mastery, not gate content behind a paywall.
  bool get expertChallengeUnlocked =>
      totalModulesCount > 0 && completedModulesCount >= totalModulesCount;

  ModuleStatus statusFor(String moduleId) =>
      _statuses[moduleId] ?? ModuleStatus.available;

  List<String> get _allModuleIds =>
      MockData.units.expand((u) => u.modules).map((m) => m.id).toList();

  // Deliberately "done" only, not "current" — a module that was just
  // unlocked by finishing the previous one hasn't actually been learned
  // yet, even though it's now reachable.
  int get completedModulesCount =>
      _allModuleIds.where((id) => statusFor(id) == ModuleStatus.done).length;

  int get totalModulesCount => _allModuleIds.length;

  int get completedTermsCount => MockData.units
      .expand((u) => u.modules)
      .where((m) => statusFor(m.id) == ModuleStatus.done)
      .fold(0, (sum, m) => sum + m.termCount);

  /// Overall "ESG Fluency" — the average quiz+pairs accuracy across every
  /// module actually completed so far, as a 0-100 percentage. Distinct from
  /// XP: XP measures how much a learner has *done*; this measures how much
  /// of it is actually sticking. Null (not 0) when nothing's been completed
  /// yet, so the UI can show "not enough data" instead of a misleading 0%.
  double? get esgFluency {
    final values = _accuracy.values;
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length) * 100;
  }

  /// A rough, human-readable confidence label for one learning unit, based
  /// on the accuracy of whichever of its modules have actually been
  /// completed. Modules not yet done simply aren't counted — this reflects
  /// demonstrated performance, not a guess about unstudied material.
  String confidenceForUnit(LearningUnit unit) {
    final scores = [
      for (final m in unit.modules)
        if (_accuracy.containsKey(m.id)) _accuracy[m.id]!,
    ];
    if (scores.isEmpty) return 'Not started';
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    if (avg >= 0.90) return 'Strong';
    if (avg >= 0.75) return 'Confident';
    if (avg >= 0.50) return 'Developing';
    return 'Beginner';
  }

  // Milestones judged purely against the learner's own progress — no
  // fabricated "other users" data, since none exists in a local-only app.
  List<Achievement> get achievements => [
    Achievement(
      id: 'first-module',
      title: 'Getting Started',
      description: 'Complete your first module',
      icon: Icons.flag,
      unlocked: completedModulesCount >= 1,
    ),
    Achievement(
      id: 'week-streak',
      title: 'Week Warrior',
      description: 'Reach a 7-day streak',
      icon: Icons.local_fire_department,
      unlocked: longestStreak >= 7,
    ),
    Achievement(
      id: 'halfway',
      title: 'Halfway There',
      description: 'Complete half the curriculum',
      icon: Icons.trending_up,
      unlocked:
          totalModulesCount > 0 &&
          completedModulesCount >= (totalModulesCount / 2).ceil(),
    ),
    Achievement(
      id: 'month-streak',
      title: 'Committed',
      description: 'Reach a 30-day streak',
      icon: Icons.whatshot,
      unlocked: longestStreak >= 30,
    ),
    Achievement(
      id: 'curriculum',
      title: 'Curriculum Complete',
      description: 'Finish every module',
      icon: Icons.school,
      unlocked:
          totalModulesCount > 0 && completedModulesCount >= totalModulesCount,
    ),
    Achievement(
      id: 'expert',
      title: 'Expert',
      description: 'Complete the Expert Challenge',
      icon: Icons.workspace_premium,
      unlocked: expertChallengeCompleted,
    ),
  ];

  /// Loads persisted state, or seeds it from MockData's compiled-in
  /// defaults on a genuinely first-ever launch. Safe to call more than
  /// once — later calls are a no-op.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_keyXp)) {
      _streakDays = prefs.getInt(_keyStreak) ?? 0;
      _longestStreak = prefs.getInt(_keyLongestStreak) ?? 0;
      _totalXp = prefs.getInt(_keyXp) ?? 0;
      final lastPracticeIso = prefs.getString(_keyLastPractice);
      _lastPracticeDate = lastPracticeIso == null
          ? null
          : DateTime.tryParse(lastPracticeIso);

      final statusesJson = prefs.getString(_keyStatuses);
      if (statusesJson != null) {
        final decoded = jsonDecode(statusesJson) as Map<String, dynamic>;
        decoded.forEach(
          (id, value) =>
              _statuses[id] = ModuleStatus.values.byName(value as String),
        );
      }
      final accuracyJson = prefs.getString(_keyAccuracy);
      if (accuracyJson != null) {
        final decoded = jsonDecode(accuracyJson) as Map<String, dynamic>;
        decoded.forEach(
          (id, value) => _accuracy[id] = (value as num).toDouble(),
        );
      }
      final scheduleJson = prefs.getString(_keyReviewSchedule);
      if (scheduleJson != null) {
        final decoded = jsonDecode(scheduleJson) as Map<String, dynamic>;
        decoded.forEach((id, value) {
          final entry = value as Map<String, dynamic>;
          _reviewSchedule[id] = _ReviewEntry(
            stage: entry['stage'] as int,
            dueDate: DateTime.parse(entry['dueDate'] as String),
          );
        });
      }
      _expertChallengeCompleted = prefs.getBool(_keyExpertDone) ?? false;
      _todayXpRaw = prefs.getInt(_keyTodayXp) ?? 0;
      final todayXpIso = prefs.getString(_keyTodayXpDate);
      _todayXpDate = todayXpIso == null ? null : DateTime.tryParse(todayXpIso);
      _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
      _notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? false;
      _notificationHour = prefs.getInt(_keyNotificationHour) ?? 18;
      _notificationMinute = prefs.getInt(_keyNotificationMinute) ?? 0;

      final historyJson = prefs.getString(_keyDailyXpHistory);
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson) as Map<String, dynamic>;
        decoded.forEach(
          (day, xp) => _dailyXpHistory[day] = (xp as num).toInt(),
        );
      } else if (_todayXpDate != null && _todayXpRaw > 0) {
        // Upgrading from a version that only ever tracked a single day's XP
        // — seed today's entry from that so it isn't lost outright, even
        // though the days before it were never recorded.
        _dailyXpHistory[_dateKey(_dateOnly(_todayXpDate!))] = _todayXpRaw;
      }
    } else {
      _seedFreshState();
      await _save();
    }

    _loaded = true;
    notifyListeners();
  }

  // A genuinely blank slate — no XP, no streak, nothing pre-completed. Only
  // the very first module in the curriculum is unlocked; every other module
  // is locked until the learner actually earns their way there. A fake
  // "you've already used this" seed reads as confusing half-finished
  // progress on first open, not a welcoming demo.
  void _seedFreshState() {
    _statuses.clear();
    _accuracy.clear();
    _reviewSchedule.clear();
    _streakDays = 0;
    _longestStreak = 0;
    _totalXp = 0;
    _lastPracticeDate = null;
    _expertChallengeCompleted = false;
    _todayXpRaw = 0;
    _todayXpDate = null;
    _dailyXpHistory.clear();
    final firstModuleId = MockData.units.expand((u) => u.modules).first.id;
    _statuses[firstModuleId] = ModuleStatus.current;
  }

  /// Wipes all progress — streak, XP, module status, mistakes queue,
  /// accuracy, expert challenge — back to the same blank slate as a fresh
  /// install, without touching unrelated settings like sound preference.
  /// Lets a learner genuinely start over without reinstalling the app.
  Future<void> resetProgress() async {
    _seedFreshState();
    notifyListeners();
    await _save();
  }

  /// Marks a module done, promotes the next available module to current,
  /// records this attempt's quiz+pairs accuracy, awards XP, and updates the
  /// streak based on the calendar day.
  Future<void> completeLesson({
    required String moduleId,
    required int correct,
    required int total,
  }) async {
    // A rapid double-tap on a module card can push two LessonScreen
    // instances before the first navigation completes — without this
    // guard, finishing both would silently award XP twice for one lesson.
    final alreadyDone = statusFor(moduleId) == ModuleStatus.done;
    _statuses[moduleId] = ModuleStatus.done;
    if (total > 0) _accuracy[moduleId] = correct / total;

    final ids = _allModuleIds;
    final index = ids.indexOf(moduleId);
    if (index != -1 && index + 1 < ids.length) {
      final nextId = ids[index + 1];
      if (statusFor(nextId) == ModuleStatus.available) {
        _statuses[nextId] = ModuleStatus.current;
      }
    }

    if (!alreadyDone) _addXp(_xpPerLesson);
    _recordPracticeToday();

    notifyListeners();
    await _save();
  }

  /// Marks the expert challenge done and awards its (larger) one-off XP
  /// bonus. Doesn't touch module statuses — it sits outside the regular
  /// unit path, unlocked only once every module is already done. The
  /// challenge itself stays replayable (a passing retake still counts as
  /// today's practice for the streak), but the XP bonus is truly one-off —
  /// only the first completion pays out.
  Future<void> completeExpertChallenge({int? correct, int? total}) async {
    final alreadyCompleted = _expertChallengeCompleted;
    _expertChallengeCompleted = true;
    if (correct != null && total != null && total > 0) {
      _accuracy[_expertChallengeAccuracyKey] = correct / total;
    }
    if (!alreadyCompleted) _addXp(_xpExpertChallenge);
    _recordPracticeToday();

    notifyListeners();
    await _save();
  }

  void _addXp(int amount) {
    final today = _dateOnly(DateTime.now());
    if (_todayXpDate == null || _dateOnly(_todayXpDate!) != today) {
      _todayXpRaw = 0;
      _todayXpDate = today;
    }
    _todayXpRaw += amount;
    _totalXp += amount;
    final key = _dateKey(today);
    _dailyXpHistory[key] = (_dailyXpHistory[key] ?? 0) + amount;
  }

  void _recordPracticeToday() {
    final today = _dateOnly(DateTime.now());
    final last = _lastPracticeDate == null
        ? null
        : _dateOnly(_lastPracticeDate!);
    if (last == null || today.difference(last).inDays > 1) {
      _streakDays = 1;
    } else if (today.difference(last).inDays == 1) {
      _streakDays += 1;
    }
    // Same-day repeat practice leaves the streak unchanged.
    _lastPracticeDate = today;
    if (_streakDays > _longestStreak) _longestStreak = _streakDays;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStreak, _streakDays);
    await prefs.setInt(_keyLongestStreak, _longestStreak);
    await prefs.setInt(_keyXp, _totalXp);
    if (_lastPracticeDate != null) {
      await prefs.setString(
        _keyLastPractice,
        _lastPracticeDate!.toIso8601String(),
      );
    } else {
      // Reached only via resetProgress() — without this, a stale date
      // would linger in prefs and load() would read it back, corrupting
      // the streak on the very next practice after a reset.
      await prefs.remove(_keyLastPractice);
    }
    await prefs.setString(
      _keyStatuses,
      jsonEncode(_statuses.map((id, status) => MapEntry(id, status.name))),
    );
    await prefs.setString(_keyAccuracy, jsonEncode(_accuracy));
    await prefs.setString(
      _keyReviewSchedule,
      jsonEncode(
        _reviewSchedule.map(
          (id, entry) => MapEntry(id, {
            'stage': entry.stage,
            'dueDate': entry.dueDate.toIso8601String(),
          }),
        ),
      ),
    );
    await prefs.setBool(_keyExpertDone, _expertChallengeCompleted);
    await prefs.setInt(_keyTodayXp, _todayXpRaw);
    if (_todayXpDate != null) {
      await prefs.setString(_keyTodayXpDate, _todayXpDate!.toIso8601String());
    } else {
      // Same reasoning as _keyLastPractice above — clear it on reset instead
      // of leaving a stale date for load() to read back.
      await prefs.remove(_keyTodayXpDate);
    }
    await prefs.setBool(_keySoundEnabled, _soundEnabled);
    await prefs.setBool(_keyNotificationsEnabled, _notificationsEnabled);
    await prefs.setInt(_keyNotificationHour, _notificationHour);
    await prefs.setInt(_keyNotificationMinute, _notificationMinute);

    // Keep a rolling ~5 weeks of history — enough for the weekly chart
    // plus headroom — rather than growing this map forever over months of
    // real use.
    final cutoff = _dateOnly(DateTime.now()).subtract(const Duration(days: 34));
    _dailyXpHistory.removeWhere((key, _) {
      final d = DateTime.tryParse(key);
      return d == null || d.isBefore(cutoff);
    });
    await prefs.setString(_keyDailyXpHistory, jsonEncode(_dailyXpHistory));
  }

  /// Test-only: marks every module done, to reach the expert-challenge-
  /// unlocked state without literally completing 16 lessons through the UI.
  @visibleForTesting
  void completeAllModulesForTest() {
    for (final id in _allModuleIds) {
      _statuses[id] = ModuleStatus.done;
    }
    notifyListeners();
  }

  /// Test-only: makes every currently-scheduled review term due right now,
  /// so a test can exercise "wrong answer -> shows up to revisit" without
  /// waiting for a real day (or several) to pass.
  @visibleForTesting
  void makeAllReviewsDueForTest() {
    final today = _dateOnly(DateTime.now());
    for (final entry in _reviewSchedule.values) {
      entry.dueDate = today;
    }
    notifyListeners();
  }

  /// Test-only: drops in-memory state so each test starts clean.
  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _statuses.clear();
    _accuracy.clear();
    _reviewSchedule.clear();
    _streakDays = 0;
    _longestStreak = 0;
    _totalXp = 0;
    _lastPracticeDate = null;
    _expertChallengeCompleted = false;
    _todayXpRaw = 0;
    _todayXpDate = null;
    _soundEnabled = true;
    _dailyXpHistory.clear();
    _notificationsEnabled = false;
    _notificationHour = 18;
    _notificationMinute = 0;
  }
}

/// One term's position in the spaced-repetition cycle: which stage
/// (0 = 1-day, 1 = 3-day, 2 = 7-day) it's at, and when it's next due.
class _ReviewEntry {
  _ReviewEntry({required this.stage, required this.dueDate});

  final int stage;
  DateTime dueDate;
}
