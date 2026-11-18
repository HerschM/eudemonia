import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llm_service.dart';
import 'model_file_validator.dart';
import 'model_load_guard.dart';
import 'stt_service.dart';

/// Represents the memory state of AI models (LLM and STT).
enum ModelLifecycleState {
  /// Both models are cleared from RAM (<60 MB baseline app footprint).
  unloaded,

  /// Models are currently being loaded into memory from disk.
  loading,

  /// Models are resident in memory and ready for zero-latency inference (~1.6 GB RAM).
  ready,
}

/// Central orchestrator managing the memory lifecycle, inactivity eviction, and
/// on-demand pre-warming of on-device LLM (Qwen-2.5) and STT (Parakeet v3) models.
class ModelLifecycleManager {
  final STTService _sttService;
  final LLMService _llmService;
  final LLMConfig _config;
  final AppLogger? _logger;
  final Future<String?> Function()? _modelsDirResolver;
  final void Function(ModelLifecycleState state)? _onStateChanged;
  final ModelFileValidator? _fileValidator;
  final ModelLoadGuard? _loadGuard;

  ModelLifecycleState _state = ModelLifecycleState.unloaded;
  Future<void>? _loadFuture;
  Timer? _inactivityTimer;
  DateTime? _lastActiveTime;
  DateTime? _lastLoadedTime;

  /// Number of in-flight inference tasks holding the models in RAM.
  int _activeUsers = 0;
  String? _deferredEvictionReason;

  ModelLifecycleManager(
    this._sttService,
    this._llmService, {
    LLMConfig? config,
    this._logger,
    this._modelsDirResolver,
    this._onStateChanged,
    this._fileValidator,
    this._loadGuard,
  })  : _config = config ?? const LLMConfig();

  void _setState(ModelLifecycleState next) {
    if (_state == next) return;
    _state = next;
    _onStateChanged?.call(next);
  }

  ModelLifecycleState get state => _state;
  bool get areModelsLoaded => _state == ModelLifecycleState.ready;
  DateTime? get lastActiveTime => _lastActiveTime;
  DateTime? get lastLoadedTime => _lastLoadedTime;
  LLMConfig get config => _config;

  /// Ensures both STT and LLM models are mapped and initialized in RAM.
  /// If already loaded, returns immediately.
  /// If loading is in progress, awaits the active Future (thread-safe, idempotent).
  Future<void> ensureModelsLoaded({String reason = 'demand'}) {
    _lastActiveTime = DateTime.now();

    // Cancel pending eviction countdown because activity is occurring
    _cancelInactivityTimer();

    if (_state == ModelLifecycleState.ready) {
      _logger?.info('[ModelLifecycle] Models already loaded in RAM (Reason: $reason). Zero reload overhead.');
      return Future.value();
    }

    final active = _loadFuture;
    if (active != null) {
      _logger?.info('[ModelLifecycle] Awaiting active model loading task (Reason: $reason)...');
      return active;
    }

    // Every caller awaits this same future, so a load failure always has a listener.
    return _loadFuture = _loadModels(reason).whenComplete(() => _loadFuture = null);
  }

  Future<void> _loadModels(String reason) async {
    _setState(ModelLifecycleState.loading);

    final stopwatch = Stopwatch()..start();
    _logger?.info('================ [ModelLifecycle State Transition] ================');
    _logger?.info('[ModelLifecycle] STATE CHANGE: Unloaded -> Loading');
    _logger?.info('[ModelLifecycle] Reason: $reason');
    _logger?.info('[ModelLifecycle] Target Models: Sherpa-ONNX Parakeet v3 (~600MB) & Qwen-2.5 1.5B GGUF (~1.0GB)');
    _logger?.info('[ModelLifecycle] Inactivity TTL: ${_config.modelInactivityTtl.inMinutes} minutes');
    _logger?.info('===================================================================');

    try {
      String? modelsDirPath;
      if (_modelsDirResolver != null) {
        modelsDirPath = await _modelsDirResolver();
      } else {
        final extDir = await getExternalStorageDirectory();
        modelsDirPath = extDir?.path;
      }

      if (modelsDirPath == null) {
        throw Exception('Could not resolve models directory path.');
      }

      final sttModelPath = '$modelsDirPath/parakeet';
      final llmModelPath = '$modelsDirPath/qwen2.5-1.5b.gguf';
      final files = ModelFiles(sttModelDir: sttModelPath, llmModelPath: llmModelPath);

      // The native runtimes abort the process on a malformed file, so reject what we can first.
      await _fileValidator?.validate(files);

      // Whatever validation cannot see is contained by the crash-loop guard.
      final guard = _loadGuard;
      if (guard != null) await guard.begin(await files.signature());
      try {
        // Load models sequentially to prevent simultaneous memory spikes and OS OOM kills
        _logger?.info('[ModelLifecycle] Step 1/2: Initializing Sherpa-ONNX STT model...');
        await _sttService.initialize(sttModelPath);

        _logger?.info('[ModelLifecycle] Step 2/2: Initializing Qwen GGUF LLM model...');
        await _llmService.initialize(llmModelPath);
      } finally {
        // Reaching this line means the process survived the native load.
        await guard?.finish();
      }

      stopwatch.stop();
      _lastLoadedTime = DateTime.now();
      _setState(ModelLifecycleState.ready);

      _logger?.info('================ [ModelLifecycle State Transition] ================');
      _logger?.info('[ModelLifecycle] STATE CHANGE: Loading -> Ready');
      _logger?.info('[ModelLifecycle] Total Load Duration: ${stopwatch.elapsedMilliseconds}ms');
      _logger?.info('[ModelLifecycle] Estimated RAM Consumed: ~1.6 GB');
      _logger?.info('===================================================================');
    } catch (e, stack) {
      stopwatch.stop();
      _logger?.error('[ModelLifecycle] ERROR during model loading', error: e, stackTrace: stack);
      // A half-finished load must not strand one model in RAM.
      _disposeServices();
      _setState(ModelLifecycleState.unloaded);
      rethrow;
    }
  }

  /// Lifts a crash-loop block so the next load is attempted. Called for explicit user retries.
  Future<void> allowLoadRetry() async {
    await _loadGuard?.clearBlock();
  }

  /// Runs [task] with both models resident in RAM. Eviction is held off until
  /// the task finishes, then the inactivity countdown restarts.
  Future<T> runWithModels<T>(Future<T> Function() task, {String reason = 'demand'}) async {
    await ensureModelsLoaded(reason: reason);
    _activeUsers++;
    try {
      return await task();
    } finally {
      _activeUsers--;
      final deferredReason = _deferredEvictionReason;
      if (_activeUsers == 0 && deferredReason != null) {
        await evictModels(reason: deferredReason);
      } else {
        touch(reason: 'Finished: $reason');
      }
    }
  }

  /// Proactively pre-warms the models in the background the moment audio recording starts.
  /// Runs concurrently without blocking the audio capture thread.
  void warmupOnRecordingStart() {
    _lastActiveTime = DateTime.now();
    _cancelInactivityTimer();

    if (_state == ModelLifecycleState.ready) {
      _logger?.info('[ModelLifecycle] Warmup requested: Models already hot in RAM.');
      touch(reason: 'Warmup requested while models already loaded');
      return;
    }

    _logger?.info('[ModelLifecycle] Proactive warmup initiated on recording start.');
    ensureModelsLoaded(reason: 'Recording started (proactive pre-warm)').catchError((e) {
      _logger?.warning('[ModelLifecycle] Non-fatal background warmup warning: $e');
    });
  }

  /// Resets the inactivity timer countdown after audio recording or note processing finishes.
  void touch({String reason = 'activity'}) {
    _lastActiveTime = DateTime.now();
    _cancelInactivityTimer();

    if (_state != ModelLifecycleState.ready) {
      _logger?.info('[ModelLifecycle] touch() called but models are not loaded (state: $_state).');
      return;
    }

    final ttl = _config.modelInactivityTtl;
    _logger?.info('[ModelLifecycle] Activity recorded ($reason). Resetting inactivity timer.');
    _logger?.info('[ModelLifecycle] Inactivity TTL countdown started: ${ttl.inMinutes}m 00s until automatic eviction.');

    _inactivityTimer = Timer(ttl, () async {
      _logger?.info('[ModelLifecycle] Inactivity TTL expired (${ttl.inMinutes}m of zero activity). Initiating model eviction.');
      await evictModels(reason: 'Inactivity TTL expired (${ttl.inMinutes}m idle)');
    });
  }

  /// Evicts both LLM and STT models from RAM, freeing ~1.6 GB of memory.
  ///
  /// Returns `true` once the models are out of RAM. If inference is in flight,
  /// eviction is deferred until it finishes and this returns `false`.
  Future<bool> evictModels({String reason = 'manual eviction'}) async {
    _cancelInactivityTimer();

    // Let an in-progress load settle so its handles are released too.
    final loading = _loadFuture;
    if (loading != null) {
      try {
        await loading;
      } catch (_) {}
      _cancelInactivityTimer();
    }

    if (_state == ModelLifecycleState.unloaded) {
      _logger?.info('[ModelLifecycle] evictModels() called but models are already unloaded.');
      return true;
    }

    if (_activeUsers > 0) {
      _logger?.info('[ModelLifecycle] Eviction deferred until in-flight inference completes (Reason: $reason).');
      _deferredEvictionReason = reason;
      return false;
    }
    _deferredEvictionReason = null;

    _logger?.info('================ [ModelLifecycle State Transition] ================');
    _logger?.info('[ModelLifecycle] STATE CHANGE: Ready -> Unloaded (Eviction)');
    _logger?.info('[ModelLifecycle] Eviction Reason: $reason');
    _logger?.info('[ModelLifecycle] Disposing STTService & LLMService native handles...');

    _disposeServices();
    _setState(ModelLifecycleState.unloaded);
    _logger?.info('[ModelLifecycle] Models successfully unloaded from RAM.');
    _logger?.info('[ModelLifecycle] Memory Reclaimed: ~1.6 GB RAM. App footprint returned to baseline (<60 MB).');
    _logger?.info('===================================================================');
    return true;
  }

  void _disposeServices() {
    try {
      _sttService.dispose();
    } catch (e) {
      _logger?.error('[ModelLifecycle] Error disposing STT model', error: e);
    }
    try {
      _llmService.dispose();
    } catch (e) {
      _logger?.error('[ModelLifecycle] Error disposing LLM model', error: e);
    }
  }

  void _cancelInactivityTimer() {
    if (_inactivityTimer != null && _inactivityTimer!.isActive) {
      _inactivityTimer!.cancel();
      _inactivityTimer = null;
    }
  }

  /// Diagnostic state dump for debugging and telemetry.
  Map<String, dynamic> getDiagnosticState() {
    return {
      'state': _state.name,
      'isSTTInitialized': _sttService.isInitialized,
      'isLLMInitialized': _llmService.isInitialized,
      'completedTurnsCount': _llmService.completedTurnsCount,
      'lastActiveTime': _lastActiveTime?.toIso8601String(),
      'lastLoadedTime': _lastLoadedTime?.toIso8601String(),
      'isTimerActive': _inactivityTimer?.isActive ?? false,
      'inactivityTtlMinutes': _config.modelInactivityTtl.inMinutes,
      'kvCacheMaxSize': _config.kvCacheMaxSize,
      'clearKvCacheEveryXTurns': _config.clearKvCacheEveryXTurns,
    };
  }

  void printDiagnosticDump() {
    _logger?.info('---------------- [ModelLifecycle Diagnostic Dump] ----------------');
    final dump = getDiagnosticState();
    dump.forEach((k, v) => _logger?.info('  $k: $v'));
    _logger?.info('------------------------------------------------------------------');
  }

  void dispose() {
    _cancelInactivityTimer();
    evictModels(reason: 'ModelLifecycleManager dispose');
  }
}

/// Synchronous mirror of [ModelLifecycleManager.state] for UI telemetry.
class ModelLifecycleStateNotifier extends Notifier<ModelLifecycleState> {
  @override
  ModelLifecycleState build() => ModelLifecycleState.unloaded;

  void setLifecycleState(ModelLifecycleState value) => state = value;
}

final modelLifecycleStateProvider =
    NotifierProvider<ModelLifecycleStateNotifier, ModelLifecycleState>(() {
  return ModelLifecycleStateNotifier();
});

final modelLifecycleManagerProvider = Provider<ModelLifecycleManager>((ref) {
  final sttService = ref.watch(sttServiceProvider);
  final llmService = ref.watch(llmServiceProvider);
  final config = ref.watch(llmConfigProvider);
  final logger = ref.watch(appLoggerProvider);
  final manager = ModelLifecycleManager(
    sttService,
    llmService,
    config: config,
    logger: logger,
    fileValidator: const ModelFileValidator(),
    loadGuard: ModelLoadGuard(),
    onStateChanged: (state) {
      ref.read(modelLifecycleStateProvider.notifier).setLifecycleState(state);
    },
  );
  return manager;
});
