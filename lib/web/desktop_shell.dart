import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'responsive.dart';

/// The web build's persistent frame around the three top-level tabs — a
/// fixed sidebar instead of the native app's bottom tab bar, so the site
/// reads as a website with real pages (own URL, working browser
/// back/forward/refresh) rather than a phone screen pasted into a browser
/// tab. Only used on web; the native app never builds this.
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    // "Learning", not "Path" — a review round called "Path" gamified for
    // a professional audience. This file is web-only regardless.
    _NavTab(location: '/home', icon: Icons.route, label: 'Learning'),
    _NavTab(
      location: '/glossary',
      icon: Icons.menu_book_outlined,
      label: 'Glossary',
    ),
    // Stats+Profile merged into one destination — see ProgressScreen.
    _NavTab(
      location: '/progress',
      icon: Icons.bar_chart_outlined,
      label: 'Progress',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Narrow web viewports (a phone browser) get the same single-column
    // layout as the native app instead — including its own bottom tab bar,
    // which each screen still renders itself below this breakpoint. A
    // fixed 240px sidebar would leave next to nothing for content there.
    if (!isDesktopWeb(context)) return child;

    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      backgroundColor: LedgerColors.contentBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(location: location, tabs: _tabs),
          Expanded(
            // Scopes ScaffoldMessenger.of(context) calls made by the routed
            // screen (e.g. "Already completed" snackbars) to this content
            // column, so they don't stretch under the sidebar too.
            child: ScaffoldMessenger(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.location,
    required this.icon,
    required this.label,
  });

  final String location;
  final IconData icon;
  final String label;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, required this.tabs});

  final String location;
  final List<_NavTab> tabs;

  @override
  Widget build(BuildContext context) {
    // "The Ledger" — a dark, monospace-driven rail chosen from a set of
    // mockups over the plain-white/navy sidebars tried earlier this
    // session, aiming for "internal compliance tool" rather than "app".
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: LedgerColors.railBg,
        border: Border(right: BorderSide(color: LedgerColors.railBorder)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              // The wordmark doubles as a "home" link, same as on any real
              // website — from any tab, this is how you get back to
              // Learning. InkWell/Material, not a bare GestureDetector —
              // matching _SidebarLink's already-working tap pattern.
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('sidebar-wordmark'),
                  onTap: () => context.go('/home'),
                  mouseCursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: LedgerColors.gold,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SUSTAINWISE',
                        style: TextStyle(
                          fontFamily: LedgerColors.fontMono,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.6,
                          color: Color(0xFFEDEAE3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Divider(height: 1, color: LedgerColors.railBorder),
            ),
            for (final tab in tabs)
              _SidebarLink(tab: tab, selected: location == tab.location),
            const Spacer(),
            // A visitor who arrived via a shared app.sustainwiseapp.com
            // link has otherwise had no way to find the marketing site.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: LedgerColors.railBorder),
                  const SizedBox(height: 14),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () =>
                          launchUrl(Uri.parse('https://sustainwiseapp.com')),
                      child: const Text(
                        'sustainwiseapp.com',
                        style: TextStyle(
                          fontFamily: LedgerColors.fontMono,
                          fontSize: 10.5,
                          letterSpacing: 0.2,
                          color: LedgerColors.railTextDim,
                          decoration: TextDecoration.underline,
                          decorationColor: LedgerColors.railTextDim,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarLink extends StatefulWidget {
  const _SidebarLink({required this.tab, required this.selected});

  final _NavTab tab;
  final bool selected;

  @override
  State<_SidebarLink> createState() => _SidebarLinkState();
}

class _SidebarLinkState extends State<_SidebarLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? LedgerColors.gold : LedgerColors.railText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Material(
          color: widget.selected
              ? LedgerColors.railSelectedBg
              : (_hovering ? LedgerColors.railSelectedBg : Colors.transparent),
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => context.go(widget.tab.location),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: Row(
                children: [
                  Icon(widget.tab.icon, size: 15, color: color),
                  const SizedBox(width: 10),
                  Text(
                    widget.tab.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: LedgerColors.fontMono,
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
