import 'package:go_router/go_router.dart';
import '../screens/glossary_screen.dart';
import '../screens/home_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/regulatory_radar_screen.dart';
import 'desktop_shell.dart';
import 'page_title.dart';

const Map<String, String> _pageTitles = {
  '/home': 'Learning — SustainWise',
  '/glossary': 'Glossary — SustainWise',
  '/progress': 'Progress — SustainWise',
  '/radar': 'Regulatory Radar — SustainWise',
};

/// Web-only: gives the three top-level tabs their own real URL (own
/// browser-history entry, working back/forward/refresh) inside a shared
/// [DesktopShell], plus a standalone route for the Regulatory Radar — pure
/// reference content with no per-visitor state, and the one "deeper flow"
/// worth being directly shareable/bookmarkable per external review. A
/// lesson, quiz, or the Expert Challenge stay on the existing imperative
/// Navigator pushes used by the native app: sequential, stateful flows a
/// mid-flow deep link wouldn't make sense for anyway.
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
      // Stats and Profile merged into one Progress screen — old bookmarks
      // or shared links to either still land somewhere real instead of
      // falling through to the generic unknown-path redirect below.
      final loc = state.matchedLocation;
      if (loc == '/stats' || loc == '/profile') return '/progress';
      const known = {'/home', '/glossary', '/progress', '/radar'};
      return known.contains(loc) ? null : '/home';
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
            path: '/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
        ],
      ),
      // Outside the ShellRoute deliberately — this is a drill-down from
      // Home's own card (see home_screen.dart's regulatory radar tap), not
      // a peer of the three sidebar tabs, so it keeps its existing
      // full-screen AppBar-with-back-button treatment rather than gaining
      // a persistent sidebar it was never designed to sit inside.
      GoRoute(
        path: '/radar',
        builder: (context, state) {
          setPageTitle(_pageTitles['/radar']!);
          return const RegulatoryRadarScreen();
        },
      ),
    ],
  );
}
