import 'dart:io';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Synchronous speech recognition engine driven by the STT worker isolate.
///
/// Every method blocks the calling thread for the duration of native work, so
/// implementations must only ever be invoked from a background isolate.
abstract class SttEngine {
  /// Loads model weights from [modelDir] into RAM.
  void load(String modelDir);

  /// Transcribes the WAV file at [audioFilePath]. Returns an empty string when no speech is found.
  String transcribe(String audioFilePath);

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

/// Sherpa-ONNX Parakeet v3 transducer engine.
class SherpaSttEngine implements SttEngine {
  static const int targetSampleRate = 16000;

  /// 300ms of tail silence (4800 samples at 16kHz) so the transducer emits the final words.
  static const int tailPaddingSamples = 4800;

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

    _recognizer = OfflineRecognizer(config);
  }

  @override
  String transcribe(String audioFilePath) {
    final recognizer = _recognizer;
    if (recognizer == null) throw Exception('STT Service not initialized');

    if (!File(audioFilePath).existsSync()) {
      throw Exception('Audio recording not found at $audioFilePath');
    }

    final waveData = readWave(audioFilePath);
    if (waveData.samples.isEmpty) return '';

    Float32List samples = waveData.samples;
    if (waveData.sampleRate != targetSampleRate && waveData.sampleRate > 0) {
      samples = resampleLinear(samples, waveData.sampleRate, targetSampleRate);
    }

    final paddedSamples = Float32List(samples.length + tailPaddingSamples);
    paddedSamples.setRange(0, samples.length, samples);

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: paddedSamples, sampleRate: targetSampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text;
    } finally {
      stream.free();
    }
  }

  @override
  void dispose() {
    _recognizer?.free();
    _recognizer = null;
  }
}
