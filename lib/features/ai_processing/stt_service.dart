import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class STTService {
  OfflineRecognizer? _recognizer;
  bool _isInitialized = false;

  Future<void> initialize(String modelDir) async {
    if (_isInitialized) return;

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
  }

  Future<String> transcribe(String audioFilePath) async {
    if (!_isInitialized || _recognizer == null) throw Exception('STT Service not initialized');

    final waveData = readWave(audioFilePath);
    final stream = _recognizer!.createStream();

    stream.acceptWaveform(
      samples: waveData.samples,
      sampleRate: waveData.sampleRate,
    );

    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);

    stream.free();
    return result.text;
  }

  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
  }
}

final sttServiceProvider = Provider<STTService>((ref) {
  return STTService();
});
