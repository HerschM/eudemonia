import 'dart:io';

import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _transcript =
    'um so I was thinking we should uh move the queue worker into its own '
    'foreground service because like it keeps getting killed when the phone '
    'goes idle and you know that is basically breaking the whole background '
    'transcription thing so yeah remind me to look at that tomorrow';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LLM latency benchmark', timeout: Timeout.none, (tester) async {
    final dir = await getExternalStorageDirectory();
    final modelPath = '${dir!.path}/qwen2.5-1.5b.gguf';
    if (!File(modelPath).existsSync()) {
      fail('Model file not found at $modelPath. Push qwen2.5-1.5b.gguf there first.');
    }

    const timeout = Duration(seconds: 240);
    // CPU-only variants were measured on 2026-11-19 (1.2 chunks/s vs 7.3 with GPU offload on a
    // Pixel 7a) and dropped; see TASK-062 in TASKS.md for the full table.
    final variants = <String, LLMConfig>{
      'gpu99_greedy': const LLMConfig().copyWith(
          gpuLayers: 99,
          threads: 4,
          greedySampling: true,
          generationTimeout: timeout),
      'gpu99_sampled': const LLMConfig().copyWith(
          gpuLayers: 99,
          threads: 4,
          greedySampling: false,
          generationTimeout: timeout),
    };

    var completed = 0;
    for (final entry in variants.entries) {
      final service = LLMService(config: entry.value);
      try {
        final loadWatch = Stopwatch()..start();
        await service.initialize(modelPath);
        loadWatch.stop();

        await service.processText(_transcript);
        final m = service.lastTurnMetrics!;

        final cps = m.chunksPerSecond;
        // ignore: avoid_print
        print('LLM_BENCH2|${entry.key}|load_ms=${loadWatch.elapsedMilliseconds}'
            '|ttft_ms=${m.timeToFirstTokenMs ?? 'none'}'
            '|gen_ms=${m.generationMs ?? 'none'}|total_ms=${m.totalMs}'
            '|chunks=${m.outputChunks}'
            '|chunks_per_s=${cps == null ? 'none' : cps.toStringAsFixed(1)}'
            '|timed_out=${m.timedOut}|fallback=${m.usedFallback}'
            '|raw_chars=${m.rawOutput.length}');
        {
          final raw = m.rawOutput.length > 600
              ? m.rawOutput.substring(0, 600)
              : m.rawOutput;
          // ignore: avoid_print
          print('LLM_RAW|${raw.replaceAll('\n', '\\n')}');
        }
        completed++;
      } catch (e) {
        // ignore: avoid_print
        print('LLM_BENCH2|${entry.key}|ERROR $e');
      } finally {
        try {
          service.dispose();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 30));
      }
    }

    expect(completed, greaterThan(0), reason: 'No variant completed');
  });
}
