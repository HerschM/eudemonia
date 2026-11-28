import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/core/formatting/recording_timer.dart';

void main() {
  group('formatRecordingTimer', () {
    test('elapsed time reads mm:ss, as the capsule always showed it', () {
      expect(formatRecordingTimer(Duration.zero), '00:00');
      expect(formatRecordingTimer(const Duration(seconds: 65, milliseconds: 200)), '01:05');
      expect(formatRecordingTimer(const Duration(minutes: 12, seconds: 3)), '12:03');
    });

    test('with a limit it reads elapsed / limit', () {
      expect(formatRecordingTimer(const Duration(seconds: 90), const Duration(minutes: 5)), '01:30 / 05:00');
      expect(formatRecordingTimer(Duration.zero, const Duration(minutes: 10)), '00:00 / 10:00');
    });

    test('a negative elapsed time (clock moved back) reads as zero', () {
      expect(formatRecordingTimer(const Duration(seconds: -4)), '00:00');
    });
  });
}
