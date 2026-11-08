import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

class STTService {
  final AppLogger? _logger;
  OfflineRecognizer? _recognizer;
  bool _isInitialized = false;

  STTService({this._logger});

  bool get isInitialized => _isInitialized;

  Future<void> initialize(String modelDir) async {
    if (_isInitialized) return;

    _logger?.info('[STTService] Initializing Parakeet v3 STT model from $modelDir...');

    try {
      initBindings();
    } catch (_) {}

    final encoderPath = '$modelDir/encoder.int8.onnx';
    final decoderPath = '$modelDir/decoder.int8.onnx';
    final joinerPath = '$modelDir/joiner.int8.onnx';
    final tokensPath = '$modelDir/tokens.txt';

    if (!await File(encoderPath).exists()) {
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
    _isInitialized = true;
    _logger?.info('[STTService] Parakeet v3 STT model loaded successfully.');
  }

  Float32List _resample(Float32List input, int fromRate, int toRate) {
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

  Future<String> transcribe(String audioFilePath) async {
    if (!_isInitialized || _recognizer == null) throw Exception('STT Service not initialized');

    final waveData = readWave(audioFilePath);
    if (waveData.samples.isEmpty) {
      _logger?.warning('[STTService] Empty audio samples in file: $audioFilePath');
      return '';
    }

    // Ensure 16000Hz sample rate for Parakeet transducer
    Float32List samples = waveData.samples;
    int targetSampleRate = 16000;
    if (waveData.sampleRate != targetSampleRate && waveData.sampleRate > 0) {
      _logger?.info('[STTService] Resampling audio from ${waveData.sampleRate}Hz to ${targetSampleRate}Hz');
      samples = _resample(samples, waveData.sampleRate, targetSampleRate);
    }

    // Append 300ms tail silence padding (4800 samples at 16kHz) to ensure transducer emission without word cut-off
    const tailPaddingSamples = 4800;
    final paddedSamples = Float32List(samples.length + tailPaddingSamples);
    paddedSamples.setRange(0, samples.length, samples);

    final stream = _recognizer!.createStream();

    try {
      stream.acceptWaveform(
        samples: paddedSamples,
        sampleRate: targetSampleRate,
      );

      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      return result.text;
    } finally {
      stream.free();
    }
  }

  void dispose() {
    _logger?.info('[STTService] Disposing Parakeet v3 STT model...');
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
    _logger?.info('[STTService] Parakeet v3 STT model disposed.');
  }
}

final sttServiceProvider = Provider<STTService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return STTService(logger: logger);
});
