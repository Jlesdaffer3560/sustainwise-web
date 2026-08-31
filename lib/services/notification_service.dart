import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The daily reminder — a once-a-day local (not push) notification nudging
/// a learner back in if they haven't practiced yet. Wraps
/// flutter_local_notifications directly rather than through ProgressStore,
/// which only ever persists plain data and never touches a platform plugin.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _dailyReminderId = 1001;
  // "_v2" — not just cosmetic: Android notification channels are immutable
  // once created (importance/sound can only be changed by the user in
  // system settings, never by the app). Renaming forces a fresh channel
  // with the corrected settings below, rather than silently inheriting
  // whatever the original "daily_reminder" channel ended up with from
  // earlier testing (including a possible manual mute).
  static const _channelId = 'daily_reminder_v2';
  static const _channelName = 'Daily reminder';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // No platform timezone name available — the reminder still fires
      // daily, just anchored to UTC clock time instead of the device's.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    _initialized = true;
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS permission. Returns false
  /// if the user denies it — the caller should leave the reminder toggle
  /// off in that case rather than silently scheduling a notification that
  /// will never actually show.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Schedules (or reschedules) the daily reminder for [hour]:[minute],
  /// with [body] as its message. Inexact scheduling — a once-a-day nudge
  /// doesn't need to-the-minute precision, and skipping exact alarms means
  /// no extra SCHEDULE_EXACT_ALARM permission prompt for the user.
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'SustainWise',
      body: body,
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'A once-a-day nudge to keep your streak alive.',
          // High, not default — a reminder that's easy to miss defeats the
          // point. High importance is what makes Android show it as a
          // heads-up banner with sound, instead of a silent shade-only entry.
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDaily() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _dailyReminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// A short, streak-aware reminder message — computed fresh each time the
  /// reminder is (re)scheduled rather than baked in once, so it stays
  /// reasonably current across the app's lifetime.
  String reminderBody(int streakDays) {
    if (streakDays >= 2) {
      return "Your $streakDays-day streak is waiting — keep it alive with a quick lesson.";
    }
    return 'Got 5 minutes? A quick ESG vocab session is waiting for you.';
  }

  @visibleForTesting
  void resetForTest() => _initialized = false;
}
