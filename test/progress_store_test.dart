import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sustainwise/data/models.dart';
import 'package:sustainwise/data/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressStore store;
  late List<String> moduleIds;

  setUpAll(() async {
    await MockData.load();
    moduleIds = [
      for (final u in MockData.units)
        for (final m in u.modules) m.id,
    ];
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ProgressStore.instance..resetForTest();
    await store.load();
  });

  tearDown(() => store.resetForTest());

  DateTime day(int d, [int hour = 10]) => DateTime(2026, 3, d, hour);

  group('streak freeze', () {
    test('bridges exactly one missed day, once per week', () async {
      store.clock = () => day(2);
      await store.completeLesson(moduleId: moduleIds[0], correct: 8, total: 10);
      expect(store.streakDays, 1);

      // Day 3 is missed; on day 4 the freeze still keeps the streak alive.
      store.clock = () => day(4);
      expect(store.streakFreezeAvailable, isTrue);
      expect(store.streakAtRisk, isTrue);
      expect(store.streakDays, 1);

      await store.completeLesson(moduleId: moduleIds[1], correct: 8, total: 10);
      expect(store.streakDays, 2);
      expect(store.streakFreezeAvailable, isFalse);
      expect(store.streakAtRisk, isFalse);

      // Another missed day within the same week is NOT covered.
      store.clock = () => day(6);
      expect(store.streakDays, 0);
      await store.completeLesson(moduleId: moduleIds[2], correct: 8, total: 10);
      expect(store.streakDays, 1);

      // A week after the freeze was spent (it saved day 3), it is back.
      store.clock = () => day(10);
      expect(store.streakFreezeAvailable, isTrue);
    });

    test('two or more missed days always end the streak', () async {
      store.clock = () => day(2);
      await store.completeLesson(moduleId: moduleIds[0], correct: 8, total: 10);
      store.clock = () => day(5);
      expect(store.streakDays, 0);
      expect(store.streakAtRisk, isFalse);
    });

    test('a normal consecutive day does not spend the freeze', () async {
      store.clock = () => day(2);
      await store.completeLesson(moduleId: moduleIds[0], correct: 8, total: 10);
      store.clock = () => day(3);
      await store.completeLesson(moduleId: moduleIds[1], correct: 8, total: 10);
      expect(store.streakDays, 2);
      expect(store.streakFreezeAvailable, isTrue);
    });
  });

  group('streak freeze: the 7-day gap is measured between saved days', () {
    Future<void> practise(int d) async {
      store.clock = () => day(d);
      await store.completeLesson(
        moduleId: moduleIds[d % moduleIds.length],
        correct: 8,
        total: 10,
      );
    }

    test('a second freeze 6 days after the first is refused', () async {
      await practise(2);
      await practise(4); // missed day 3: the freeze saves it
      for (final d in [5, 6, 7, 8]) {
        await practise(d);
      }
      expect(store.streakDays, 6);

      // Missed day 9. Spending a freeze on day 9 is only 6 days after the
      // one that saved day 3, so it must be refused: the streak is over.
      store.clock = () => day(10);
      expect(store.streakAtRisk, isFalse);
      expect(store.streakDays, 0);
      await practise(10);
      expect(store.streakDays, 1);
    });

    test('a second freeze 7 days after the first is allowed', () async {
      await practise(2);
      await practise(4); // saves day 3
      for (final d in [5, 6, 7, 8, 9]) {
        await practise(d);
      }
      // Missed day 10: exactly 7 days after day 3, so a freeze may cover it.
      store.clock = () => day(11);
      expect(store.streakAtRisk, isTrue);
      expect(store.streakDays, 7);
      await practise(11);
      expect(store.streakDays, 8);
    });

    test('the freeze state survives a reload', () async {
      await practise(2);
      await practise(4);
      expect(store.streakFreezeAvailable, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('streak_freeze_used_on'), isNotNull);

      store.resetForTest();
      store.clock = () => day(4);
      await store.load();
      expect(store.streakFreezeAvailable, isFalse);
    });

    // The streak uses calendar-field arithmetic, so a 23- or 25-hour day
    // (European clock changes on 29 March and 25 October 2026) can never
    // look like "no day passed". These dates straddle both changes.
    test('consecutive days across the clock changes keep counting', () async {
      for (final (month, days) in [
        (3, [28, 29, 30, 31]),
        (10, [24, 25, 26, 27]),
      ]) {
        store.resetForTest();
        SharedPreferences.setMockInitialValues({});
        await store.load();
        for (var i = 0; i < days.length; i++) {
          store.clock = () => DateTime(2026, month, days[i], 23, 30);
          await store.completeLesson(
            moduleId: moduleIds[i],
            correct: 8,
            total: 10,
          );
          expect(
            store.streakDays,
            i + 1,
            reason: 'month $month day ${days[i]}',
          );
        }
      }
    });

    test(
      'practising twice on the same day does not change the streak',
      () async {
        await practise(2);
        store.clock = () => day(2, 22);
        await store.completeLesson(
          moduleId: moduleIds[3],
          correct: 8,
          total: 10,
        );
        expect(store.streakDays, 1);
      },
    );
  });

  test('concurrent saves leave a consistent state on disk', () async {
    // Several actions within one moment: all must end up persisted.
    await Future.wait([
      store.toggleFavorite('a'),
      store.setLearnerRole('curious'),
      store.setMilestoneFollowed('milestone_001', true),
      store.completeLesson(moduleId: moduleIds[0], correct: 9, total: 10),
      store.toggleFavorite('b'),
    ]);
    store.resetForTest();
    await store.load();
    expect(store.favoriteTermKeys, {'a', 'b'});
    expect(store.learnerRole, 'curious');
    expect(store.isFollowingMilestone('milestone_001'), isTrue);
    expect(store.statusFor(moduleIds[0]), ModuleStatus.done);
  });

  test(
    'a score of exactly 85% is not a weak spot; equal scores keep order',
    () async {
      await store.completeLesson(
        moduleId: moduleIds[0],
        correct: 17,
        total: 20,
      );
      await store.completeLesson(moduleId: moduleIds[1], correct: 5, total: 10);
      await store.completeLesson(moduleId: moduleIds[2], correct: 5, total: 10);
      expect(store.weakModuleIds(), [moduleIds[1], moduleIds[2]]);
    },
  );

  group('mastery', () {
    test('levels follow the latest accuracy', () async {
      expect(store.masteryFor(moduleIds[0]), 0);
      await store.completeLesson(moduleId: moduleIds[0], correct: 6, total: 10);
      expect(store.masteryFor(moduleIds[0]), 1);
      await store.completeLesson(moduleId: moduleIds[1], correct: 8, total: 10);
      expect(store.masteryFor(moduleIds[1]), 2);
      await store.completeLesson(
        moduleId: moduleIds[2],
        correct: 10,
        total: 10,
      );
      expect(store.masteryFor(moduleIds[2]), 3);
    });

    test(
      'weak modules are the completed ones below 85%, weakest first',
      () async {
        await store.completeLesson(
          moduleId: moduleIds[0],
          correct: 8,
          total: 10,
        );
        await store.completeLesson(
          moduleId: moduleIds[1],
          correct: 5,
          total: 10,
        );
        await store.completeLesson(
          moduleId: moduleIds[2],
          correct: 10,
          total: 10,
        );
        expect(store.weakModuleIds(), [moduleIds[1], moduleIds[0]]);
      },
    );
  });

  group('preferences survive a reset of progress', () {
    test('favourites, followed milestones and role are kept', () async {
      await store.toggleFavorite('finance_011');
      await store.setMilestoneFollowed('milestone_003', true);
      await store.setLearnerRole('finance');
      await store.completeLesson(moduleId: moduleIds[0], correct: 8, total: 10);

      await store.resetProgress();

      expect(store.completedModulesCount, 0);
      expect(store.isFavorite('finance_011'), isTrue);
      expect(store.isFollowingMilestone('milestone_003'), isTrue);
      expect(store.learnerRole, 'finance');
    });

    test('toggling twice removes a favourite; values are persisted', () async {
      await store.toggleFavorite('a');
      await store.toggleFavorite('b');
      await store.toggleFavorite('a');
      expect(store.favoriteTermKeys, {'b'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favorite_term_keys'), ['b']);
    });
  });

  group('upgrading from an older version', () {
    // The exact keys a 1.6.x install wrote: nothing of the new features
    // (freeze, favourites, followed dates, role) exists yet.
    Map<String, Object> oldInstall() => {
      'streak_days': 5,
      'longest_streak': 9,
      'total_xp': 480,
      'last_practice_date': DateTime(2026, 11, 13, 20).toIso8601String(),
      'module_statuses': '{"esg-fundamentals":"done","csr-ethics":"done"}',
      'module_accuracy': '{"esg-fundamentals":0.9,"csr-ethics":0.7}',
      'review_schedule':
          '{"finance_011":{"stage":1,"dueDate":"2026-11-20T00:00:00.000"}}',
      'expert_challenge_done': false,
      'today_xp': 15,
      'today_xp_date': DateTime(2026, 11, 13).toIso8601String(),
      'sound_enabled': false,
      'notifications_enabled': true,
      'notification_hour': 8,
      'notification_minute': 30,
      'daily_xp_history': '{"2026-11-13":15}',
    };

    test('keeps all existing progress and starts new features empty', () async {
      SharedPreferences.setMockInitialValues(oldInstall());
      store.resetForTest();
      store.clock = () => DateTime(2026, 11, 14, 9);
      await store.load();

      expect(store.totalXp, 480);
      expect(store.longestStreak, 9);
      expect(store.streakDays, 5, reason: 'practised yesterday: alive');
      expect(store.statusFor('esg-fundamentals'), ModuleStatus.done);
      expect(store.statusFor('csr-ethics'), ModuleStatus.done);
      expect(store.completedModulesCount, 2);
      expect(store.soundEnabled, isFalse);
      expect(store.notificationsEnabled, isTrue);
      expect(store.notificationHour, 8);
      expect(store.isScheduled('finance_011'), isTrue);

      // New things default to "nothing yet", and the freeze is available.
      expect(store.favoriteTermKeys, isEmpty);
      expect(store.followedMilestoneIds, isEmpty);
      expect(store.learnerRole, isNull);
      expect(store.streakFreezeAvailable, isTrue);
      expect(store.masteryFor('esg-fundamentals'), 3);
      expect(store.masteryFor('csr-ethics'), 1);
      expect(store.masteryFor('sfdr'), 0);
    });

    test(
      'a learner who had finished all 16 modules is not marked complete',
      () async {
        // The 17th module is new: the expert challenge waits for it.
        final old16 = [
          for (final id in moduleIds)
            if (id != 'esg-ratings-data-providers') id,
        ];
        expect(old16.length, 16);
        SharedPreferences.setMockInitialValues({
          ...oldInstall(),
          'module_statuses': '{${old16.map((id) => '"$id":"done"').join(',')}}',
        });
        store.resetForTest();
        await store.load();

        expect(store.completedModulesCount, 16);
        expect(store.totalModulesCount, 17);
        expect(store.expertChallengeUnlocked, isFalse);
        expect(
          store.statusFor('esg-ratings-data-providers'),
          ModuleStatus.current,
        );

        // Finishing the new module restores the unlock.
        await store.completeLesson(
          moduleId: 'esg-ratings-data-providers',
          correct: 9,
          total: 10,
        );
        expect(store.expertChallengeUnlocked, isTrue);
      },
    );

    test('one damaged value only loses that value, not the progress', () async {
      for (final damaged in [
        'daily_xp_history',
        'module_accuracy',
        'review_schedule',
        'module_statuses',
      ]) {
        SharedPreferences.setMockInitialValues({
          ...oldInstall(),
          damaged: 'not json at all',
        });
        store.resetForTest();
        await store.load();

        expect(store.isLoaded, isTrue, reason: damaged);
        expect(store.totalXp, 480, reason: '$damaged must not wipe XP');
        expect(store.longestStreak, 9, reason: damaged);
        expect(store.soundEnabled, isFalse, reason: damaged);
        if (damaged != 'module_statuses') {
          expect(store.completedModulesCount, 2, reason: damaged);
        } else {
          expect(store.completedModulesCount, 0);
        }
      }
    });

    test('loading damaged data does not write anything back', () async {
      SharedPreferences.setMockInitialValues({
        ...oldInstall(),
        'daily_xp_history': '{"2026-11-13": "lots"}',
      });
      store.resetForTest();
      await store.load();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_xp'), 480);
      expect(prefs.getString('daily_xp_history'), '{"2026-11-13": "lots"}');
    });

    test('a wrong type for a number falls back for that field only', () async {
      SharedPreferences.setMockInitialValues({
        ...oldInstall(),
        'notification_hour': 'eight',
      });
      store.resetForTest();
      await store.load();
      expect(store.totalXp, 480);
      expect(store.notificationHour, 18, reason: 'back to the default');
    });

    test('a brand-new install starts fresh and saves it', () async {
      SharedPreferences.setMockInitialValues({});
      store.resetForTest();
      await store.load();
      expect(store.completedModulesCount, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('total_xp'), 0);
    });
  });

  test('weekly recap compares this week with last week', () async {
    // Monday 2026-03-09 is the start of "this week"; 2026-03-02 is last week.
    store.clock = () => day(3);
    await store.completeLesson(moduleId: moduleIds[0], correct: 8, total: 10);
    store.clock = () => day(10);
    await store.completeLesson(moduleId: moduleIds[1], correct: 8, total: 10);
    store.clock = () => day(11);
    await store.completeLesson(moduleId: moduleIds[2], correct: 8, total: 10);

    expect(store.xpLastWeek, 15);
    expect(store.activeDaysThisWeek, 2);
  });
}
