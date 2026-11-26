/// Daily session numbers: like Capture's `#NN`, a session is identified by its day and its
/// `#S-NN` number, and the counter restarts every calendar day. Pure Dart.
library;

import 'package:eudemonia/core/formatting/thought_timestamp.dart';

import 'synthesis_cluster.dart';

/// `#S-NN` for [number], e.g. `#S-02`.
String formatSessionLabel(int number) => '#S-${number.toString().padLeft(2, '0')}';

/// Numeric part of a `#S-NN` label, or 0 when it cannot be parsed.
int sessionLabelNumber(String label) => int.tryParse(label.replaceFirst('#S-', '')) ?? 0;

DateTime calendarDayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// The number a new session starting at [start] gets: the highest number among [sessions] of
/// that day + 1. Gaps are allowed, as in Capture: a deleted session's number comes back only
/// when no higher number of that day exists.
int nextSessionNumber(Iterable<SynthesisCluster> sessions, DateTime start) {
  final day = calendarDayOf(start);
  var highest = 0;
  for (final s in sessions) {
    if (s.sessionDay != day) continue;
    final n = sessionLabelNumber(s.sequenceNumber);
    if (n > highest) highest = n;
  }
  return highest + 1;
}

/// Numbers [sessions] 1, 2, … per day in order of their start, keeping the list order. Used once
/// to move sessions numbered globally (before daily numbers) to daily numbers; idempotent.
List<SynthesisCluster> renumberSessionsByDay(List<SynthesisCluster> sessions) {
  final byDay = <DateTime, List<SynthesisCluster>>{};
  for (final s in sessions) {
    byDay.putIfAbsent(s.sessionDay, () => []).add(s);
  }
  final labels = <String, String>{};
  for (final day in byDay.values) {
    day.sort((a, b) {
      final byStart = a.sessionStart.compareTo(b.sessionStart);
      return byStart != 0
          ? byStart
          : sessionLabelNumber(a.sequenceNumber).compareTo(sessionLabelNumber(b.sequenceNumber));
    });
    for (var i = 0; i < day.length; i++) {
      labels[day[i].clusterId] = formatSessionLabel(i + 1);
    }
  }
  return [
    for (final s in sessions)
      labels[s.clusterId] == s.sequenceNumber ? s : s.copyWith(sequenceNumber: labels[s.clusterId]),
  ];
}

/// How a thought refers to the session that consumed it: `#S-02` when the session is from the
/// day of [relativeTo] (the thought's capture time), else `#S-02 · 23/11`.
String sessionReferenceLabel(SynthesisCluster session, {required DateTime relativeTo}) =>
    session.sessionDay == calendarDayOf(relativeTo)
        ? session.sequenceNumber
        : '${session.sequenceNumber} · ${formatDayMonth(session.sessionDay)}';
