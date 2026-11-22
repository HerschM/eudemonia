import 'dart:async';

import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/model_residency_arbiter.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 11, 21, 9);

class FakeSTTService extends STTService {
  final List<String> log;
  bool _loaded = false;
  int disposeCallCount = 0;

  FakeSTTService(this.log);

  @override
  bool get isInitialized => _loaded;

  @override
  Future<void> initialize(String modelDir) async {
    log.add('stt-load');
    _loaded = true;
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!_loaded) throw StateError('FakeSTTService used before initialize');
    return '';
  }

  @override
  void dispose() {
    disposeCallCount++;
    log.add('stt-dispose');
    _loaded = false;
  }
}

/// Scripted reply: a string answers the prompt, null holds the generation until it is stopped.
typedef Responder = FutureOr<String?> Function(String prompt);

class FakeSession implements LlmPromptSession {
  final StreamController<String> _chunks = StreamController<String>();
  final Completer<LlmPromptCompletion> _done = Completer<LlmPromptCompletion>();

  FakeSession(Future<String?> reply) {
    _done.future.ignore();
    reply.then((text) {
      if (text == null || _done.isCompleted) return;
      _chunks.add(text);
      _done.complete(const LlmPromptCompletion(hitOutputCap: false, stopped: false));
    }, onError: (Object e) {
      if (!_done.isCompleted) _done.completeError(e);
    });
  }

  @override
  Stream<String> get chunks => _chunks.stream;

  @override
  Future<LlmPromptCompletion> get completion => _done.future;

  @override
  Future<void> stop() async {
    if (!_done.isCompleted) _done.complete(const LlmPromptCompletion(hitOutputCap: false, stopped: true));
  }

  @override
  Future<void> close() async {
    await _chunks.close();
  }
}

class FakeEngine implements LlmEngine {
  final List<String> log;
  Responder responder;
  Completer<void>? loadGate;
  bool _loaded = false;
  final List<String> prompts = [];

  /// Called when a prompt is sent, before its reply is produced.
  void Function(String prompt)? onPrompt;

  /// When set, dispose does not finish until it completes.
  Completer<void>? disposeGate;
  bool disposeStarted = false;

  FakeEngine(this.log, this.responder);

  @override
  Future<void> load(String modelPath) async {
    log.add('llm-load:$modelPath');
    final gate = loadGate;
    if (gate != null) await gate.future;
    _loaded = true;
  }

  @override
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens}) async {
    if (!_loaded) throw StateError('FakeEngine used before load');
    prompts.add(prompt);
    onPrompt?.call(prompt);
    return FakeSession(Future(() => responder(prompt)));
  }

  @override
  Future<void> dispose() async {
    disposeStarted = true;
    final gate = disposeGate;
    if (gate != null) await gate.future;
    log.add('llm-dispose');
    _loaded = false;
  }
}

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

bool isOrganise(String prompt) => prompt.contains('Answer:');

List<String> promptThoughts(String prompt) => RegExp(r'^\d+\. (.*)$', multiLine: true)
    .allMatches(prompt.split('Thoughts:\n').last)
    .map((m) => m[1]!)
    .toList();

/// Organise: Personal for thoughts mentioning "home", Work otherwise. Write: the thoughts, verbatim.
String defaultReply(String prompt) {
  final thoughts = promptThoughts(prompt);
  if (isOrganise(prompt)) {
    return [
      for (var i = 0; i < thoughts.length; i++) '${i + 1}: ${thoughts[i].contains('home') ? 'Personal' : 'Work'}',
    ].join('\n');
  }
  return thoughts.join(' ');
}

void main() {
  late List<String> log;
  late NotesRepository notes;
  late SynthesisSessionStore store;
  late FakeSTTService stt;
  late ModelResidencyArbiter arbiter;
  late ModelLifecycleManager lifecycle;
  late FakeEngine engine;
  late LLMService llm;
  late bool captureActive;
  late List<bool> runningChanges;
  late int notesChanged;
  ProviderContainer? container;

  setUp(() {
    log = [];
    notes = NotesRepository();
    store = SynthesisSessionStore();
    stt = FakeSTTService(log);
    arbiter = ModelResidencyArbiter();
    lifecycle = ModelLifecycleManager(stt, modelsDirResolver: () async => '/models', arbiter: arbiter);
    engine = FakeEngine(log, defaultReply);
    llm = LLMService(engineFactory: () => engine, stopTimeout: const Duration(seconds: 2));
    captureActive = false;
    runningChanges = [];
    notesChanged = 0;
    container = null;
  });

  tearDown(() {
    container?.dispose();
    lifecycle.dispose();
  });

  ProviderContainer app() {
    return container ??= ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(notes),
      synthesisSessionStoreProvider.overrideWithValue(store),
    ]);
  }

  List<SynthesisCluster> sessions() => app().read(synthesisRepositoryProvider);

  SynthesisRunner runner() {
    final c = app();
    return SynthesisRunner(
      notes: notes,
      sessions: c.read(synthesisRepositoryProvider.notifier),
      readSessions: () => c.read(synthesisRepositoryProvider),
      llm: llm,
      lifecycle: lifecycle,
      arbiter: arbiter,
      isCaptureActive: () => captureActive,
      modelsDir: () async => '/models',
      onRunningChanged: runningChanges.add,
      onNotesChanged: () => notesChanged++,
    );
  }

  Future<Note> thought(String text, int minutes, {int attempts = 0, ThoughtState state = ThoughtState.processed}) async {
    final note = Note(correctedText: text, createdAt: _t0.add(Duration(minutes: minutes)), state: state)
      ..synthesisAttempts = attempts;
    await notes.saveNote(note);
    return note;
  }

  Future<void> storeSession(SynthesisCluster cluster) => store.put(cluster);

  SynthesisCluster session(String id, String folder, String note, List<Note> origins, {bool reprocessing = false}) =>
      SynthesisCluster(
        clusterId: id,
        sequenceNumber: '#S-01',
        folder: folder,
        synthesizedContent: note,
        sessionStart: origins.isEmpty ? _t0 : origins.first.createdAt!,
        sessionEnd: origins.isEmpty ? _t0 : origins.last.createdAt!,
        sessionDuration: Duration.zero,
        originNotes: [for (final n in origins) SynthesisOriginNote.fromNote(n)],
        isReprocessing: reprocessing,
      );

  Future<Note> reload(Note n) async => (await notes.getNoteById(n.id))!;

  void expectModelReleased() {
    expect(llm.isInitialized, isFalse);
    expect(arbiter.holder, isNull);
    expect(log.last, 'llm-dispose');
  }

  group('SynthesisRunner', () {
    test('creates one session per folder, each only after its write turn, and marks thoughts synthesized', () async {
      final a = await thought('Refactor the queue.', 0);
      final b = await thought('Clean the home office.', 5);
      final c = await thought('Ship the capsule.', 10);
      final sessionsSeenAtWrite = <int>[];
      engine.onPrompt = (p) {
        if (!isOrganise(p)) sessionsSeenAtWrite.add(sessions().length);
      };

      final result = await runner().run(manual: false);

      expect(result, SynthesisRunResult.completed);
      expect(sessionsSeenAtWrite, [0, 1]);
      final s = sessions();
      expect(s.map((x) => x.folder), ['Personal', 'Work']);
      final work = s.firstWhere((x) => x.folder == 'Work');
      expect(work.synthesizedContent, 'Refactor the queue. Ship the capsule.');
      expect(work.originNotes.map((o) => o.id), [a.id, c.id]);
      expect(work.sessionStart, a.createdAt);
      expect(work.sessionEnd, c.createdAt);
      expect(work.sessionDuration, const Duration(minutes: 10));
      expect(work.isUnread, isTrue);
      expect(work.isReprocessing, isFalse);
      for (final n in [a, b, c]) {
        final r = await reload(n);
        expect(r.state, ThoughtState.synthesized);
        expect(r.synthesisAttempts, 0);
      }
      expect(runningChanges, [true, false]);
      expect(notesChanged, greaterThan(0));
      expectModelReleased();
    });

    test('an organise failure creates no session and counts an attempt; the thought stays in Capture', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.responder = (p) => isOrganise(p) ? 'no idea' : defaultReply(p);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(sessions(), isEmpty);
      final r = await reload(a);
      expect(r.state, ThoughtState.processed);
      expect(r.synthesisAttempts, 1);
    });

    test('a write failure leaves the existing session untouched and counts an attempt', () async {
      final old = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old note.', [old]));
      final a = await thought('Move it to Monday.', 10);
      engine.responder = (p) => isOrganise(p) ? defaultReply(p) : '';

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.synthesizedContent, 'Old note.');
      expect(s.originNotes.map((o) => o.id), [old.id]);
      final r = await reload(a);
      expect(r.state, ThoughtState.processed);
      expect(r.synthesisAttempts, 1);
    });

    test('a thought joining an existing session is written into it', () async {
      final old = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old note.', [old]));
      final a = await thought('Move it to Monday.', 10);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.clusterId, 's1');
      expect(s.synthesizedContent, 'Plan the release. Move it to Monday.');
      expect(s.originNotes.map((o) => o.id), [old.id, a.id]);
      expect(s.sessionDuration, const Duration(minutes: 10));
      expect((await reload(a)).state, ThoughtState.synthesized);
    });

    test('automatic runs skip thoughts that failed 3 times; the manual action retries them', () async {
      final a = await thought('Refactor the queue.', 0, attempts: 3);

      expect(await runner().run(manual: false), SynthesisRunResult.nothingToDo);
      expect(log, isEmpty);

      expect(await runner().run(manual: true), SynthesisRunResult.completed);
      expect(sessions(), hasLength(1));
      final r = await reload(a);
      expect(r.state, ThoughtState.synthesized);
      expect(r.synthesisAttempts, 0);
    });

    test('nothing to do without eligible thoughts or flagged sessions', () async {
      await thought('', 0);
      await thought('Done already.', 1, state: ThoughtState.synthesized);
      expect(await runner().run(manual: true), SynthesisRunResult.nothingToDo);
      expect(log, isEmpty);
      expect(runningChanges, isEmpty);
    });

    test('busy while capture is active', () async {
      await thought('Refactor the queue.', 0);
      captureActive = true;
      final r = runner();
      expect(await r.run(manual: true), SynthesisRunResult.busy);
      expect(r.isRunning, isFalse);
      expect(log, isEmpty);
      expect(arbiter.holder, isNull);
    });

    test('busy while the speech model is in use', () async {
      await thought('Refactor the queue.', 0);
      final gate = Completer<void>();
      final task = lifecycle.runWithModels(() => gate.future);
      await Future<void>.delayed(Duration.zero);
      expect(await runner().run(manual: true), SynthesisRunResult.busy);
      gate.complete();
      await task;
      expect(log.where((e) => e.startsWith('llm-load')), isEmpty);
    });

    test('busy while speech holds the residency slot', () async {
      await thought('Refactor the queue.', 0);
      await arbiter.acquireSpeech();
      expect(await runner().run(manual: true), SynthesisRunResult.busy);
      expect(arbiter.holder, HeavyModel.speech);
      expect(log, isEmpty);
    });

    test('evicts the speech model before loading the language model', () async {
      await thought('Refactor the queue.', 0);
      await lifecycle.ensureModelsLoaded();

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(log.indexOf('stt-dispose'), lessThan(log.indexOf('llm-load:/models/qwen2.5-1.5b.gguf')));
      expect(lifecycle.state, ModelLifecycleState.unloaded);
    });

    test('an engine error fails the run, counts no attempts and releases the model', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.responder = (p) => throw Exception('native fault');

      expect(await runner().run(manual: false), SynthesisRunResult.failed);

      expect(sessions(), isEmpty);
      final r = await reload(a);
      expect(r.state, ThoughtState.processed);
      expect(r.synthesisAttempts, 0);
      expect(runningChanges, [true, false]);
      expectModelReleased();
    });

    test('a load failure fails the run and releases the slot', () async {
      await thought('Refactor the queue.', 0);
      final r = SynthesisRunner(
        notes: notes,
        sessions: app().read(synthesisRepositoryProvider.notifier),
        readSessions: () => app().read(synthesisRepositoryProvider),
        llm: llm,
        lifecycle: lifecycle,
        arbiter: arbiter,
        isCaptureActive: () => false,
        modelsDir: () async => null,
      );
      expect(await r.run(manual: true), SynthesisRunResult.failed);
      expect(arbiter.holder, isNull);
      expect(r.isRunning, isFalse);
    });

    test('a recording preempts a write turn: committed sessions stay, nothing else changes', () async {
      final a = await thought('Refactor the queue.', 0);
      final b = await thought('Clean the home office.', 5);
      var writes = 0;
      final held = Completer<void>();
      engine.responder = (p) {
        if (isOrganise(p)) return defaultReply(p);
        if (++writes == 1) return defaultReply(p);
        held.complete();
        return null;
      };

      final run = runner().run(manual: false);
      await held.future;
      await lifecycle.ensureModelsLoaded(reason: 'recording');

      expect(await run, SynthesisRunResult.preempted);
      expect(sessions().single.folder, 'Work');
      expect((await reload(a)).state, ThoughtState.synthesized);
      final rb = await reload(b);
      expect(rb.state, ThoughtState.processed);
      expect(rb.synthesisAttempts, 0);
      expect(arbiter.holder, HeavyModel.speech);
      expect(lifecycle.state, ModelLifecycleState.ready);
      expect(llm.isInitialized, isFalse);
      expect(runningChanges, [true, false]);
    });

    test('a recording during model load preempts the run once the load settles', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.loadGate = Completer<void>();

      final run = runner().run(manual: false);
      await until(() => log.any((e) => e.startsWith('llm-load')));
      final speech = lifecycle.ensureModelsLoaded(reason: 'recording');
      engine.loadGate!.complete();

      expect(await run, SynthesisRunResult.preempted);
      await speech;
      expect(arbiter.holder, HeavyModel.speech);
      expect(engine.prompts, isEmpty);
      expect((await reload(a)).synthesisAttempts, 0);
    });

    test('the language model is fully disposed before the slot is released at the end of a run', () async {
      await thought('Refactor the queue.', 0);
      final gate = engine.disposeGate = Completer<void>();

      final run = runner().run(manual: false);
      await until(() => engine.disposeStarted);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(arbiter.holder, HeavyModel.language);
      gate.complete();

      expect(await run, SynthesisRunResult.completed);
      expectModelReleased();
    });

    test('a preempting recording loads speech only after the language model is fully disposed', () async {
      await thought('Refactor the queue.', 0);
      final held = Completer<void>();
      engine.responder = (p) {
        if (!held.isCompleted) held.complete();
        return null;
      };
      final gate = engine.disposeGate = Completer<void>();

      final run = runner().run(manual: false);
      await held.future;
      final speech = lifecycle.ensureModelsLoaded(reason: 'recording');
      await until(() => engine.disposeStarted);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(arbiter.holder, HeavyModel.language);
      expect(log, isNot(contains('stt-load')));
      gate.complete();

      expect(await run, SynthesisRunResult.preempted);
      await speech;
      expect(log.indexOf('llm-dispose'), lessThan(log.indexOf('stt-load')));
      expect(arbiter.holder, HeavyModel.speech);
    });

    test('a flagged session is rewritten from its thoughts and the flag cleared', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Stale merged text.', [x, y], reprocessing: true));

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release. Move it to Monday.');
      expect(s.isReprocessing, isFalse);
      expect(s.isUnread, isTrue);
      expect(engine.prompts.where(isOrganise), isEmpty);
    });

    test('a flagged session whose write fails stays flagged', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Stale.', [x], reprocessing: true));
      engine.responder = (p) => '';

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(sessions().single.isReprocessing, isTrue);
      expect(sessions().single.synthesizedContent, 'Stale.');
    });

    test('a flagged session without thoughts is removed', () async {
      await storeSession(session('s1', 'Work', 'Empty.', [], reprocessing: true));

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(sessions(), isEmpty);
    });

    test('a second run while one is in progress is busy', () async {
      await thought('Refactor the queue.', 0);
      engine.loadGate = Completer<void>();
      final r = runner();

      final first = r.run(manual: true);
      expect(r.isRunning, isTrue);
      expect(await r.run(manual: true), SynthesisRunResult.busy);
      engine.loadGate!.complete();

      expect(await first, SynthesisRunResult.completed);
      expect(r.isRunning, isFalse);
    });
  });
}
