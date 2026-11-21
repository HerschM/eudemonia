import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';

void main() {
  Map<String, dynamic> json(String status) => {
        'id': 'a',
        'audioFilePath': '/a.m4a',
        'recordedAt': DateTime(2026, 11, 5).toIso8601String(),
        'status': status,
      };

  test('an unknown stored status loads as pending instead of throwing', () {
    expect(AudioQueueItem.fromJson(json('categorizing')).status, AudioQueueStatus.pending);
    expect(AudioQueueItem.fromJson(json('nonsense')).status, AudioQueueStatus.pending);
  });

  test('known statuses round-trip', () {
    for (final s in AudioQueueStatus.values) {
      expect(AudioQueueItem.fromJson(json(s.name)).status, s);
    }
  });
}
