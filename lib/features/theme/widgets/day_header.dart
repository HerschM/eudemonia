import 'package:flutter/material.dart';
import 'package:eudemonia/core/formatting/thought_timestamp.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The label above a day's group of cards, shared by Capture and Synthesis: `TODAY — 26/11`,
/// `YESTERDAY — 25/11`, otherwise the date `23/11` (with the year, `23/11/2025`, when it is not
/// the current year). [date] null reads `UNDATED`. [now] is for tests.
String dayHeaderLabel(DateTime? date, {DateTime? now}) {
  if (date == null) return 'UNDATED';
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  final dayMonth = formatDayMonth(date);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'TODAY — $dayMonth';
  if (difference == 1) return 'YESTERDAY — $dayMonth';
  return date.year == current.year ? dayMonth : '$dayMonth/${date.year}';
}

/// Small spaced-out caption that opens a day group in a list. Pure presentational widget.
class DayHeader extends StatelessWidget {
  final String label;

  const DayHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
