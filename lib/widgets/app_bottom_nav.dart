import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

enum AppTab { path, glossary, stats, profile }

/// The Path/Glossary/Stats/Profile tab bar, shared by every top-level
/// screen so its behavior (and which tab lights up) never drifts between
/// them.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onPathTap,
    required this.onGlossaryTap,
    required this.onStatsTap,
    required this.onProfileTap,
  });

  final AppTab current;
  final VoidCallback onPathTap;
  final VoidCallback onGlossaryTap;
  final VoidCallback onStatsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.surface,
      elevation: 8,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            _navItem(
              icon: Icons.route,
              // "Learning" on narrow web too, same reasoning as the
              // desktop sidebar — this row is shared with native, which
              // keeps "Path" exactly as it always was.
              label: kIsWeb ? 'Learning' : 'Path',
              selected: current == AppTab.path,
              onTap: onPathTap,
            ),
            _navItem(
              icon: Icons.menu_book_outlined,
              label: 'Glossary',
              selected: current == AppTab.glossary,
              onTap: onGlossaryTap,
            ),
            _navItem(
              icon: Icons.bar_chart_outlined,
              label: 'Stats',
              selected: current == AppTab.stats,
              onTap: onStatsTap,
            ),
            _navItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: current == AppTab.profile,
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppColors.teal : AppColors.inkSoft;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showComingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label — coming soon'),
      duration: const Duration(seconds: 1),
    ),
  );
}
