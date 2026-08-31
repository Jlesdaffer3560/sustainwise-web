import 'package:go_router/go_router.dart';
import '../screens/glossary_screen.dart';
import '../screens/home_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/stats_screen.dart';
import 'desktop_shell.dart';

/// Web-only: gives the four top-level tabs their own real URL (own
/// browser-history entry, working back/forward/refresh) inside a shared
/// [DesktopShell]. Deeper flows reached from within a tab — a lesson, the
/// Expert Challenge, the Regulatory Radar — stay on the existing imperative
/// Navigator pushes used by the native app; only the tab switcher itself
/// needed a real router.
GoRouter buildWebRouter() {
  return GoRouter(
    initialLocation: '/',
    // Any unmatched path (a stale bookmark, a typo) lands on Home instead
    // of go_router's bare default error page.
    redirect: (context, state) {
      const known = {'/', '/home', '/glossary', '/stats', '/profile'};
      return known.contains(state.matchedLocation) ? null : '/home';
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const IntroScreen()),
      ShellRoute(
        builder: (context, state, child) => DesktopShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/glossary',
            // A search from Home's search bar goes through this query
            // param (/glossary?q=dnsh) instead of an imperative Navigator
            // push, so the result is a real URL — shareable, bookmarkable,
            // and restored correctly on refresh.
            builder: (context, state) =>
                GlossaryScreen(initialQuery: state.uri.queryParameters['q']),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
