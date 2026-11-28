import 'dart:math' as math;
import 'dart:typed_data';

/// A half-open range `[start, end)` of sample indexes in a recording.
class AudioSegment {
  final int start;
  final int end;

  const AudioSegment(this.start, this.end);

  int get length => end - start;

  @override
  bool operator ==(Object other) => other is AudioSegment && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'AudioSegment($start, $end)';
}

/// Why recordings are cut at all (measured 2026-11-27, sherpa-onnx 1.13.8, Parakeet):
/// decoding a whole recording in one call grows memory with its length. On the Mac peak
/// memory was 2.2 GB for clips up to 19 s, 3.9 GB at 128 s and 5.6 GB at 296 s; on a
/// Pixel 7a a 4 min 55 s recording took the app from 1.0 GB to 4.1 GB and the system
/// killed other apps. The single 5-minute call also lost its final 6 seconds of speech.
/// Recordings up to about 40 s were fine, so they stay one piece, exactly as before.
///
/// A recording of at most this many seconds is decoded whole.
const int sttMaxSegmentSeconds = 40;

/// A cut is never placed earlier than this after the segment's start, so segments stay long
/// enough to give the recogniser context.
const int sttMinCutSeconds = 25;

/// The last segment is never shorter than this, unless the whole recording is.
const int sttMinLastSegmentSeconds = 10;

/// Loudness is measured in frames of this length.
const int sttFrameMilliseconds = 20;

/// A cut goes in the middle of the quietest stretch of this length (15 frames).
const int sttQuietStretchMilliseconds = 300;

/// Plans where a recording is cut before speech recognition.
///
/// Returns consecutive segments that cover every sample exactly once, in order.
/// - A recording of at most [sttMaxSegmentSeconds] is one segment (the whole recording;
///   an empty recording is one empty segment).
/// - Otherwise, starting at the segment start `s`, the search window runs from
///   `s + sttMinCutSeconds` to `min(s + sttMaxSegmentSeconds, end - sttMinLastSegmentSeconds)`.
///   The window is split into 20 ms frames counted from its start; every run of 15
///   consecutive frames that fits in the window is a candidate, and the one with the lowest
///   energy (sum of squared samples, equivalent to lowest RMS) wins, the earliest on a tie.
///   The cut is placed in its middle, so a cut falls in a pause when there is one and at
///   the quietest point when there is none. The next segment starts at the cut.
/// - Last-segment rule: ending the search window [sttMinLastSegmentSeconds] before the end
///   of the recording means no cut can leave a shorter final segment, and since only
///   recordings longer than [sttMaxSegmentSeconds] are cut the window is always at least
///   5 s wide. Every segment is therefore at most [sttMaxSegmentSeconds] long.
///
/// Mirrored exactly (same sums, same order, same tie rule) by `plan_segments` in
/// `tool/stt_model_lab/compare_stt.py`; change both together.
List<AudioSegment> planSttSegments(Float32List samples, int sampleRate) {
  if (sampleRate <= 0) throw ArgumentError.value(sampleRate, 'sampleRate', 'must be positive');

  final total = samples.length;
  final maxSegment = sttMaxSegmentSeconds * sampleRate;
  final segments = <AudioSegment>[];
  int start = 0;
  while (total - start > maxSegment) {
    final cut = _quietestCut(
      samples,
      sampleRate,
      start + sttMinCutSeconds * sampleRate,
      math.min(start + maxSegment, total - sttMinLastSegmentSeconds * sampleRate),
    );
    segments.add(AudioSegment(start, cut));
    start = cut;
  }
  segments.add(AudioSegment(start, total));
  return segments;
}

/// The middle of the lowest-energy stretch of frames that fits in `[windowStart, windowEnd)`.
int _quietestCut(Float32List samples, int sampleRate, int windowStart, int windowEnd) {
  final frame = sampleRate * sttFrameMilliseconds ~/ 1000;
  const framesPerStretch = sttQuietStretchMilliseconds ~/ sttFrameMilliseconds;
  final frameCount = (windowEnd - windowStart) ~/ frame;

  final energies = List<double>.filled(frameCount, 0);
  for (int f = 0; f < frameCount; f++) {
    final from = windowStart + f * frame;
    double sum = 0;
    for (int i = from; i < from + frame; i++) {
      final x = samples[i];
      sum += x * x;
    }
    energies[f] = sum;
  }

  int best = 0;
  double bestEnergy = double.infinity;
  for (int j = 0; j + framesPerStretch <= frameCount; j++) {
    double sum = 0;
    for (int f = j; f < j + framesPerStretch; f++) {
      sum += energies[f];
    }
    if (sum < bestEnergy) {
      bestEnergy = sum;
      best = j;
    }
  }
  return windowStart + best * frame + framesPerStretch * frame ~/ 2;
}
