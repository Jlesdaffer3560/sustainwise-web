import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  static const _keyStreak = 'streak_days';
  static const _keyLongestStreak = 'longest_streak';
  static const _keyXp = 'total_xp';
  static const _keyLastPractice = 'last_practice_date';
  static const _keyStatuses = 'module_statuses';

  bool _loaded = false;
  bool get isLoaded => _loaded;

  int _streakDays = 0;
  int _longestStreak = 0;
  int _totalXp = 0;
  DateTime? _lastPracticeDate;
  final Map<String, ModuleStatus> _statuses = {};

  int get streakDays => _streakDays;
  int get longestStreak => _longestStreak;
  int get totalXp => _totalXp;

  ModuleStatus statusFor(String moduleId) => _statuses[moduleId] ?? ModuleStatus.available;

  List<String> get _allModuleIds => MockData.units.expand((u) => u.modules).map((m) => m.id).toList();

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
      _lastPracticeDate = lastPracticeIso == null ? null : DateTime.tryParse(lastPracticeIso);

      final statusesJson = prefs.getString(_keyStatuses);
      if (statusesJson != null) {
        final decoded = jsonDecode(statusesJson) as Map<String, dynamic>;
        decoded.forEach((id, value) => _statuses[id] = ModuleStatus.values.byName(value as String));
      }
    } else {
      _streakDays = MockData.defaultStreakDays;
      _longestStreak = MockData.defaultLongestStreak;
      _totalXp = MockData.defaultTotalXp;
      // Seed as if the existing streak was last extended yesterday, so the
      // very first real lesson today correctly extends it to 13 instead of
      // reading as "no prior practice" and resetting it down to 1.
      _lastPracticeDate = _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      for (final module in MockData.units.expand((u) => u.modules)) {
        _statuses[module.id] = module.status;
      }
      await _save();
    }

    _loaded = true;
    notifyListeners();
  }

  /// Marks a module done, promotes the next available module to current,
  /// awards XP, and updates the streak based on the calendar day.
  Future<void> completeLesson({required String moduleId}) async {
    _statuses[moduleId] = ModuleStatus.done;

    final ids = _allModuleIds;
    final index = ids.indexOf(moduleId);
    if (index != -1 && index + 1 < ids.length) {
      final nextId = ids[index + 1];
      if (statusFor(nextId) == ModuleStatus.available) {
        _statuses[nextId] = ModuleStatus.current;
      }
    }

    _totalXp += _xpPerLesson;

    final today = _dateOnly(DateTime.now());
    final last = _lastPracticeDate == null ? null : _dateOnly(_lastPracticeDate!);
    if (last == null || today.difference(last).inDays > 1) {
      _streakDays = 1;
    } else if (today.difference(last).inDays == 1) {
      _streakDays += 1;
    }
    // Same-day repeat practice leaves the streak unchanged.
    _lastPracticeDate = today;
    if (_streakDays > _longestStreak) _longestStreak = _streakDays;

    notifyListeners();
    await _save();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStreak, _streakDays);
    await prefs.setInt(_keyLongestStreak, _longestStreak);
    await prefs.setInt(_keyXp, _totalXp);
    if (_lastPracticeDate != null) {
      await prefs.setString(_keyLastPractice, _lastPracticeDate!.toIso8601String());
    }
    await prefs.setString(_keyStatuses, jsonEncode(_statuses.map((id, status) => MapEntry(id, status.name))));
  }

  /// Test-only: drops in-memory state so each test starts clean.
  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _statuses.clear();
    _streakDays = 0;
    _longestStreak = 0;
    _totalXp = 0;
    _lastPracticeDate = null;
  }
}
