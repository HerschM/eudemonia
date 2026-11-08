import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llm_service.dart';
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

  ModelLifecycleState _state = ModelLifecycleState.unloaded;
  Completer<void>? _loadingCompleter;
  Timer? _inactivityTimer;
  DateTime? _lastActiveTime;
  DateTime? _lastLoadedTime;

  ModelLifecycleManager(
    this._sttService,
    this._llmService, {
    LLMConfig? config,
    this._logger,
    this._modelsDirResolver,
  })  : _config = config ?? const LLMConfig();

  ModelLifecycleState get state => _state;
  bool get areModelsLoaded => _state == ModelLifecycleState.ready;
  DateTime? get lastActiveTime => _lastActiveTime;
  DateTime? get lastLoadedTime => _lastLoadedTime;
  LLMConfig get config => _config;

  /// Ensures both STT and LLM models are mapped and initialized in RAM.
  /// If already loaded, returns immediately.
  /// If loading is in progress, awaits the active Future (thread-safe, idempotent).
  Future<void> ensureModelsLoaded({String reason = 'demand'}) async {
    _lastActiveTime = DateTime.now();

    // Cancel pending eviction countdown because activity is occurring
    _cancelInactivityTimer();

    if (_state == ModelLifecycleState.ready) {
      _logger?.info('[ModelLifecycle] Models already loaded in RAM (Reason: $reason). Zero reload overhead.');
      return;
    }

    if (_state == ModelLifecycleState.loading && _loadingCompleter != null) {
      _logger?.info('[ModelLifecycle] Awaiting active model loading task (Reason: $reason)...');
      return _loadingCompleter!.future;
    }

    _state = ModelLifecycleState.loading;
    _loadingCompleter = Completer<void>();

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

      // Load models sequentially to prevent simultaneous memory spikes and OS OOM kills
      _logger?.info('[ModelLifecycle] Step 1/2: Initializing Sherpa-ONNX STT model...');
      await _sttService.initialize(sttModelPath);

      _logger?.info('[ModelLifecycle] Step 2/2: Initializing Qwen GGUF LLM model...');
      await _llmService.initialize(llmModelPath);

      stopwatch.stop();
      _state = ModelLifecycleState.ready;
      _lastLoadedTime = DateTime.now();

      _logger?.info('================ [ModelLifecycle State Transition] ================');
      _logger?.info('[ModelLifecycle] STATE CHANGE: Loading -> Ready');
      _logger?.info('[ModelLifecycle] Total Load Duration: ${stopwatch.elapsedMilliseconds}ms');
      _logger?.info('[ModelLifecycle] Estimated RAM Consumed: ~1.6 GB');
      _logger?.info('===================================================================');

      _loadingCompleter?.complete();
    } catch (e, stack) {
      stopwatch.stop();
      _state = ModelLifecycleState.unloaded;
      _logger?.error('[ModelLifecycle] ERROR during model loading', error: e, stackTrace: stack);
      _loadingCompleter?.completeError(e, stack);
      rethrow;
    } finally {
      _loadingCompleter = null;
    }
  }

  /// Proactively pre-warms the models in the background the moment audio recording starts.
  /// Runs concurrently without blocking the audio capture thread.
  void warmupOnRecordingStart() {
    _lastActiveTime = DateTime.now();
    _cancelInactivityTimer();

    if (_state == ModelLifecycleState.ready) {
      _logger?.info('[ModelLifecycle] Warmup requested: Models already hot in RAM.');
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

  /// Evicts both LLM and STT models from RAM immediately, freeing ~1.6 GB of memory.
  Future<void> evictModels({String reason = 'manual eviction'}) async {
    _cancelInactivityTimer();

    if (_state == ModelLifecycleState.unloaded) {
      _logger?.info('[ModelLifecycle] evictModels() called but models are already unloaded.');
      return;
    }

    _logger?.info('================ [ModelLifecycle State Transition] ================');
    _logger?.info('[ModelLifecycle] STATE CHANGE: Ready -> Unloaded (Eviction)');
    _logger?.info('[ModelLifecycle] Eviction Reason: $reason');
    _logger?.info('[ModelLifecycle] Disposing STTService & LLMService native handles...');

    try {
      _sttService.dispose();
      _llmService.dispose();
      _state = ModelLifecycleState.unloaded;
      _logger?.info('[ModelLifecycle] Models successfully unloaded from RAM.');
      _logger?.info('[ModelLifecycle] Memory Reclaimed: ~1.6 GB RAM. App footprint returned to baseline (<60 MB).');
    } catch (e) {
      _logger?.error('[ModelLifecycle] Error during eviction', error: e);
      _state = ModelLifecycleState.unloaded;
    }
    _logger?.info('===================================================================');
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

final modelLifecycleManagerProvider = Provider<ModelLifecycleManager>((ref) {
  final sttService = ref.watch(sttServiceProvider);
  final llmService = ref.watch(llmServiceProvider);
  final config = ref.watch(llmConfigProvider);
  final logger = ref.watch(appLoggerProvider);
  return ModelLifecycleManager(sttService, llmService, config: config, logger: logger);
});
