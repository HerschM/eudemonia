import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eudemonia/features/ai_processing/model_file_validator.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/settings/system_telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/text_eval.dart' show wordErrorRate;

const _hardTags = {'noise', 'whisper', 'fast', 'far', 'pocket'};

/// Audio length from the WAV header: data chunk bytes / (16000 Hz * 2 bytes).
double _audioSeconds(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final available = bytes.length - (offset + 8);
      return (size > available ? available : size) / (16000 * 2);
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  return (bytes.length - 44) / (16000 * 2);
}

double? _mean(Iterable<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Voice pipeline evaluation (speech recognition, timing, memory)',
      timeout: Timeout.none, (tester) async {
    final dir = (await getExternalStorageDirectory())!;
    final samplesDir = '${dir.path}/voice_samples';
    final manifestFile = File('$samplesDir/manifest.json');
    if (!manifestFile.existsSync()) {
      fail('Manifest not found at ${manifestFile.path}. Run tool/push_voice_samples.sh first.');
    }
    final manifest =
        (jsonDecode(await manifestFile.readAsString()) as List).cast<Map<String, dynamic>>();

    final files = ModelFiles(
      sttModelDir: '${dir.path}/parakeet',
    );
    await const ModelFileValidator().validate(files);

    const telemetry = SystemTelemetryService();
    var memPeak = 0.0;
    Future<double?> memMb() async {
      final bytes = (await telemetry.read())?.appMemoryBytes;
      if (bytes == null) return null;
      final mb = bytes / (1024 * 1024);
      if (mb > memPeak) memPeak = mb;
      return mb;
    }

    final memStart = await memMb();

    final stt = STTService();
    await stt.initialize(files.sttModelDir);
    final memAfterStt = await memMb();

    final results = <Map<String, dynamic>>[];
    try {
      for (final entry in manifest) {
        final id = entry['id'] as String;
        final file = entry['file'] as String;
        final reference = entry['reference'] as String?;
        final expectSpeech = entry['expectSpeech'] as bool? ?? true;
        final tags = (entry['tags'] as List).cast<String>();

        final result = <String, dynamic>{
          'id': id,
          'file': file,
          'tags': tags,
          'status': 'ok',
          'stt_ms': null,
          'audio_seconds': null,
          'stt_text': null,
          'wer': null,
        };
        results.add(result);

        final wav = File('$samplesDir/$file');
        if (!wav.existsSync()) {
          result['status'] = 'missing_file';
          // ignore: avoid_print
          print('EVAL|${jsonEncode(result)}');
          continue;
        }

        try {
          result['audio_seconds'] = _audioSeconds(await wav.readAsBytes());

          final sttWatch = Stopwatch()..start();
          final sttText = (await stt.transcribe(wav.path)).trim();
          sttWatch.stop();
          result['stt_ms'] = sttWatch.elapsedMilliseconds;
          result['stt_text'] = sttText;
          if (reference != null) result['wer'] = wordErrorRate(reference, sttText);

          if (!expectSpeech) {
            if (sttText.isNotEmpty) result['status'] = 'unexpected_speech';
          } else if (sttText.isEmpty) {
            result['status'] = 'empty_transcript';
          } else {
          }
        } catch (e) {
          result['status'] = 'error: $e';
        }
        await memMb();
        // ignore: avoid_print
        print('EVAL|${jsonEncode(result)}');
      }
    } finally {
      stt.dispose();
    }

    await Future.delayed(const Duration(seconds: 5));
    final memAfterDispose = await memMb();

    final run = results.where((r) => r['status'] != 'missing_file').toList();
    bool isHard(Map<String, dynamic> r) =>
        (r['tags'] as List).any((t) => _hardTags.contains(t));
    Iterable<double> wers(bool hard) => run
        .where((r) => r['wer'] != null && isHard(r) == hard)
        .map((r) => (r['wer'] as num).toDouble());
    double? round1(double? v) => v == null ? null : double.parse(v.toStringAsFixed(1));
    final summary = <String, dynamic>{
      'samples_run': run.length,
      'samples_missing': results.length - run.length,
      'mean_wer_quiet': _mean(wers(false)),
      'mean_wer_hard': _mean(wers(true)),
      'mem_start_mb': round1(memStart),
      'mem_after_stt_mb': round1(memAfterStt),
      'mem_peak_mb': round1(memPeak),
      'mem_after_dispose_mb': round1(memAfterDispose),
    };

    // ignore: avoid_print
    print('EVAL_SUMMARY|${jsonEncode(summary)}');
    await File('${dir.path}/voice_eval_results.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'samples': results, 'summary': summary}));

    expect(run, isNotEmpty, reason: 'No sample WAV files found under $samplesDir');
  });
}
