import 'dart:convert';
import 'dart:io';

import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/settings/system_telemetry_service.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_prompts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// Overridable with --dart-define so another model or context size can be measured.
const _modelFile = String.fromEnvironment('SYN_MODEL', defaultValue: 'qwen2.5-1.5b.gguf');
const _ctxList = String.fromEnvironment('SYN_CTX', defaultValue: '2048,4096,8192');
// Qwen3 models think before answering unless an empty think block follows the assistant header.
const _emptyThink = bool.fromEnvironment('SYN_EMPTY_THINK');
// SYN_THREADS sets the CPU thread count; SYN_SKIP_ALL=true leaves out the two turns that take every thought at once.
const _threads = int.fromEnvironment('SYN_THREADS', defaultValue: 4);
const _skipAll = bool.fromEnvironment('SYN_SKIP_ALL');
final _contextSizes = _ctxList.split(',').map(int.parse).toList();
// SYN_TEMPLATE=llama3 builds the prompts in the Llama 3 chat format instead of ChatML.
const _template = String.fromEnvironment('SYN_TEMPLATE', defaultValue: 'chatml');
const _format = _template == 'llama3' ? ChatFormat.llama3 : ChatFormat.chatml;
String _p(String prompt) => _emptyThink && _format == ChatFormat.chatml ? '$prompt<think>\n\n</think>\n\n' : prompt;

int _words(Iterable<String> texts) =>
    texts.fold(0, (n, t) => n + t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Synthesis LLM evaluation (organise, write, structured across context sizes)',
      timeout: const Timeout(Duration(minutes: 120)), (tester) async {
    final dir = (await getExternalStorageDirectory())!;
    final thoughtsFile = File('${dir.path}/synthesis_eval/thoughts.json');
    if (!thoughtsFile.existsSync()) {
      fail('Thoughts not found at ${thoughtsFile.path}. Push a JSON list of {"id","text"} there first.');
    }
    final thoughts = (jsonDecode(await thoughtsFile.readAsString()) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => MapEntry(e['id'] as String, e['text'] as String))
        .toList();
    final byId = {for (final t in thoughts) t.key: t.value};
    List<String> pick(List<String> ids) {
      for (final id in ids) {
        if (!byId.containsKey(id)) fail('thoughts.json has no thought with id $id');
      }
      return [for (final id in ids) byId[id]!];
    }

    final modelPath = '${dir.path}/$_modelFile';
    const telemetry = SystemTelemetryService();
    Future<double?> memMb() async {
      final bytes = (await telemetry.read())?.appMemoryBytes;
      return bytes == null ? null : double.parse((bytes / (1024 * 1024)).toStringAsFixed(1));
    }

    final resultsFile = File('${dir.path}/synthesis_llm_eval_results.json');
    if (resultsFile.existsSync()) resultsFile.deleteSync();
    final loads = <Map<String, dynamic>>[];
    final turns = <Map<String, dynamic>>[];
    Future<void> save() => resultsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({'loads': loads, 'turns': turns}));

    final allIds = thoughts.map((t) => t.key).toList();
    final allThoughts = thoughts.map((t) => t.value).toList();

    for (final ctx in _contextSizes) {
      final service = LLMService(
          config: LLMConfig(kvCacheMaxSize: ctx, threads: _threads, generationTimeout: const Duration(minutes: 10)));
      final load = <String, dynamic>{'ctx': ctx, 'status': 'ok'};
      loads.add(load);
      try {
        final watch = Stopwatch()..start();
        await service.initialize(modelPath);
        load['load_ms'] = watch.elapsedMilliseconds;
        load['mem_after_load_mb'] = await memMb();
      } catch (e) {
        load['status'] = 'error: $e';
        await save();
        await service.dispose();
        continue;
      }
      await save();

      Future<String?> turn(
        String id,
        String kind,
        List<String> inputs,
        String prompt,
        int maxOutputTokens, {
        List<String>? organiseIds,
      }) async {
        final record = <String, dynamic>{
          'id': id,
          'ctx': ctx,
          'kind': kind,
          'input_words': _words(inputs),
          'prompt_chars': prompt.length,
          'max_output_tokens': maxOutputTokens,
          'status': 'ok',
        };
        turns.add(record);
        String? output;
        try {
          final g = await service.generate(prompt, maxOutputTokens: maxOutputTokens);
          output = g.text;
          record['ttft_ms'] = g.timeToFirstTokenMs;
          record['total_ms'] = g.totalMs;
          record['output_chunks'] = g.outputChunks;
          record['hit_output_cap'] = g.hitOutputCap;
          record['output'] = g.text;
          if (organiseIds != null) {
            final labels = parseOrganiseReply(g.text, inputs.length, defaultFolders);
            record['parse_valid'] = labels != null;
            record['labels'] = labels == null ? null : {for (var i = 0; i < labels.length; i++) organiseIds[i]: labels[i]};
          }
        } catch (e) {
          record['status'] = 'error: $e';
        }
        record['mem_after_turn_mb'] = await memMb();
        // ignore: avoid_print
        print('SYN_EVAL|${jsonEncode(record)}');
        await save();
        return output;
      }

      Future<String?> organise(String id, List<String> ids) {
        final inputs = pick(ids);
        return turn(id, 'organise', inputs, _p(buildOrganisePrompt(inputs, format: _format)), organiseOutputBudget(inputs.length),
            organiseIds: ids);
      }

      Future<String?> write(String id, List<String> ids) {
        final inputs = pick(ids);
        return turn(id, 'write', inputs, _p(buildWritePrompt(inputs, format: _format)), writeOutputBudget(_words(inputs)));
      }

      await organise('1_organise_r01_r03', ['r01', 'r02', 'r03']);
      await organise('2_organise_r06_r10', ['r06', 'r07', 'r08', 'r09', 'r10']);
      // Organise on every thought, using the pushed ids.
      if (!_skipAll) {
        final inputs = allThoughts;
        await turn('3_organise_all', 'organise', inputs, _p(buildOrganisePrompt(inputs, format: _format)),
            organiseOutputBudget(inputs.length),
            organiseIds: allIds);
      }
      await write('4_write_r08', ['r08']);
      await write('5_write_r02_r14_r11', ['r02', 'r14', 'r11']);
      await write('6_write_r12', ['r12']);
      await write('7_write_r13', ['r13']);
      await write('8_write_r10_r11_r12_r13', ['r10', 'r11', 'r12', 'r13']);
      if (!_skipAll) {
        await turn('9_write_all', 'write', allThoughts, _p(buildWritePrompt(allThoughts, format: _format)),
            writeOutputBudget(_words(allThoughts)));
      }

      Future<String?> structured(String id, List<String> ids) {
        final inputs = pick(ids);
        return turn(id, 'structured', inputs, _p(buildStructuredWritePrompt(inputs, format: _format)),
            structuredOutputBudget(_words(inputs)));
      }

      await structured('11_structured_r08', ['r08']);
      await structured('12_structured_r02_r14_r11', ['r02', 'r14', 'r11']);
      await structured('13_structured_r13', ['r13']);
      await structured('14_structured_r10_r11_r12_r13', ['r10', 'r11', 'r12', 'r13']);

      await service.dispose();
      await Future.delayed(const Duration(seconds: 5));
      load['mem_after_dispose_mb'] = await memMb();
      await save();
    }

    expect(turns.where((t) => t['status'] == 'ok'), isNotEmpty, reason: 'No turn succeeded');
  });
}
