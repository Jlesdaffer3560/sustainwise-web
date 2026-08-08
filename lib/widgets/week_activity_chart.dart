import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single day's activity level, 0.0-1.0. Matches `.week-col` in the mockup —
/// bar and label are always paired in one model so they can never drift out
/// of sync (that was a real bug in the HTML prototype's first draft).
class DayActivity {
  const DayActivity(this.label, this.level, {this.isToday = false});

  final String label; // e.g. "Mo"
  final double level; // 0.0-1.0
  final bool isToday;
}

class WeekActivityChart extends StatelessWidget {
  const WeekActivityChart({super.key, required this.days, this.trackHeight = 36});

  final List<DayActivity> days;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: trackHeight,
                    constraints: const BoxConstraints(maxWidth: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: day.level.clamp(0, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: day.isToday ? AppColors.amber : AppColors.teal,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    day.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w400,
                      color: day.isToday ? AppColors.amber : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
