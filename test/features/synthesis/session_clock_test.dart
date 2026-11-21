import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/synthesis/domain/session_clock.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 9, 0);
  List<List<DateTime>> split(List<DateTime> times) =>
      splitIntoSessions<DateTime>(times, timeOf: (t) => t);

  test('empty input gives no sessions', () {
    expect(split([]), isEmpty);
  });

  test('a single item is one session', () {
    expect(split([t0]), [
      [t0]
    ]);
  });

  test('a gap of exactly 45 minutes stays in the session', () {
    final b = t0.add(const Duration(minutes: 45));
    expect(split([t0, b]), [
      [t0, b]
    ]);
  });

  test('a gap of 45 minutes and one second starts a new session', () {
    final b = t0.add(const Duration(minutes: 45, seconds: 1));
    expect(split([t0, b]), [
      [t0],
      [b]
    ]);
  });

  test('items every 30 minutes: the item at exactly first + 2h starts a new session', () {
    final times = [for (var i = 0; i <= 5; i++) t0.add(Duration(minutes: 30 * i))];
    final sessions = split(times);
    expect(sessions.length, 2);
    expect(sessions[0], times.sublist(0, 4));
    expect(sessions[1], times.sublist(4));
    expect(sessions[1].first, t0.add(const Duration(hours: 2)));
  });

  test('unsorted input is sorted', () {
    final b = t0.add(const Duration(minutes: 10));
    final c = t0.add(const Duration(hours: 5));
    expect(split([c, b, t0]), [
      [t0, b],
      [c]
    ]);
  });

  test('three separate sessions across a day', () {
    final morning = t0;
    final noon = t0.add(const Duration(hours: 4));
    final evening = t0.add(const Duration(hours: 10));
    final sessions = split([morning, noon, evening]);
    expect(sessions.length, 3);
  });
}
