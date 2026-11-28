/// The recording timer text: elapsed time as `mm:ss`, followed by ` / mm:ss` of [max] when a
/// recording has a length limit (`01:30 / 05:00`).
String formatRecordingTimer(Duration elapsed, [Duration? max]) =>
    max == null ? _minutesSeconds(elapsed) : '${_minutesSeconds(elapsed)} / ${_minutesSeconds(max)}';

String _minutesSeconds(Duration d) {
  final seconds = d.isNegative ? 0 : d.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
