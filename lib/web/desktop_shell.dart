import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'responsive.dart';

/// The web build's persistent frame around the four top-level tabs — a
/// fixed sidebar instead of the native app's bottom tab bar, so the site
/// reads as a website with real pages (own URL, working browser
/// back/forward/refresh) rather than a phone screen pasted into a browser
/// tab. Only used on web; the native app never builds this.
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _NavTab(location: '/home', icon: Icons.route, label: 'Path'),
    _NavTab(
      location: '/glossary',
      icon: Icons.menu_book_outlined,
      label: 'Glossary',
    ),
    _NavTab(location: '/stats', icon: Icons.bar_chart_outlined, label: 'Stats'),
    _NavTab(
      location: '/profile',
      icon: Icons.person_outline,
      label: 'Profile',
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
      backgroundColor: AppColors.bg,
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
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              // The wordmark doubles as a "home" link, same as on any real
              // website — from any tab, this is how you get back to Path.
              // InkWell/Material, not a bare GestureDetector — matching
              // _SidebarLink's already-working tap pattern exactly, on the
              // chance the two behaved differently under some gesture-arena
              // edge case that never showed up in an isolated test.
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('sidebar-wordmark'),
                  onTap: () => context.go('/home'),
                  mouseCursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SustainWise',
                        style: TextStyle(
                          fontFamily: 'LoraItalic',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Text(
                'Learn. Practice. Track.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            for (final tab in tabs)
              _SidebarLink(tab: tab, selected: location == tab.location),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'sustainwiseapp.com',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
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
    final color = widget.selected ? AppColors.teal : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Material(
          color: widget.selected
              ? AppColors.teal.withValues(alpha: 0.10)
              : (_hovering
                    ? AppColors.border.withValues(alpha: 0.5)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(widget.tab.location),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              child: Row(
                children: [
                  Icon(widget.tab.icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Text(
                    widget.tab.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w600,
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
