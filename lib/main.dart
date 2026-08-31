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
      // On a wide browser window that would stretch every card edge-to-edge,
      // so cap it — generously, not phone-width — and fill the margin with
      // the app's own page background rather than a stark letterbox color,
      // so it reads as page whitespace instead of dead space. Narrower
      // viewports (mobile browsers) are unaffected since this only ever
      // caps width, never forces it.
      builder: kIsWeb
          ? (context, child) => ColoredBox(
              color: AppColors.bg,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            )
          : null,
      home: const IntroScreen(),
    );
  }
}
