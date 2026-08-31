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

const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// Builds this week's real [DayActivity] list from actual per-day XP —
/// shared by Stats and Profile so their two "This week" charts read from
/// one place instead of each keeping (and risking drifting from) its own
/// copy. [xpPerDay] and [todayIndex] come straight from
/// [ProgressStore.thisWeekXp]/[ProgressStore.todayWeekdayIndex]; a day is
/// "full" once it hits [goalXp] (the daily goal), same reference point as
/// the Home daily-goal ring.
List<DayActivity> buildWeekActivity({
  required List<int> xpPerDay,
  required int todayIndex,
  required int goalXp,
}) {
  assert(xpPerDay.length == 7);
  return [
    for (var i = 0; i < 7; i++)
      DayActivity(
        _weekdayLabels[i],
        (xpPerDay[i] / goalXp).clamp(0.0, 1.0),
        isToday: i == todayIndex,
      ),
  ];
}

class WeekActivityChart extends StatelessWidget {
  const WeekActivityChart({
    super.key,
    required this.days,
    this.trackHeight = 36,
  });

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
                      fontWeight: day.isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: day.isToday
                          ? AppColors.amberDeep
                          : AppColors.inkSoft,
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
