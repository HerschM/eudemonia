/// Splits [items] into time sessions, in chronological order.
///
/// Items are sorted ascending by [timeOf]. An item joins the current session
/// when it follows the previous item by at most [idleWindow] and starts less
/// than [maxSpan] after the session's first item; otherwise it opens a new one.
List<List<T>> splitIntoSessions<T>(
  Iterable<T> items, {
  required DateTime Function(T) timeOf,
  Duration idleWindow = const Duration(minutes: 45),
  Duration maxSpan = const Duration(hours: 2),
}) {
  final sorted = items.toList()..sort((a, b) => timeOf(a).compareTo(timeOf(b)));
  final sessions = <List<T>>[];
  DateTime? sessionStart;
  DateTime? previous;
  for (final item in sorted) {
    final time = timeOf(item);
    final joins = sessionStart != null &&
        time.difference(previous!) <= idleWindow &&
        time.difference(sessionStart) < maxSpan;
    if (joins) {
      sessions.last.add(item);
    } else {
      sessions.add([item]);
      sessionStart = time;
    }
    previous = time;
  }
  return sessions;
}
