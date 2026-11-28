import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_segmenter.dart';

const int _rate = 16000;

int _s(double seconds) => (seconds * _rate).round();

/// Speech-like loudness everywhere: a 440 Hz tone, never quiet.
Float32List _tone(double seconds, {int rate = _rate}) {
  final n = (seconds * rate).round();
  final out = Float32List(n);
  for (int i = 0; i < n; i++) {
    out[i] = 0.5 * math.sin(2 * math.pi * 440 * i / rate);
  }
  return out;
}

/// Digital silence between [fromSeconds] and [toSeconds].
Float32List _withPause(Float32List samples, double fromSeconds, double toSeconds) {
  samples.fillRange(_s(fromSeconds), _s(toSeconds), 0);
  return samples;
}

void _expectCoversInOrder(List<AudioSegment> segments, int total) {
  expect(segments, isNotEmpty);
  expect(segments.first.start, 0);
  expect(segments.last.end, total);
  for (int i = 1; i < segments.length; i++) {
    expect(segments[i].start, segments[i - 1].end, reason: 'segments must be contiguous');
  }
  for (final segment in segments) {
    expect(segment.end, greaterThanOrEqualTo(segment.start));
  }
}

void main() {
  group('planSttSegments', () {
    test('an empty recording is one empty segment', () {
      expect(planSttSegments(Float32List(0), _rate), [const AudioSegment(0, 0)]);
    });

    test('a recording of 30 s is one segment covering it', () {
      final samples = _tone(30);
      expect(planSttSegments(samples, _rate), [AudioSegment(0, samples.length)]);
    });

    test('a recording of exactly 40 s is one segment covering it', () {
      final samples = Float32List(40 * _rate);
      expect(planSttSegments(samples, _rate), [AudioSegment(0, 40 * _rate)]);
    });

    test('one sample over 40 s is split in two, the last at least 10 s', () {
      final longer = _tone(40 + 1 / _rate);
      expect(longer.length, 40 * _rate + 1);
      final segments = planSttSegments(longer, _rate);

      expect(segments, hasLength(2));
      _expectCoversInOrder(segments, longer.length);
      expect(segments[0].end, greaterThanOrEqualTo(_s(25)));
      expect(longer.length - segments[0].end, greaterThanOrEqualTo(_s(10)));
    });

    test('the cut falls in the middle of the earliest quietest 300 ms of a pause', () {
      // A 500 ms pause at 32.0-32.5 s holds several all-silent 300 ms stretches; the
      // earliest one starts at 32.0 s, so the cut is at 32.15 s.
      final samples = _withPause(_tone(100), 32.0, 32.5);
      final segments = planSttSegments(samples, _rate);

      expect(segments.first, AudioSegment(0, _s(32.15)));
      _expectCoversInOrder(segments, samples.length);
    });

    test('without a pause the cut falls at the quietest point', () {
      // Loudness falls linearly to its lowest at 33.01 s and rises again; no silence.
      final n = 60 * _rate;
      final samples = Float32List(n);
      for (int i = 0; i < n; i++) {
        samples[i] = 0.05 + 0.02 * (i / _rate - 33.01).abs();
      }
      final segments = planSttSegments(samples, _rate);

      expect(segments.first, AudioSegment(0, _s(33.01)));
    });

    test('pauses before 25 s or after 40 s from the segment start are not used', () {
      final samples = _withPause(_withPause(_tone(100), 20.0, 21.0), 41.0, 42.0);
      final cut = planSttSegments(samples, _rate).first.end;

      expect(cut, greaterThanOrEqualTo(_s(25)));
      expect(cut, lessThanOrEqualTo(_s(40)));
    });

    test('each later cut is searched from the previous cut', () {
      // First cut in the pause at 30 s (30.15 s). The next window starts at 55.15 s and its
      // 20 ms frames are counted from there, so the first all-silent stretch of the pause at
      // 60.0-60.5 s starts at 60.01 s and the cut is at 60.16 s.
      final samples = _withPause(_withPause(_tone(120), 30.0, 30.3), 60.0, 60.5);
      final segments = planSttSegments(samples, _rate);

      expect(segments[0], AudioSegment(0, _s(30.15)));
      expect(segments[1], AudioSegment(_s(30.15), _s(60.16)));
      _expectCoversInOrder(segments, samples.length);
    });

    test('the search window ends 10 s before the end so the last segment is never shorter', () {
      // 45 s with a pause at 38 s: cutting there would leave 7 s, so the window ends at 35 s
      // and the pause is not used.
      final samples = _withPause(_tone(45), 38.0, 38.5);
      final segments = planSttSegments(samples, _rate);

      expect(segments, hasLength(2));
      expect(segments[0].end, lessThanOrEqualTo(_s(35)));
      expect(samples.length - segments[0].end, greaterThanOrEqualTo(_s(10)));
    });

    test('a pause inside the shortened window is still used', () {
      final samples = _withPause(_tone(45), 33.0, 33.3);
      expect(planSttSegments(samples, _rate).first, AudioSegment(0, _s(33.15)));
    });

    test('a five-minute recording: every segment 25-40 s, the last 10-40 s, all samples once', () {
      final samples = _tone(300);
      final segments = planSttSegments(samples, _rate);

      _expectCoversInOrder(segments, samples.length);
      for (final segment in segments.take(segments.length - 1)) {
        expect(segment.length, inInclusiveRange(_s(25), _s(40)));
      }
      expect(segments.last.length, inInclusiveRange(_s(10), _s(40)));
    });

    test('durations scale with the sample rate', () {
      final samples = _tone(41, rate: 8000);
      final segments = planSttSegments(samples, 8000);

      expect(segments, hasLength(2));
      expect(segments.last.end, samples.length);
      expect(samples.length - segments.first.end, greaterThanOrEqualTo(10 * 8000));
    });

    test('a non-positive sample rate is rejected', () {
      expect(() => planSttSegments(Float32List(10), 0), throwsArgumentError);
    });
  });
}
