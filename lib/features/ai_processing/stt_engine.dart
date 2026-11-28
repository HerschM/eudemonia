import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'audio_segmenter.dart';
import 'native/native_release.dart';

/// The result of one transcription, plus what the service logs about long recordings.
class SttTranscript {
  /// The recognised text; empty when no speech is found.
  final String text;

  /// Length of the recording.
  final Duration audioDuration;

  /// Number of pieces the recording was decoded in (1 for recordings of at most 40 s).
  final int segmentCount;

  /// Time spent reading, planning and decoding the recording.
  final Duration elapsed;

  const SttTranscript({
    required this.text,
    required this.audioDuration,
    this.segmentCount = 1,
    this.elapsed = Duration.zero,
  });
}

/// Synchronous speech recognition engine driven by the STT worker isolate.
///
/// Every method blocks the calling thread for the duration of native work, so
/// implementations must only ever be invoked from a background isolate.
abstract class SttEngine {
  /// Loads model weights from [modelDir] into RAM.
  void load(String modelDir);

  /// Transcribes the WAV file at [audioFilePath]. The text is empty when no speech is found.
  SttTranscript transcribe(String audioFilePath);

  /// Releases all native handles.
  void dispose();
}

/// Builds the engine inside the worker isolate. Must be a top-level or static
/// function so it can be sent across the isolate boundary.
typedef SttEngineFactory = SttEngine Function();

SttEngine createSherpaSttEngine() => SherpaSttEngine();

/// Linear resampler guaranteeing the sample rate expected by the recognizer.
Float32List resampleLinear(Float32List input, int fromRate, int toRate) {
  if (fromRate == toRate || input.isEmpty || fromRate <= 0 || toRate <= 0) return input;
  final ratio = fromRate / toRate;
  final outLength = (input.length / ratio).round();
  final output = Float32List(outLength);
  for (int i = 0; i < outLength; i++) {
    final position = i * ratio;
    final index = position.floor();
    final fraction = position - index;
    if (index + 1 < input.length) {
      output[i] = input[index] * (1.0 - fraction) + input[index + 1] * fraction;
    } else if (index < input.length) {
      output[i] = input[index];
    }
  }
  return output;
}

/// Decodes [segments] of [samples] one after another through [decodeSegment], which gets
/// each segment's samples followed by [SherpaSttEngine.tailPaddingSamples] of silence.
///
/// A single segment's text is returned unchanged, so a recording that is not cut gives
/// exactly the text it gave before segmenting existed. With several segments each text is
/// trimmed, silent segments contribute nothing, and the rest are joined with one space.
String transcribeInSegments(
  Float32List samples,
  List<AudioSegment> segments,
  String Function(Float32List paddedSamples) decodeSegment,
) {
  if (segments.length == 1) {
    final only = segments.single;
    return decodeSegment(_withTailPadding(samples, only.start, only.end));
  }
  final texts = <String>[];
  for (final segment in segments) {
    final text = decodeSegment(_withTailPadding(samples, segment.start, segment.end)).trim();
    if (text.isNotEmpty) texts.add(text);
  }
  return texts.join(' ');
}

Float32List _withTailPadding(Float32List samples, int start, int end) {
  final padded = Float32List(end - start + SherpaSttEngine.tailPaddingSamples);
  padded.setRange(0, end - start, samples, start);
  return padded;
}

/// Sherpa-ONNX Parakeet transducer engine.
///
/// The recognizer (about 750 MB of native memory on the phone) is also freed when the worker
/// isolate shuts down without [dispose], as when the Flutter engine is destroyed or the isolate
/// is killed. A stream lives within one [transcribe] call and is freed before it returns.
class SherpaSttEngine implements SttEngine, Finalizable {
  static const int targetSampleRate = 16000;

  /// 300ms of tail silence (4800 samples at 16kHz) so the transducer emits the final words.
  static const int tailPaddingSamples = 4800;

  /// Created in each isolate's first [load], after the bindings are initialised.
  static NativeRelease? _release;

  OfflineRecognizer? _recognizer;

  @override
  void load(String modelDir) {
    // Each isolate has its own FFI binding state.
    initBindings();

    final encoderPath = '$modelDir/encoder.int8.onnx';
    final decoderPath = '$modelDir/decoder.int8.onnx';
    final joinerPath = '$modelDir/joiner.int8.onnx';
    final tokensPath = '$modelDir/tokens.txt';

    if (!File(encoderPath).existsSync()) {
      throw Exception('Parakeet model files not found in $modelDir');
    }

    final config = OfflineRecognizerConfig(
      model: OfflineModelConfig(
        transducer: OfflineTransducerModelConfig(
          encoder: encoderPath,
          decoder: decoderPath,
          joiner: joinerPath,
        ),
        tokens: tokensPath,
        modelType: 'nemo_transducer',
        numThreads: 4,
        debug: false,
      ),
    );

    final release = _release ??= NativeRelease(
        _openSherpaLibrary().lookup<NativeFinalizerFunction>('SherpaOnnxDestroyOfflineRecognizer'));
    final recognizer = OfflineRecognizer(config);
    release.attach(this, recognizer.ptr);
    _recognizer = recognizer;
  }

  /// Opens the library sherpa_onnx's `initBindings()` opens when given no path (sherpa_onnx
  /// 1.13.8, lib/src/init_native.dart `loadDylib`); the same loaded library, so the same
  /// destroy function the package calls.
  static DynamicLibrary _openSherpaLibrary() {
    final path = resolveSherpaOnnxPathSync();
    if (Platform.isMacOS) {
      return path == null
          ? DynamicLibrary.process()
          : DynamicLibrary.open(
              '$path/sherpa_onnx_macos/sherpa-onnx.xcframework/macos-arm64_x86_64/libsherpa-onnx-c-api.dylib');
    }
    if (Platform.isIOS) return DynamicLibrary.process();
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open(path == null ? 'libsherpa-onnx-c-api.so' : '$path/libsherpa-onnx-c-api.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open(path == null ? 'sherpa-onnx-c-api.dll' : '$path\\sherpa-onnx-c-api.dll');
    }
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }

  @override
  SttTranscript transcribe(String audioFilePath) {
    final recognizer = _recognizer;
    if (recognizer == null) throw Exception('STT Service not initialized');

    if (!File(audioFilePath).existsSync()) {
      throw Exception('Audio recording not found at $audioFilePath');
    }

    final stopwatch = Stopwatch()..start();
    final waveData = readWave(audioFilePath);
    if (waveData.samples.isEmpty) return const SttTranscript(text: '', audioDuration: Duration.zero);

    Float32List samples = waveData.samples;
    if (waveData.sampleRate != targetSampleRate && waveData.sampleRate > 0) {
      samples = resampleLinear(samples, waveData.sampleRate, targetSampleRate);
    }

    // Long recordings are decoded in pieces so memory stays flat (see audio_segmenter.dart).
    final segments = planSttSegments(samples, targetSampleRate);
    final text = transcribeInSegments(samples, segments, (paddedSamples) {
      // One stream per segment, freed before the next one is created.
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(samples: paddedSamples, sampleRate: targetSampleRate);
        recognizer.decode(stream);
        return recognizer.getResult(stream).text;
      } finally {
        stream.free();
      }
    });

    return SttTranscript(
      text: text,
      audioDuration: Duration(microseconds: samples.length * Duration.microsecondsPerSecond ~/ targetSampleRate),
      segmentCount: segments.length,
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  void dispose() {
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer == null) return;
    // Detached first, so the isolate shutdown never frees it again.
    _release!.release(this, recognizer.free);
  }
}
