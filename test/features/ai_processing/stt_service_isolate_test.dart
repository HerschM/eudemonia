import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';

/// Contract-enforcing engine double: refuses work before load or after dispose.
class _FakeEngine implements SttEngine {
  bool _loaded = false;

  @override
  void load(String modelDir) {
    if (modelDir.contains('missing')) {
      throw Exception('Parakeet model files not found in $modelDir');
    }
    _loaded = true;
  }

  @override
  String transcribe(String audioFilePath) {
    if (!_loaded) throw StateError('engine used before load or after dispose');
    if (audioFilePath.contains('slow')) {
      // Blocks this isolate exactly like a native decode call would.
      sleep(const Duration(milliseconds: 400));
    }
    if (audioFilePath.contains('silent')) return '';
    if (audioFilePath.contains('broken')) throw Exception('Audio recording not found at $audioFilePath');
    return 'transcript of $audioFilePath';
  }

  @override
  void dispose() {
    _loaded = false;
  }
}

SttEngine _createFakeEngine() => _FakeEngine();

void main() {
  group('STTService worker isolate', () {
    late STTService service;

    setUp(() {
      service = STTService(engineFactory: _createFakeEngine);
    });

    tearDown(() {
      service.dispose();
    });

    test('transcribe before initialize throws and reports uninitialized', () async {
      expect(service.isInitialized, isFalse);
      await expectLater(service.transcribe('/a.wav'), throwsException);
    });

    test('initialize loads the engine and transcribe returns its text', () async {
      await service.initialize('/models/parakeet');
      expect(service.isInitialized, isTrue);
      expect(await service.transcribe('/a.wav'), 'transcript of /a.wav');
      expect(await service.transcribe('/silent.wav'), isEmpty);
    });

    test('load failure propagates and leaves the service uninitialized', () async {
      await expectLater(
        service.initialize('/missing/parakeet'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('model files not found'))),
      );
      expect(service.isInitialized, isFalse);

      // A later load with a valid directory still succeeds.
      await service.initialize('/models/parakeet');
      expect(service.isInitialized, isTrue);
    });

    test('engine failure fails only that request', () async {
      await service.initialize('/models/parakeet');
      await expectLater(service.transcribe('/broken.wav'), throwsException);
      expect(await service.transcribe('/b.wav'), 'transcript of /b.wav');
    });

    test('decoding does not block the calling isolate', () async {
      await service.initialize('/models/parakeet');

      int ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 20), (_) => ticks++);
      final text = await service.transcribe('/slow.wav');
      timer.cancel();

      expect(text, 'transcript of /slow.wav');
      // A 400ms decode on this isolate would starve the timer completely.
      expect(ticks, greaterThanOrEqualTo(5));
    });

    test('dispose during an in-flight transcription lets it finish, then reinitialize works', () async {
      await service.initialize('/models/parakeet');

      final inFlight = service.transcribe('/slow.wav');
      service.dispose();
      expect(service.isInitialized, isFalse);

      expect(await inFlight, 'transcript of /slow.wav');
      await expectLater(service.transcribe('/a.wav'), throwsException);

      await service.initialize('/models/parakeet');
      expect(await service.transcribe('/a.wav'), 'transcript of /a.wav');
    });
  });

  group('resampleLinear', () {
    test('returns input untouched when rates match', () {
      final input = Float32List.fromList([0.1, 0.2, 0.3]);
      expect(identical(resampleLinear(input, 16000, 16000), input), isTrue);
    });

    test('48kHz audio is reduced to a third of the samples at 16kHz', () {
      final input = Float32List(4800);
      expect(resampleLinear(input, 48000, 16000).length, 1600);
    });
  });
}
