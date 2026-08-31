import 'package:go_router/go_router.dart';
import '../screens/glossary_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/stats_screen.dart';
import 'desktop_shell.dart';
import 'page_title.dart';

const Map<String, String> _pageTitles = {
  '/home': 'Path — SustainWise',
  '/glossary': 'Glossary — SustainWise',
  '/stats': 'Stats — SustainWise',
  '/profile': 'Profile — SustainWise',
};

/// Web-only: gives the four top-level tabs their own real URL (own
/// browser-history entry, working back/forward/refresh) inside a shared
/// [DesktopShell]. Deeper flows reached from within a tab — a lesson, the
/// Expert Challenge, the Regulatory Radar — stay on the existing imperative
/// Navigator pushes used by the native app; only the tab switcher itself
/// needed a real router.
GoRouter buildWebRouter() {
  return GoRouter(
    initialLocation: '/home',
    // A branded splash before any content is normal for an app cold
    // start, but a visitor landing on a website to quickly look something
    // up doesn't want a mandatory ~1.3s wait on every plain visit to the
    // bare domain — '/' always goes straight to Home. Any other unmatched
    // path (a stale bookmark, a typo) does too, instead of go_router's
    // bare default error page.
    redirect: (context, state) {
      const known = {'/home', '/glossary', '/stats', '/profile'};
      return known.contains(state.matchedLocation) ? null : '/home';
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          // Every SustainWise tab otherwise shows the same static title
          // from index.html regardless of which page is open — confusing
          // with more than one tab open, and a shared /glossary?q=dnsh
          // link deserves a tab title that actually names the term.
          final query = state.uri.queryParameters['q'];
          final base = _pageTitles[state.matchedLocation] ?? 'SustainWise';
          setPageTitle(
            (state.matchedLocation == '/glossary' &&
                    query != null &&
                    query.isNotEmpty)
                ? '$query — Glossary — SustainWise'
                : base,
          );
          return DesktopShell(child: child);
        },
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
