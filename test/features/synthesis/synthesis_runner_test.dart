import 'dart:async';

import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/cpu_wake_lock.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/model_residency_arbiter.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/capture/thought_actions.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/application/session_actions.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_prompts.dart';
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
  final Completer<LlmPromptCompletion> _done = Completer<LlmPromptCompletion>();

  FakeSession(Future<String?> reply) {
    _done.future.ignore();
    reply.then((text) {
      if (text == null || _done.isCompleted) return;
      _done.complete(LlmPromptCompletion(
        text: text,
        hitOutputCap: false,
        stopped: false,
        promptTokens: 300,
        reusedPromptTokens: 256,
        outputTokens: 12,
        readMs: 2500,
        writeMs: 1500,
        readingThreads: 6,
        writingThreads: 2,
        allowedCores: '0-5',
      ));
    }, onError: (Object e) {
      if (!_done.isCompleted) _done.completeError(e);
    });
  }

  @override
  Future<LlmPromptCompletion> get completion => _done.future;

  @override
  Future<void> stop() async {
    if (!_done.isCompleted) _done.complete(const LlmPromptCompletion(text: '', hitOutputCap: false, stopped: true));
  }
}

/// Records every save as (id, synthesisAttempts at that moment); the in-memory store shares
/// instances, so only the save itself proves a counter was persisted.
class RecordingNotesRepository extends NotesRepository {
  final List<(int, int)> saves = [];

  @override
  Future<void> saveNote(Note note) {
    saves.add((note.id, note.synthesisAttempts));
    return super.saveNote(note);
  }
}

/// Keeps every info line in memory instead of writing a log file.
class RecordingLogger extends AppLogger {
  final List<String> infos = [];
  final List<String> warnings = [];

  @override
  Future<void> info(String message) async => infos.add(message);

  @override
  Future<void> warning(String message) async => warnings.add(message);

  @override
  Future<void> error(String message, {dynamic error, StackTrace? stackTrace}) async {}
}

/// Appends 'wake-hold' / 'wake-release' to the same log as the engine so their order is observable.
class FakeCpuWakeLock implements CpuWakeLock {
  final List<String> log;
  final List<Duration> holds = [];

  /// When set, the first hold does not finish until it completes.
  Completer<void>? firstHoldGate;

  FakeCpuWakeLock(this.log);

  @override
  Future<void> hold(Duration timeout) async {
    holds.add(timeout);
    log.add('wake-hold');
    final gate = firstHoldGate;
    if (gate != null && holds.length == 1) await gate.future;
  }

  @override
  Future<void> release() async {
    log.add('wake-release');
  }
}

class FakeEngine implements LlmEngine {
  final List<String> log;
  Responder responder;
  Completer<void>? loadGate;

  /// When set, the load fails with it.
  Object? loadError;
  bool _loaded = false;
  final List<String> prompts = [];
  final List<String?> grammars = [];

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
    final error = loadError;
    if (error != null) throw error;
    _loaded = true;
  }

  @override
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens, String? grammar}) async {
    if (!_loaded) throw StateError('FakeEngine used before load');
    prompts.add(prompt);
    grammars.add(grammar);
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

class MemoryFolderStore implements FolderStore {
  List<FolderDefinition>? stored;

  @override
  Future<List<FolderDefinition>?> load() async => stored;

  @override
  Future<void> save(List<FolderDefinition> folders) async => stored = List.of(folders);
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
  late RecordingNotesRepository notes;
  late SynthesisSessionStore store;
  late FakeSTTService stt;
  late ModelResidencyArbiter arbiter;
  late ModelLifecycleManager lifecycle;
  late FakeEngine engine;
  late LLMService llm;
  late bool captureActive;
  late List<bool> runningChanges;
  SynthesisModelProfile? activeProfile;
  ProviderContainer? container;

  setUp(() {
    log = [];
    notes = RecordingNotesRepository();
    store = SynthesisSessionStore();
    stt = FakeSTTService(log);
    arbiter = ModelResidencyArbiter();
    lifecycle = ModelLifecycleManager(stt, modelsDirResolver: () async => '/models', arbiter: arbiter);
    engine = FakeEngine(log, defaultReply);
    llm = LLMService(engineFactory: () => engine, stopTimeout: const Duration(seconds: 2));
    captureActive = false;
    runningChanges = [];
    activeProfile = SynthesisModelProfile.qwen3_4b;
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
      folderStoreProvider.overrideWithValue(MemoryFolderStore()),
    ]);
  }

  List<SynthesisCluster> sessions() => app().read(synthesisRepositoryProvider);

  SynthesisRunner runner({
    CpuWakeLock? wakeLock,
    AppLogger? logger,
    Future<List<FolderDefinition>> Function()? folders,
    void Function(String clusterId, String styleId, String? failure)? onRewriteFinished,
  }) {
    final c = app();
    return SynthesisRunner(
      folders: folders ?? () async => defaultFolders,
      notes: notes,
      sessions: c.read(synthesisRepositoryProvider.notifier),
      readSessions: () => c.read(synthesisRepositoryProvider),
      llm: llm,
      lifecycle: lifecycle,
      arbiter: arbiter,
      profile: () => activeProfile,
      isCaptureActive: () => captureActive,
      modelsDir: () async => '/models',
      wakeLock: wakeLock,
      logger: logger,
      onRunningChanged: runningChanges.add,
      onRewriteFinished: onRewriteFinished,
    );
  }

  Future<Note> thought(String text, int minutes, {int attempts = 0, ThoughtState state = ThoughtState.processed}) async {
    final note = Note(correctedText: text, createdAt: _t0.add(Duration(minutes: minutes)), state: state)
      ..synthesisAttempts = attempts;
    await notes.saveNote(note);
    return note;
  }

  Future<void> storeSession(SynthesisCluster cluster) => store.put(cluster);

  SynthesisCluster session(String id, String folder, String note, List<Note> origins,
          {bool reprocessing = false, String? style}) =>
      SynthesisCluster(
        appliedStyleId: style ?? defaultNoteStyleId,
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
      expectModelReleased();
    });

    test('organise turns are bound to the folder grammar, write turns are not; each turn logs its figures', () async {
      await thought('Refactor the queue.', 0);
      await thought('Clean the home office.', 5);
      final logger = RecordingLogger();

      expect(await runner(logger: logger).run(manual: false), SynthesisRunResult.completed);

      expect(engine.prompts.length, 3);
      expect(isOrganise(engine.prompts.first), isTrue);
      expect(engine.grammars.first, buildOrganiseGrammar(2, defaultFolders));
      expect(engine.grammars.skip(1), [null, null]);
      final turns = logger.infos.where((l) => l.startsWith('[Synthesis] Turn:')).toList();
      expect(turns.length, 3);
      expect(
        turns.first,
        '[Synthesis] Turn: 300 prompt tokens (256 reused) read in 2.5s; 12 output tokens written in 1.5s; '
        'threads 6 reading / 2 writing on cores 0-5.',
      );
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

    test('no chosen language model: noModel before anything is evicted, loaded or counted', () async {
      final a = await thought('Refactor the queue.', 0);
      await lifecycle.ensureModelsLoaded();
      log.clear();
      activeProfile = null;
      final saves = notes.saves.length;

      expect(await runner().run(manual: true), SynthesisRunResult.noModel);
      expect(await runner().run(manual: false), SynthesisRunResult.noModel);

      expect(log, isEmpty, reason: 'the speech model stays resident and nothing is loaded');
      expect(lifecycle.state, ModelLifecycleState.ready);
      expect(arbiter.holder, HeavyModel.speech, reason: 'the resident speech model was not evicted');
      expect(runningChanges, isEmpty);
      expect(notes.saves.length, saves, reason: 'no attempt was counted');
      expect((await reload(a)).synthesisAttempts, 0);
      expect(sessions(), isEmpty);
    });

    test('the profile is resolved once per run and names the file that is loaded', () async {
      await thought('Refactor the queue.', 0);
      var resolved = 0;
      final r = SynthesisRunner(
        notes: notes,
        sessions: app().read(synthesisRepositoryProvider.notifier),
        readSessions: () => app().read(synthesisRepositoryProvider),
        llm: llm,
        lifecycle: lifecycle,
        arbiter: arbiter,
        profile: () {
          resolved++;
          return SynthesisModelProfile.qwen3_1_7b;
        },
        isCaptureActive: () => false,
        modelsDir: () async => '/models',
      );

      expect(await r.run(manual: true), SynthesisRunResult.completed);

      expect(resolved, 1);
      expect(log, contains('llm-load:/models/qwen3-1.7b.gguf'));
    });

    test('evicts the speech model before loading the language model', () async {
      await thought('Refactor the queue.', 0);
      await lifecycle.ensureModelsLoaded();

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(log.indexOf('stt-dispose'), lessThan(log.indexOf('llm-load:/models/${SynthesisModelProfile.qwen3_4b.modelFileName}')));
      expect(lifecycle.state, ModelLifecycleState.unloaded);
    });

    test('an engine error fails the run, keeps the start-of-run attempt and releases the model', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.responder = (p) => throw Exception('native fault');

      expect(await runner().run(manual: false), SynthesisRunResult.failed);

      expect(sessions(), isEmpty);
      final r = await reload(a);
      expect(r.state, ThoughtState.processed);
      expect(r.synthesisAttempts, 1);
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
        profile: () => SynthesisModelProfile.qwen3_4b,
        isCaptureActive: () => false,
        modelsDir: () async => null,
      );
      expect(await r.run(manual: true), SynthesisRunResult.failed);
      expect(arbiter.holder, isNull);
      expect(r.isRunning, isFalse);
      expect((await notes.getAllNotes()).single.synthesisAttempts, 1);
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

    test('a flagged session whose rewrite reply is invalid keeps its note, is no longer flagged and logs a warning',
        () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Stale.', [x], reprocessing: true));
      engine.responder = (p) => '';
      final logger = RecordingLogger();

      expect(await runner(logger: logger).run(manual: false), SynthesisRunResult.completed);

      expect(sessions().single.isReprocessing, isFalse);
      expect(sessions().single.synthesizedContent, 'Stale.');
      expect(logger.warnings.where((w) => w.contains('No valid rewrite')), hasLength(1));
      await app().read(synthesisRepositoryProvider.notifier).pendingWrites;
      expect((await store.loadAll()).single.isReprocessing, isFalse);
    });

    test('a flagged session whose rewrite is preempted stays flagged for the next run', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Stale.', [x], reprocessing: true));
      final held = Completer<void>();
      engine.responder = (p) {
        held.complete();
        return null;
      };

      final run = runner().run(manual: false);
      await held.future;
      await lifecycle.ensureModelsLoaded(reason: 'recording');

      expect(await run, SynthesisRunResult.preempted);
      expect(sessions().single.isReprocessing, isTrue);
      expect(sessions().single.synthesizedContent, 'Stale.');
    });

    test('a run with no thoughts waiting but a flagged session does the rewrite', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Stale.', [x], reprocessing: true));

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(engine.prompts, hasLength(1));
      expect(sessions().single.synthesizedContent, 'Plan the release.');
      expect(sessions().single.isReprocessing, isFalse);
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

  group('a deleted or edited thought leaves its note consistent', () {
    ThoughtActions actions(SynthesisRunner r, List<Future<SynthesisRunResult>> runs) => ThoughtActions(
          notes: notes,
          sessions: app().read(synthesisRepositoryProvider.notifier),
          startRewrite: () {
            final run = r.run(manual: true);
            runs.add(run);
            return run;
          },
        );

    test('deleting a synthesized thought rewrites its note without it and clears the flag', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Plan the release. Move it to Monday.', [x, y]));
      final r = runner();
      final runs = <Future<SynthesisRunResult>>[];
      app().read(synthesisRepositoryProvider);

      await actions(r, runs).delete(y);

      expect(runs, hasLength(1));
      expect(await runs.single, SynthesisRunResult.completed);
      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release.');
      expect(s.originNotes.map((o) => o.id), [x.id]);
      expect(s.isReprocessing, isFalse);
      expect(engine.prompts.single, isNot(contains('Monday')));
    });

    test('editing a synthesized thought rewrites its note with the new text', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Plan the release. Move it to Monday.', [x, y]));
      final r = runner();
      final runs = <Future<SynthesisRunResult>>[];
      app().read(synthesisRepositoryProvider);

      await actions(r, runs).editText(y, 'Move it to Tuesday.');

      expect(await runs.single, SynthesisRunResult.completed);
      expect(sessions().single.synthesizedContent, 'Plan the release. Move it to Tuesday.');
      expect(sessions().single.isReprocessing, isFalse);
    });

    test('a rewrite that cannot start now (busy) leaves the session flagged for the next run', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Plan the release. Move it to Monday.', [x, y]));
      final r = runner();
      final runs = <Future<SynthesisRunResult>>[];
      app().read(synthesisRepositoryProvider);
      captureActive = true;

      await actions(r, runs).delete(y);

      expect(await runs.single, SynthesisRunResult.busy);
      expect(sessions().single.isReprocessing, isTrue);
      captureActive = false;
      expect(await r.run(manual: false), SynthesisRunResult.completed);
      expect(sessions().single.synthesizedContent, 'Plan the release.');
      expect(sessions().single.isReprocessing, isFalse);
    });

    test('a thought deleted while its note is being rewritten is left out by a second rewrite in the same run',
        () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      final z = await thought('Tell the team.', 20, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x, y, z], reprocessing: true));
      final r = runner();
      final runs = <Future<SynthesisRunResult>>[];
      final gate = Completer<void>();
      final firstWriteSent = Completer<void>();
      engine.responder = (p) async {
        if (!firstWriteSent.isCompleted) {
          firstWriteSent.complete();
          await gate.future;
        }
        return defaultReply(p);
      };

      final run = r.run(manual: false);
      await firstWriteSent.future;
      await actions(r, runs).delete(z);
      expect(await runs.single, SynthesisRunResult.busy);
      gate.complete();

      expect(await run, SynthesisRunResult.completed);
      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release. Move it to Monday.');
      expect(s.isReprocessing, isFalse);
      expect(engine.prompts, hasLength(2));
    });

    test('a waiting thought deleted while its note is being written is not brought back', () async {
      final a = await thought('Refactor the queue.', 0);
      final b = await thought('Ship the capsule.', 5);
      final gate = Completer<void>();
      final writeSent = Completer<void>();
      engine.responder = (p) async {
        if (!isOrganise(p) && !writeSent.isCompleted) {
          writeSent.complete();
          await gate.future;
        }
        return defaultReply(p);
      };
      final r = runner();

      final run = r.run(manual: false);
      await writeSent.future;
      await notes.deleteNote(b.id);
      gate.complete();

      expect(await run, SynthesisRunResult.completed);
      expect(await notes.getNoteById(b.id), isNull);
      final s = sessions().single;
      expect(s.originNotes.map((o) => o.id), [a.id]);
      expect(s.synthesizedContent, 'Refactor the queue.', reason: 'rewritten from the thoughts that are left');
      expect(s.isReprocessing, isFalse);
    });
  });

  group('note styles', () {
    /// Write turns answer as Key points: a title and one bullet per thought, verbatim.
    String bulletReply(String p) =>
        isOrganise(p) ? defaultReply(p) : '**Note**\n\n${promptThoughts(p).map((t) => '- $t').join('\n')}';

    test('a restyled session is rewritten with its style\'s prompt; the run logs the model and the styles', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], reprocessing: true, style: 'journal'));
      final logger = RecordingLogger();
      final outcomes = <String>[];

      expect(await runner(logger: logger, onRewriteFinished: (id, style, f) => outcomes.add('$id $style $f'))
          .run(manual: true), SynthesisRunResult.completed);

      expect(engine.prompts.single, contains(noteStyleById('journal').systemPrompt));
      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release.');
      expect(s.appliedStyleId, 'journal');
      expect(s.isReprocessing, isFalse);
      expect(outcomes, ['s1 journal null']);
      expect(logger.infos.where((l) => l.startsWith('[Synthesis] Run started (manual): model qwen3-4b.gguf, ')),
          hasLength(1));
      expect(logger.infos.firstWhere((l) => l.startsWith('[Synthesis] Run started')), contains('journal'));
    });

    test('a new session is written organised', () async {
      await thought('Refactor the queue.', 0);
      final logger = RecordingLogger();

      expect(await runner(logger: logger).run(manual: false), SynthesisRunResult.completed);

      expect(engine.prompts.last, contains(noteStyleById('organised').systemPrompt));
      expect(sessions().single.appliedStyleId, 'organised');
      expect(logger.infos.first, startsWith('[Synthesis] Run started (automatic): model qwen3-4b.gguf, 1 thought(s) waiting'));
    });

    test('a new session is written in its folder\'s default style and keeps it', () async {
      await thought('Refactor the queue.', 0);
      final c = app();
      final folderNotifier = c.read(foldersProvider.notifier);
      await folderNotifier.loaded;
      expect(await folderNotifier.updateDefaultStyle('Work', 'journal'), FolderChange.done);
      final outcomes = <String>[];

      expect(
          await runner(folders: () async => c.read(foldersProvider), onRewriteFinished: (id, s, f) => outcomes.add('$s $f'))
              .run(manual: false),
          SynthesisRunResult.completed);

      expect(engine.prompts.last, contains(noteStyleById('journal').systemPrompt));
      expect(engine.prompts.last, contains(noteStyleById('journal').request));
      final s = sessions().single;
      expect(s.folder, 'Work');
      expect(s.appliedStyleId, 'journal');
      expect(s.synthesizedContent, 'Refactor the queue.');
      expect(outcomes, ['journal null']);
      await app().read(synthesisRepositoryProvider.notifier).pendingWrites;
      expect((await store.loadAll()).single.appliedStyleId, 'journal');
    });

    test('a new session whose reply breaks its folder\'s style is not created; the thought stays in Capture', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.responder = bulletReply;

      expect(
          await runner(folders: () async => const [
                FolderDefinition(name: 'Work', description: 'w', defaultStyleId: 'journal'),
                FolderDefinition(name: 'Uncategorized', description: 'u'),
              ]).run(manual: false),
          SynthesisRunResult.completed);

      expect(sessions(), isEmpty);
      expect((await reload(a)).state, ThoughtState.processed);
    });

    test('a style picked by hand stays when later thoughts join, whatever the folder\'s default', () async {
      final old = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', '**Note**\n\n- Plan the release.', [old], style: 'bullets'));
      await thought('Move it to Monday.', 10);
      engine.responder = bulletReply;

      expect(
          await runner(folders: () async => const [
                FolderDefinition(name: 'Work', description: 'w', defaultStyleId: 'journal'),
                FolderDefinition(name: 'Uncategorized', description: 'u'),
              ]).run(manual: false),
          SynthesisRunResult.completed);

      expect(engine.prompts.last, contains(noteStyleById('bullets').systemPrompt));
      final s = sessions().single;
      expect(s.appliedStyleId, 'bullets');
      expect(s.synthesizedContent, '**Note**\n\n- Plan the release.\n- Move it to Monday.');
    });

    test('a thought joining a styled session is written in that style', () async {
      final old = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', '**Note**\n\n- Plan the release.', [old], style: 'bullets'));
      final a = await thought('Move it to Monday.', 10);
      engine.responder = bulletReply;

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(engine.prompts.last, contains(noteStyleById('bullets').systemPrompt));
      final s = sessions().single;
      expect(s.synthesizedContent, '**Note**\n\n- Plan the release.\n- Move it to Monday.');
      expect(s.appliedStyleId, 'bullets');
      expect((await reload(a)).state, ThoughtState.synthesized);
    });

    test('a failed rewrite reports its style and why', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], reprocessing: true, style: 'bullets'));
      final outcomes = <String>[];
      // Not a list: the Key points form is broken.
      engine.responder = defaultReply;

      expect(await runner(onRewriteFinished: (id, style, f) => outcomes.add('$id $style $f')).run(manual: true),
          SynthesisRunResult.completed);

      expect(sessions().single.synthesizedContent, 'Old.');
      expect(sessions().single.isReprocessing, isFalse);
      expect(outcomes, ['s1 bullets no valid reply']);
    });

    test('a style applied while the session is being written is rewritten in that style in the same run', () async {
      final old = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Plan the release.', [old]));
      await thought('Move it to Monday.', 10);
      final gate = Completer<void>();
      final writeSent = Completer<void>();
      engine.responder = (p) async {
        if (!isOrganise(p) && !writeSent.isCompleted) {
          writeSent.complete();
          await gate.future;
        }
        return bulletReply(p);
      };
      final r = runner();

      final run = r.run(manual: false);
      await writeSent.future;
      app().read(synthesisRepositoryProvider.notifier).applyStyle('s1', 'bullets');
      gate.complete();

      expect(await run, SynthesisRunResult.completed);
      expect(engine.prompts, hasLength(3));
      expect(engine.prompts.last, contains(noteStyleById('bullets').systemPrompt));
      final s = sessions().single;
      expect(s.appliedStyleId, 'bullets');
      expect(s.synthesizedContent, '**Note**\n\n- Plan the release.\n- Move it to Monday.');
      expect(s.isReprocessing, isFalse);
    });
  });

  group('restyling a note', () {
    late List<RestyleNotice> notices;
    late List<Future<SynthesisRunResult>> runs;

    setUp(() {
      notices = [];
      runs = [];
    });

    SessionActions actions({List<FolderDefinition> folders = defaultFolders}) {
      late SessionActions a;
      final r = runner(folders: () async => folders, onRewriteFinished: (id, style, f) => a.rewriteFinished(id, style, f));
      return a = SessionActions(
        sessions: app().read(synthesisRepositoryProvider.notifier),
        startRun: () {
          final run = r.run(manual: true);
          runs.add(run);
          return run;
        },
        notify: notices.add,
        folders: () async => folders,
      );
    }

    const styledFolders = [
      FolderDefinition(name: 'Work', description: 'w'),
      FolderDefinition(name: 'Personal', description: 'p', defaultStyleId: 'journal'),
      FolderDefinition(name: 'Uncategorized', description: 'u'),
    ];

    test('moving a note to a folder with the same default style only changes its folder', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x]));
      app().read(synthesisRepositoryProvider);

      await actions(folders: styledFolders).moveToFolder('s1', 'Uncategorized');

      final s = sessions().single;
      expect(s.folder, 'Uncategorized');
      expect(s.appliedStyleId, 'organised');
      expect(s.isReprocessing, isFalse);
      expect(s.synthesizedContent, 'Old.');
      expect(runs, isEmpty);
    });

    test('moving a note to a folder with another default style rewrites it in that style', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x]));
      app().read(synthesisRepositoryProvider);

      await actions(folders: styledFolders).moveToFolder('s1', 'Personal');

      expect(sessions().single.folder, 'Personal');
      expect(sessions().single.appliedStyleId, 'journal');
      expect(sessions().single.isReprocessing, isTrue, reason: 'flagged at once, before the run ends');
      expect(await runs.single, SynthesisRunResult.completed);
      expect(engine.prompts.single, contains(noteStyleById('journal').systemPrompt));
      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release.');
      expect(s.appliedStyleId, 'journal');
      expect(s.isReprocessing, isFalse);
      expect(notices, isEmpty);
    });

    test('a move whose rewrite is invalid keeps the folder, restores the style and says so', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], style: 'bullets'));
      app().read(synthesisRepositoryProvider);
      engine.responder = (p) => '';

      await actions(folders: styledFolders).moveToFolder('s1', 'Personal');
      expect(await runs.single, SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.folder, 'Personal');
      expect(s.appliedStyleId, 'bullets');
      expect(s.synthesizedContent, 'Old.');
      expect(s.isReprocessing, isFalse);
      expect(notices.single.message, 'Could not rewrite this note as "Journal entry". It is unchanged.');
    });

    test('moving a note to a folder that no longer exists only changes its folder', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], style: 'bullets'));
      app().read(synthesisRepositoryProvider);

      await actions(folders: styledFolders).moveToFolder('s1', 'Gone');

      expect(sessions().single.folder, 'Gone');
      expect(sessions().single.appliedStyleId, 'bullets');
      expect(runs, isEmpty);
    });

    test('applying a style starts a run; a valid rewrite clears the flag and keeps the new style', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x]));
      app().read(synthesisRepositoryProvider);

      await actions().applyStyle('s1', 'journal');

      expect(sessions().single.isReprocessing, isTrue, reason: 'flagged at once, before the run ends');
      expect(sessions().single.appliedStyleId, 'journal');
      expect(runs, hasLength(1));
      expect(await runs.single, SynthesisRunResult.completed);
      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release.');
      expect(s.appliedStyleId, 'journal');
      expect(s.isReprocessing, isFalse);
      expect(notices, isEmpty);
    });

    test('an invalid rewrite keeps the note, clears the flag, puts the previous style back and says so', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', '**Plan**\n\n- Plan the release.', [x], style: 'bullets'));
      app().read(synthesisRepositoryProvider);
      engine.responder = (p) => '';

      await actions().applyStyle('s1', 'journal');
      expect(await runs.single, SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.synthesizedContent, '**Plan**\n\n- Plan the release.');
      expect(s.isReprocessing, isFalse);
      expect(s.appliedStyleId, 'bullets');
      expect(notices.single.clusterId, 's1');
      expect(notices.single.message, 'Could not rewrite this note as "Journal entry". It is unchanged.');
      await app().read(synthesisRepositoryProvider.notifier).pendingWrites;
      expect((await store.loadAll()).single.appliedStyleId, 'bullets');
    });

    test('a session too long for a short summary is reported as such without asking the model', () async {
      final x = await thought(List.filled(300, 'word').join(' '), 0, state: ThoughtState.synthesized);
      final y = await thought(List.filled(300, 'more').join(' '), 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x, y]));
      app().read(synthesisRepositoryProvider);

      await actions().applyStyle('s1', 'concise');
      expect(await runs.single, SynthesisRunResult.completed);

      expect(engine.prompts, isEmpty);
      expect(sessions().single.synthesizedContent, 'Old.');
      expect(sessions().single.appliedStyleId, 'organised');
      expect(sessions().single.isReprocessing, isFalse);
      expect(notices.single.message, 'This note is too long for a short summary. It is unchanged.');
    });

    test('a restyle that cannot run now stays pending and still restores the previous style when it fails later',
        () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], style: 'casual'));
      app().read(synthesisRepositoryProvider);
      final a = actions();
      captureActive = true;

      await a.applyStyle('s1', 'journal');
      expect(await runs.single, SynthesisRunResult.busy);
      expect(sessions().single.isReprocessing, isTrue);
      expect(sessions().single.appliedStyleId, 'journal');

      // A second style before the first was written: the note is still the casual one.
      captureActive = false;
      engine.responder = (p) => '';
      await a.applyStyle('s1', 'bullets');
      expect(await runs.last, SynthesisRunResult.completed);

      expect(sessions().single.appliedStyleId, 'casual');
      expect(notices.single.message, 'Could not rewrite this note as "Key points". It is unchanged.');
    });

    test('a restyle not known to this launch (after a restart) falls back to organised when it fails', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], reprocessing: true, style: 'journal'));
      app().read(synthesisRepositoryProvider);
      final a = actions();
      engine.responder = (p) => '';

      expect(await runner(onRewriteFinished: a.rewriteFinished).run(manual: false), SynthesisRunResult.completed);

      expect(sessions().single.appliedStyleId, 'organised');
      expect(sessions().single.synthesizedContent, 'Old.');
      expect(notices.single.message, 'Could not rewrite this note as "Journal entry". It is unchanged.');
    });

    test('a failed rewrite of an organised note changes no style and publishes nothing', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], reprocessing: true));
      app().read(synthesisRepositoryProvider);
      final a = actions();
      engine.responder = (p) => '';

      expect(await runner(onRewriteFinished: a.rewriteFinished).run(manual: false), SynthesisRunResult.completed);

      expect(sessions().single.appliedStyleId, 'organised');
      expect(notices, isEmpty);
    });

    test('a valid restyle forgets the previous style, so a later failed rewrite keeps the chosen one', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x, y]));
      app().read(synthesisRepositoryProvider);
      final a = actions();

      await a.applyStyle('s1', 'journal');
      expect(await runs.single, SynthesisRunResult.completed);
      expect(sessions().single.appliedStyleId, 'journal');

      // A thought edit later flags a rewrite that fails: the journal style stays chosen, no notice.
      app().read(synthesisRepositoryProvider.notifier).updateThoughtText(y.id, 'Move it to Tuesday.');
      engine.responder = (p) => '';
      expect(await runner(onRewriteFinished: a.rewriteFinished).run(manual: false), SynthesisRunResult.completed);
      expect(sessions().single.appliedStyleId, 'journal');
      expect(sessions().single.isReprocessing, isFalse);
      expect(notices, isEmpty);
    });

    test('the notice provider publishes and clears; the actions provider is built from the app', () async {
      final c = app();
      await c.read(synthesisRepositoryProvider.notifier).hydrated;
      c.read(restyleNoticeProvider.notifier).publish(const RestyleNotice(clusterId: 's1', message: 'm'));
      expect(c.read(restyleNoticeProvider)?.clusterId, 's1');
      c.read(restyleNoticeProvider.notifier).clear();
      expect(c.read(restyleNoticeProvider), isNull);
      expect(c.read(sessionActionsProvider), isA<SessionActions>());
    });
  });

  group('a note edited by hand', () {
    late List<RestyleNotice> notices;
    late List<Future<SynthesisRunResult>> runs;
    const mine = '**My plan**\n\nI wrote this myself.';

    setUp(() {
      notices = [];
      runs = [];
    });

    SessionActions actions({List<FolderDefinition> folders = defaultFolders}) {
      late SessionActions a;
      final r = runner(folders: () async => folders, onRewriteFinished: (id, style, f) => a.rewriteFinished(id, style, f));
      return a = SessionActions(
        sessions: app().read(synthesisRepositoryProvider.notifier),
        startRun: () {
          final run = r.run(manual: true);
          runs.add(run);
          return run;
        },
        notify: notices.add,
        folders: () async => folders,
      );
    }

    ThoughtActions thoughtActions() => ThoughtActions(
          notes: notes,
          sessions: app().read(synthesisRepositoryProvider.notifier),
          startRewrite: () {
            final run = runner().run(manual: true);
            runs.add(run);
            return run;
          },
        );

    /// Write turns answer as an organised note: a title and one bullet per thought, verbatim.
    String organisedReply(String p) =>
        isOrganise(p) ? defaultReply(p) : '**New bits**\n\n${promptThoughts(p).map((t) => '- $t').join('\n')}';

    test('editing the text stores it as given, marks it edited by hand, keeps it read and starts no run', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x], reprocessing: true, style: 'journal'));
      app().read(synthesisRepositoryProvider);

      expect(await actions().editNoteText('s1', '  $mine\n\n  \n'), NoteTextEdit.saved);

      final s = sessions().single;
      expect(s.synthesizedContent, '  $mine');
      expect(s.appliedStyleId, manualStyleId);
      expect(s.isHandEdited, isTrue);
      expect(s.isReprocessing, isFalse);
      expect(s.isUnread, isFalse);
      expect(runs, isEmpty);
      await app().read(synthesisRepositoryProvider.notifier).pendingWrites;
      expect((await store.loadAll()).single.appliedStyleId, manualStyleId);
    });

    test('an unread note stays unread after a hand edit', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x]).copyWith(isUnread: true));
      app().read(synthesisRepositoryProvider);

      expect((await actions().editNoteText('s1', mine)).accepted, isTrue);

      expect(sessions().single.isUnread, isTrue);
    });

    test('an empty text is refused and changes nothing; so is an unknown session', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Old.', [x]));
      app().read(synthesisRepositoryProvider);
      final a = actions();

      expect(await a.editNoteText('s1', '   \n\t '), NoteTextEdit.empty);
      expect(await a.editNoteText('s1', ''), NoteTextEdit.empty);
      expect(await a.editNoteText('nope', mine), NoteTextEdit.notFound);
      expect(NoteTextEdit.empty.accepted, isFalse);
      expect(NoteTextEdit.notFound.accepted, isFalse);

      expect(sessions().single.synthesizedContent, 'Old.');
      expect(sessions().single.appliedStyleId, 'organised');
    });

    test('a hand-edited note is never rewritten by the flagged pass, and a stale flag is cleared', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x], reprocessing: true, style: manualStyleId));

      expect(await runner().run(manual: true), SynthesisRunResult.nothingToDo);

      expect(engine.prompts, isEmpty);
      final s = sessions().single;
      expect(s.synthesizedContent, mine);
      expect(s.appliedStyleId, manualStyleId);
      expect(s.isReprocessing, isFalse);
    });

    test('a hand-edited note flagged during a run that has thoughts waiting is skipped too', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x], reprocessing: true, style: manualStyleId));
      await thought('Clean the home office.', 300);

      expect(await runner().run(manual: true), SynthesisRunResult.completed);

      final s = sessions().firstWhere((c) => c.clusterId == 's1');
      expect(s.synthesizedContent, mine);
      expect(s.isReprocessing, isFalse);
      expect(engine.prompts.where((p) => !isOrganise(p)), hasLength(1), reason: 'only the new Personal note');
    });

    test('deleting or editing one of its thoughts updates the thoughts but never flags it', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x, y], style: manualStyleId));
      app().read(synthesisRepositoryProvider);

      await thoughtActions().editText(x, 'Plan the big release.');
      await thoughtActions().delete(y);

      expect(runs, isEmpty);
      final s = sessions().single;
      expect(s.originNotes.map((o) => '${o.id} ${o.cleanedText}'), ['${x.id} Plan the big release.']);
      expect(s.synthesizedContent, mine);
      expect(s.isReprocessing, isFalse);
      expect(s.appliedStyleId, manualStyleId);

      await thoughtActions().delete(x);
      expect(sessions(), isEmpty, reason: 'a session left without thoughts is removed, as for any note');
    });

    test('new thoughts are written alone, organised, and appended under Added later; the note is marked unread',
        () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x], style: manualStyleId));
      final a = await thought('Move it to Monday.', 10);
      engine.responder = organisedReply;

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      final write = engine.prompts.where((p) => !isOrganise(p)).single;
      expect(write, contains(noteStyleById('organised').systemPrompt));
      expect(promptThoughts(write), ['Move it to Monday.']);
      var s = sessions().single;
      expect(s.synthesizedContent, '$mine\n\n**Added later**\n\n- Move it to Monday.');
      expect(s.appliedStyleId, manualStyleId);
      expect(s.isUnread, isTrue);
      expect(s.isReprocessing, isFalse);
      expect(s.originNotes.map((o) => o.id), [x.id, a.id]);
      expect((await reload(a)).state, ThoughtState.synthesized);

      // A second time: under the same heading.
      final b = await thought('Tell the team.', 20);
      expect(await runner().run(manual: false), SynthesisRunResult.completed);
      s = sessions().single;
      expect(s.synthesizedContent, '$mine\n\n**Added later**\n\n- Move it to Monday.\n\n- Tell the team.');
      expect(s.originNotes.map((o) => o.id), [x.id, a.id, b.id]);
      expect(s.isReprocessing, isFalse);
    });

    test('an invalid reply for new thoughts appends nothing and leaves them in Capture', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x], style: manualStyleId));
      final a = await thought('Move it to Monday.', 10);
      engine.responder = (p) => isOrganise(p) ? defaultReply(p) : '';

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.synthesizedContent, mine);
      expect(s.originNotes.map((o) => o.id), [x.id]);
      expect(s.appliedStyleId, manualStyleId);
      final r = await reload(a);
      expect(r.state, ThoughtState.processed);
      expect(r.synthesisAttempts, 1);
    });

    test('a note edited by hand while its new thoughts are written keeps the edit; they are filed next run',
        () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', 'Plan the release.', [x]));
      final a = await thought('Move it to Monday.', 10);
      final gate = Completer<void>();
      final writeSent = Completer<void>();
      engine.responder = (p) async {
        if (!isOrganise(p) && !writeSent.isCompleted) {
          writeSent.complete();
          await gate.future;
        }
        return organisedReply(p);
      };
      final acts = actions();

      final run = runner().run(manual: false);
      await writeSent.future;
      expect(await acts.editNoteText('s1', mine), NoteTextEdit.saved);
      gate.complete();

      expect(await run, SynthesisRunResult.completed);
      expect(sessions().single.synthesizedContent, mine);
      expect(sessions().single.originNotes.map((o) => o.id), [x.id]);
      expect((await reload(a)).state, ThoughtState.processed);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);
      expect(sessions().single.synthesizedContent, '$mine\n\n**Added later**\n\n- Move it to Monday.');
      expect((await reload(a)).state, ThoughtState.synthesized);
    });

    test('choosing a style regenerates it from all its thoughts', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      final y = await thought('Move it to Monday.', 10, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x, y], style: manualStyleId));
      app().read(synthesisRepositoryProvider);

      await actions().applyStyle('s1', 'journal');
      expect(await runs.single, SynthesisRunResult.completed);

      expect(engine.prompts.single, contains(noteStyleById('journal').systemPrompt));
      expect(promptThoughts(engine.prompts.single), ['Plan the release.', 'Move it to Monday.']);
      final s = sessions().single;
      expect(s.synthesizedContent, 'Plan the release. Move it to Monday.');
      expect(s.appliedStyleId, 'journal');
      expect(s.isHandEdited, isFalse);
      expect(notices, isEmpty);
    });

    test('a restyle that fails puts back the hand-edited text and style and says so', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x], style: manualStyleId));
      app().read(synthesisRepositoryProvider);
      engine.responder = (p) => '';

      await actions().applyStyle('s1', 'organised');
      expect(await runs.single, SynthesisRunResult.completed);

      final s = sessions().single;
      expect(s.synthesizedContent, mine);
      expect(s.appliedStyleId, manualStyleId);
      expect(s.isReprocessing, isFalse);
      expect(notices.single.message, 'Could not rewrite this note as "Organised". It is unchanged.');
    });

    test('moving it to a folder with another default style only changes its folder', () async {
      final x = await thought('Plan the release.', 0, state: ThoughtState.synthesized);
      await storeSession(session('s1', 'Work', mine, [x], style: manualStyleId));
      app().read(synthesisRepositoryProvider);

      await actions(folders: const [
        FolderDefinition(name: 'Work', description: 'w'),
        FolderDefinition(name: 'Personal', description: 'p', defaultStyleId: 'journal'),
        FolderDefinition(name: 'Uncategorized', description: 'u'),
      ]).moveToFolder('s1', 'Personal');

      final s = sessions().single;
      expect(s.folder, 'Personal');
      expect(s.appliedStyleId, manualStyleId);
      expect(s.synthesizedContent, mine);
      expect(s.isReprocessing, isFalse);
      expect(runs, isEmpty);
    });
  });

  group('folders', () {
    test('a folder added before a run is offered in the organise prompt and its grammar', () async {
      await thought('Water the tomatoes.', 0);
      final c = app();
      final folderNotifier = c.read(foldersProvider.notifier);
      await folderNotifier.loaded;
      expect(await folderNotifier.add('Garden', 'plants and the allotment.'), FolderChange.done);
      engine.responder = (p) => isOrganise(p) ? '1: Garden' : defaultReply(p);

      expect(await runner(folders: () async => c.read(foldersProvider)).run(manual: false),
          SynthesisRunResult.completed);

      expect(engine.prompts.first, contains('- Garden: plants and the allotment.'));
      expect(engine.grammars.first, contains('"Garden"'));
      expect(sessions().single.folder, 'Garden');
    });

    test('the folders are resolved once per run', () async {
      await thought('Water the tomatoes.', 0);
      var calls = 0;

      await runner(folders: () async {
        calls++;
        return defaultFolders;
      }).run(manual: false);

      expect(calls, 1);
    });

    test('a reply naming a folder not in the list is invalid', () async {
      final a = await thought('Water the tomatoes.', 0);
      engine.responder = (p) => isOrganise(p) ? '1: Garden' : defaultReply(p);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(sessions(), isEmpty);
      expect((await reload(a)).state, ThoughtState.processed);
    });
  });

  group('attempt counting', () {
    test('a thought the model could not file counts one attempt per run: 1 after the first, 2 after the second', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.responder = (p) => isOrganise(p) ? 'no idea' : defaultReply(p);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);
      expect((await reload(a)).synthesisAttempts, 1);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);
      expect((await reload(a)).synthesisAttempts, 2);
      expect((await reload(a)).state, ThoughtState.processed);
    });

    test('a thought synthesized on a later run has its counter reset to 0', () async {
      final a = await thought('Refactor the queue.', 0);
      engine.responder = (p) => isOrganise(p) ? 'no idea' : defaultReply(p);
      await runner().run(manual: false);
      expect((await reload(a)).synthesisAttempts, 1);

      engine.responder = defaultReply;
      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      final r = await reload(a);
      expect(r.state, ThoughtState.synthesized);
      expect(r.synthesisAttempts, 0);
    });

    test('the attempt is persisted before the first model call, so a run that dies is still counted', () async {
      final a = await thought('Refactor the queue.', 0);
      final b = await thought('Clean the home office.', 5, attempts: 1);
      List<(int, int)>? savesAtFirstPrompt;
      engine.onPrompt = (p) => savesAtFirstPrompt ??= List.of(notes.saves);

      expect(await runner().run(manual: false), SynthesisRunResult.completed);

      expect(savesAtFirstPrompt, isNotNull);
      expect(savesAtFirstPrompt!.where((s) => s.$1 == a.id).last.$2, 1);
      expect(savesAtFirstPrompt!.where((s) => s.$1 == b.id).last.$2, 2);
    });

    test('a failing model load counts an attempt for every candidate', () async {
      final a = await thought('Refactor the queue.', 0);
      final b = await thought('Clean the home office.', 5, attempts: 1);
      engine.loadError = Exception('out of memory');

      expect(await runner().run(manual: false), SynthesisRunResult.failed);

      expect((await reload(a)).synthesisAttempts, 1);
      expect((await reload(b)).synthesisAttempts, 2);
    });

    test('a failing model call counts an attempt for every candidate', () async {
      final a = await thought('Refactor the queue.', 0);
      final b = await thought('Clean the home office.', 5);
      engine.responder = (p) => throw Exception('native fault');

      expect(await runner().run(manual: false), SynthesisRunResult.failed);

      expect((await reload(a)).synthesisAttempts, 1);
      expect((await reload(b)).synthesisAttempts, 1);
    });

    test('a preempted run takes its attempts back and leaves the counters unchanged', () async {
      final a = await thought('Refactor the queue.', 0, attempts: 1);
      final b = await thought('Clean the home office.', 5);
      final held = Completer<void>();
      engine.responder = (p) {
        held.complete();
        return null;
      };

      final run = runner().run(manual: false);
      await held.future;
      expect((await reload(a)).synthesisAttempts, 2, reason: 'counted while the run is in progress');
      await lifecycle.ensureModelsLoaded(reason: 'recording');

      expect(await run, SynthesisRunResult.preempted);
      expect((await reload(a)).synthesisAttempts, 1);
      expect((await reload(b)).synthesisAttempts, 0);
      expect((await reload(a)).state, ThoughtState.processed);
    });

    test('a preempted run keeps the committed thoughts reset and restores only the waiting ones', () async {
      final a = await thought('Refactor the queue.', 0, attempts: 2);
      final b = await thought('Clean the home office.', 5, attempts: 2);
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
      final ra = await reload(a);
      expect(ra.state, ThoughtState.synthesized);
      expect(ra.synthesisAttempts, 0);
      final rb = await reload(b);
      expect(rb.state, ThoughtState.processed);
      expect(rb.synthesisAttempts, 2);
    });

    test('a thought without attempts never goes below 0 when the run is preempted', () async {
      final a = await thought('Refactor the queue.', 0);
      final held = Completer<void>();
      engine.responder = (p) {
        held.complete();
        return null;
      };

      final run = runner().run(manual: false);
      await held.future;
      // Something reset the counter while the run was in progress.
      (await reload(a)).synthesisAttempts = 0;
      await lifecycle.ensureModelsLoaded(reason: 'recording');

      expect(await run, SynthesisRunResult.preempted);
      expect((await reload(a)).synthesisAttempts, 0);
    });
  });

  group('CPU wake lock', () {
    List<String> events() =>
        log.where((e) => e.startsWith('wake') || e.startsWith('llm') || e == 'prompt').toList();

    test('a completed run holds the CPU before the model load and every model call, then releases after the model is freed',
        () async {
      await thought('Refactor the queue.', 0);
      await thought('Clean the home office.', 5);
      engine.onPrompt = (p) => log.add('prompt');
      final wake = FakeCpuWakeLock(log);

      expect(await runner(wakeLock: wake).run(manual: false), SynthesisRunResult.completed);

      final e = events();
      expect(e.first, 'wake-hold');
      expect(e.last, 'wake-release');
      expect(e.where((x) => x == 'wake-release'), hasLength(1));
      final load = e.indexWhere((x) => x.startsWith('llm-load'));
      expect(e[load - 1], 'wake-hold');
      final prompts = [for (var i = 0; i < e.length; i++) if (e[i] == 'prompt') i];
      expect(prompts, hasLength(3));
      for (final i in prompts) {
        expect(e[i - 1], 'wake-hold', reason: 'a hold directly precedes the model call at $i');
      }
      expect(e.lastIndexOf('llm-dispose'), lessThan(e.lastIndexOf('wake-release')));
      expect(wake.holds.toSet(), {SynthesisRunner.wakeLockWindow});
    });

    test('a preempted run still releases once, after the model is freed', () async {
      await thought('Refactor the queue.', 0);
      final held = Completer<void>();
      engine.responder = (p) {
        held.complete();
        return null;
      };
      final wake = FakeCpuWakeLock(log);

      final run = runner(wakeLock: wake).run(manual: false);
      await held.future;
      await lifecycle.ensureModelsLoaded(reason: 'recording');
      expect(await run, SynthesisRunResult.preempted);

      final e = events();
      expect(e.last, 'wake-release');
      expect(e.where((x) => x == 'wake-release'), hasLength(1));
      expect(e.lastIndexOf('llm-dispose'), lessThan(e.lastIndexOf('wake-release')));
    });

    test('a run preempted during the model load releases once and never asks the model', () async {
      await thought('Refactor the queue.', 0);
      engine.loadGate = Completer<void>();
      final wake = FakeCpuWakeLock(log);

      final run = runner(wakeLock: wake).run(manual: false);
      await until(() => log.any((e) => e.startsWith('llm-load')));
      final speech = lifecycle.ensureModelsLoaded(reason: 'recording');
      engine.loadGate!.complete();

      expect(await run, SynthesisRunResult.preempted);
      await speech;
      final e = events();
      expect(e.last, 'wake-release');
      expect(e.where((x) => x == 'wake-release'), hasLength(1));
      expect(engine.prompts, isEmpty);
    });

    test('a recording that arrives while the run is still preparing preempts it before any model is loaded', () async {
      final a = await thought('Refactor the queue.', 0);
      final wake = FakeCpuWakeLock(log)..firstHoldGate = Completer<void>();

      final run = runner(wakeLock: wake).run(manual: false);
      await until(() => wake.holds.isNotEmpty);
      await lifecycle.ensureModelsLoaded(reason: 'recording');
      wake.firstHoldGate!.complete();

      expect(await run, SynthesisRunResult.preempted);
      expect(log.where((e) => e.startsWith('llm-load')), isEmpty);
      expect(arbiter.holder, HeavyModel.speech);
      expect(log.last, 'wake-release');
      expect((await reload(a)).synthesisAttempts, 0);
    });

    test('a run whose model call throws still releases', () async {
      await thought('Refactor the queue.', 0);
      engine.responder = (p) => throw Exception('native fault');
      final wake = FakeCpuWakeLock(log);

      expect(await runner(wakeLock: wake).run(manual: false), SynthesisRunResult.failed);

      final e = events();
      expect(e.first, 'wake-hold');
      expect(e.last, 'wake-release');
      expect(e.where((x) => x == 'wake-release'), hasLength(1));
      expect(e.lastIndexOf('llm-dispose'), lessThan(e.lastIndexOf('wake-release')));
    });

    test('a run whose model load throws still releases', () async {
      await thought('Refactor the queue.', 0);
      engine.loadError = Exception('out of memory');
      final wake = FakeCpuWakeLock(log);

      expect(await runner(wakeLock: wake).run(manual: false), SynthesisRunResult.failed);

      final e = events();
      expect(e.first, 'wake-hold');
      expect(e.last, 'wake-release');
      expect(e.where((x) => x == 'wake-release'), hasLength(1));
    });

    test('busy and nothing-to-do results never touch the wake lock', () async {
      final wake = FakeCpuWakeLock(log);

      expect(await runner(wakeLock: wake).run(manual: true), SynthesisRunResult.nothingToDo);

      await thought('Refactor the queue.', 0);
      captureActive = true;
      expect(await runner(wakeLock: wake).run(manual: true), SynthesisRunResult.busy);
      captureActive = false;

      await arbiter.acquireSpeech();
      expect(await runner(wakeLock: wake).run(manual: true), SynthesisRunResult.busy);

      expect(log.where((e) => e.startsWith('wake')), isEmpty);
      expect(wake.holds, isEmpty);
    });
  });
}
