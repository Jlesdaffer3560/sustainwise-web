import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'data/models.dart';
import 'data/progress_store.dart';
import 'screens/intro_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'web/web_router.dart';

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
    // Web gets a real router: each top-level tab is its own URL inside a
    // persistent sidebar (DesktopShell), so the site behaves like a
    // website (working back/forward/refresh) instead of a single phone
    // screen pasted into a browser tab. The native app keeps its original,
    // untouched single-Navigator setup.
    if (kIsWeb) {
      return MaterialApp.router(
        title: 'SustainWise',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: buildWebRouter(),
      );
    }
    return MaterialApp(
      title: 'SustainWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const IntroScreen(),
    );
  }
}
