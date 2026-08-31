import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'data/models.dart';
import 'data/progress_store.dart';
import 'screens/intro_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MockData.load();
  await ProgressStore.instance.load();

  // Re-schedule with a freshly-computed streak count on every launch, if
  // the reminder is already on — the alarm itself survives between
  // launches regardless, but this keeps its message from going stale.
  final store = ProgressStore.instance;
  if (store.notificationsEnabled) {
    // Swallow failures here — a plugin/timezone hiccup on this best-effort
    // refresh shouldn't surface as an uncaught async error this far from
    // any UI that could show it.
    unawaited(
      NotificationService.instance
          .scheduleDaily(
            hour: store.notificationHour,
            minute: store.notificationMinute,
            body: NotificationService.instance.reminderBody(store.streakDays),
          )
          .catchError((_) {}),
    );
  }

  runApp(const EsgJargonApp());
}

class EsgJargonApp extends StatelessWidget {
  const EsgJargonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SustainWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // The whole UI is built mobile-first (bottom nav, phone-width cards).
      // On web, a wide browser window would otherwise stretch that layout
      // edge-to-edge, so pin it to a phone-width column and letterbox the
      // rest — narrower viewports (mobile browsers) are unaffected since
      // the constraint only ever caps width, never forces it.
      builder: kIsWeb
          ? (context, child) => ColoredBox(
              color: AppColors.ink,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: child,
                ),
              ),
            )
          : null,
      home: const IntroScreen(),
    );
  }
}
