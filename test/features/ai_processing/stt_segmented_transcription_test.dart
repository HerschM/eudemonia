import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_segmenter.dart';
import 'package:eudemonia/features/ai_processing/stt_engine.dart';

/// Records every waveform handed to the recogniser and answers with scripted texts.
class _ScriptedDecoder {
  final List<String> _texts;
  final List<Float32List> inputs = [];

  _ScriptedDecoder(this._texts);

  String call(Float32List padded) {
    if (inputs.length >= _texts.length) throw StateError('decoded more segments than planned');
    inputs.add(Float32List.fromList(padded));
    return _texts[inputs.length - 1];
  }
}

Float32List _ramp(int n) => Float32List.fromList([for (int i = 0; i < n; i++) (i + 1) / n]);

Float32List _padded(Float32List samples, int start, int end) {
  return Float32List(end - start + SherpaSttEngine.tailPaddingSamples)..setRange(0, end - start, samples, start);
}

void main() {
  group('transcribeInSegments', () {
    test('one segment sends the whole recording plus today\'s tail padding and returns the text unchanged', () {
      final samples = _ramp(1000);
      final decoder = _ScriptedDecoder([' Hello there.']);

      final text = transcribeInSegments(samples, [AudioSegment(0, samples.length)], decoder.call);

      expect(text, ' Hello there.');
      expect(decoder.inputs, hasLength(1));
      expect(decoder.inputs.single, _padded(samples, 0, samples.length));
      expect(decoder.inputs.single.length, samples.length + 4800);
    });

    test('several segments are decoded in order, each padded, and joined with one space', () {
      final samples = _ramp(900);
      final segments = [const AudioSegment(0, 300), const AudioSegment(300, 700), const AudioSegment(700, 900)];
      final decoder = _ScriptedDecoder(['First part.', ' second part ', 'third.']);

      final text = transcribeInSegments(samples, segments, decoder.call);

      expect(text, 'First part. second part third.');
      expect(decoder.inputs, [
        _padded(samples, 0, 300),
        _padded(samples, 300, 700),
        _padded(samples, 700, 900),
      ]);
    });

    test('a silent segment contributes nothing', () {
      final samples = _ramp(900);
      final segments = [const AudioSegment(0, 300), const AudioSegment(300, 600), const AudioSegment(600, 900)];

      expect(transcribeInSegments(samples, segments, _ScriptedDecoder(['One.', '  ', 'Two.']).call), 'One. Two.');
      expect(transcribeInSegments(samples, segments, _ScriptedDecoder(['', '', '']).call), isEmpty);
    });

    test('a decoding failure propagates', () {
      final samples = _ramp(600);
      final segments = [const AudioSegment(0, 300), const AudioSegment(300, 600)];

      expect(
        () => transcribeInSegments(samples, segments, (_) => throw Exception('decode failed')),
        throwsException,
      );
    });
  });
}
