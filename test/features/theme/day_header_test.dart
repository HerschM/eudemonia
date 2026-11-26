import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/theme/widgets/day_header.dart';

void main() {
  final now = DateTime(2026, 11, 26, 14, 30);

  test('today, yesterday and older days read like Capture and Synthesis both show them', () {
    expect(dayHeaderLabel(DateTime(2026, 11, 26, 0, 5), now: now), 'TODAY — 26/11');
    expect(dayHeaderLabel(DateTime(2026, 11, 25, 23, 59), now: now), 'YESTERDAY — 25/11');
    expect(dayHeaderLabel(DateTime(2026, 11, 23, 9), now: now), '23/11');
  });

  test('a day of another year carries the year; a missing date is UNDATED', () {
    expect(dayHeaderLabel(DateTime(2025, 12, 31, 9), now: now), '31/12/2025');
    expect(dayHeaderLabel(null, now: now), 'UNDATED');
  });
}
