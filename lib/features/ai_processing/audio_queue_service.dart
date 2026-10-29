import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

class AudioQueueService {
  final STTService _sttService;
  final LLMService _llmService;
  final NotesRepository _notesRepo;
  final ModelLifecycleManager _modelLifecycle;
  final AppLogger? _logger;
  final Future<File> Function()? _storageFileResolver;
  final void Function(int pending, int failed)? _onQueueChanged;
  final void Function(List<AudioQueueItem> items)? _onItemsChanged;
  final void Function()? _onNoteSaved;

  final List<AudioQueueItem> _items = [];
  bool _isProcessing = false;
  File? _cachedFile;
  Future<void>? _loadingFuture;

  AudioQueueService(
    this._sttService,
    this._llmService,
    this._notesRepo,
    this._modelLifecycle, {
    AppLogger? logger,
    Future<File> Function()? storageFileResolver,
    void Function(int pending, int failed)? onQueueChanged,
    void Function(List<AudioQueueItem> items)? onItemsChanged,
    void Function()? onNoteSaved,
    bool autoLoad = true,
  })  : _logger = logger,
        _storageFileResolver = storageFileResolver,
        _onQueueChanged = onQueueChanged,
        _onItemsChanged = onItemsChanged,
        _onNoteSaved = onNoteSaved {
    if (autoLoad) {
      loadFromStorage();
    }
  }

  List<AudioQueueItem> get items => List.unmodifiable(_items);

  int get pendingCount => _items.where((i) =>
      i.status == AudioQueueStatus.pending ||
      i.status == AudioQueueStatus.transcribing ||
      i.status == AudioQueueStatus.categorizing).length;

  int get failedCount => _items.where((i) => i.status == AudioQueueStatus.failed).length;

  AudioQueueItem? get currentProcessingItem => _items.cast<AudioQueueItem?>().firstWhere(
        (i) => i?.status == AudioQueueStatus.transcribing || i?.status == AudioQueueStatus.categorizing,
        orElse: () => null,
      );

  Future<File> _resolveStorageFile() async {
    if (_cachedFile != null) return _cachedFile!;
    if (_storageFileResolver != null) {
      _cachedFile = await _storageFileResolver();
      return _cachedFile!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final queueDir = Directory('${appDir.path}/queue');
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }
    _cachedFile = File('${queueDir.path}/queue.json');
    return _cachedFile!;
  }

  Future<void> loadFromStorage({bool forceReload = false}) {
    if (forceReload || _loadingFuture == null) {
      _loadingFuture = _loadFromStorage();
    }
    return _loadingFuture!;
  }

  Future<void> _loadFromStorage() async {
    try {
      final file = await _resolveStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _items.clear();
          for (final j in jsonList) {
            try {
              if (j is Map<String, dynamic>) {
                _items.add(AudioQueueItem.fromJson(j));
              } else if (j is Map) {
                _items.add(AudioQueueItem.fromJson(Map<String, dynamic>.from(j)));
              } else {
                _logger?.warning('Quarantining invalid non-map queue entry: $j');
              }
            } catch (itemErr) {
              _logger?.warning('Quarantining corrupt queue item: $itemErr');
            }
          }
          _notifyState();
        }
      }
    } catch (e) {
      _logger?.error('Error loading queue from storage', error: e);
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final file = await _resolveStorageFile();
      final jsonList = _items.map((i) => i.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      _logger?.error('Error saving queue to storage', error: e);
    }
  }

  void _notifyState() {
    _onQueueChanged?.call(pendingCount, failedCount);
    _onItemsChanged?.call(List.unmodifiable(_items));
  }

  Future<AudioQueueItem> enqueue(String audioFilePath, {bool autoProcess = true}) async {
    final item = AudioQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      audioFilePath: audioFilePath,
      recordedAt: DateTime.now(),
      status: AudioQueueStatus.pending,
    );

    _items.add(item);
    await _saveToStorage();
    _notifyState();
    _logger?.info('[AudioQueue] Enqueued new thought: ${item.id} (Total pending: $pendingCount)');

    if (autoProcess) {
      unawaited(processPending());
    }

    return item;
  }

  Future<void> retryFailed() async {
    bool hasFailed = false;
    for (final item in _items) {
      if (item.status == AudioQueueStatus.failed) {
        item.status = AudioQueueStatus.pending;
        item.errorMessage = null;
        hasFailed = true;
      }
    }
    if (hasFailed) {
      await _saveToStorage();
      _notifyState();
      _logger?.info('[AudioQueue] Retrying failed items. (Total pending: $pendingCount)');
      unawaited(processPending());
    }
  }

  Completer<void>? _processingCompleter;

  Future<void> processPending() async {
    if (_isProcessing) {
      if (_processingCompleter != null && !_processingCompleter!.isCompleted) {
        await _processingCompleter!.future;
      }
      return;
    }
    _isProcessing = true;
    _processingCompleter = Completer<void>();

    try {
      while (true) {
        final pendingItems = _items.where((i) => i.status == AudioQueueStatus.pending).toList();
        if (pendingItems.isEmpty) break;

        final nextItem = pendingItems.first;
        await _processSingleItem(nextItem);
      }
    } finally {
      _isProcessing = false;
      if (_processingCompleter != null && !_processingCompleter!.isCompleted) {
        _processingCompleter!.complete();
      }
      _processingCompleter = null;
    }
  }

  Future<void> _processSingleItem(AudioQueueItem item) async {
    try {
      // Step 1: Ensure models are loaded into memory via ModelLifecycleManager
      _logger?.info('[AudioQueue] Ensuring AI models are loaded in memory for item ${item.id}...');
      await _modelLifecycle.ensureModelsLoaded(reason: 'Queue worker item ${item.id}');

      // Step 2: Transcribe
      item.status = AudioQueueStatus.transcribing;
      _notifyState();
      await _saveToStorage();
      _logger?.info('[AudioQueue] Transcribing item: ${item.id} (${item.audioFilePath})');

      final rawTranscription = await _sttService.transcribe(item.audioFilePath);
      item.rawTranscript = rawTranscription;

      if (rawTranscription.trim().isEmpty) {
        _logger?.warning('[AudioQueue] Empty transcript for item ${item.id}');
        item.status = AudioQueueStatus.failed;
        item.errorMessage = 'No speech detected in audio recording.';
        await _saveToStorage();
        _notifyState();
        return;
      }

      // Step 3: Categorize with LLM
      item.status = AudioQueueStatus.categorizing;
      _notifyState();
      await _saveToStorage();
      _logger?.info('[AudioQueue] Categorizing item: ${item.id} with LLM');

      final llmResponse = await _llmService.processText(rawTranscription);
      item.folder = llmResponse.folder;
      item.correctedText = llmResponse.correctedText;

      // Step 4: Save to Isar Database
      final note = Note()
        ..rawText = rawTranscription
        ..correctedText = llmResponse.correctedText
        ..folder = llmResponse.folder
        ..createdAt = item.recordedAt
        ..originalAudioPath = item.audioFilePath;

      await _notesRepo.saveNote(note);
      item.status = AudioQueueStatus.completed;
      _logger?.info('[AudioQueue] Completed processing note ${item.id} into folder: ${llmResponse.folder}');

      await _saveToStorage();
      _notifyState();
      _onNoteSaved?.call();

      // Reset inactivity eviction countdown
      _modelLifecycle.touch(reason: 'Finished processing queued item ${item.id}');
    } catch (e, stack) {
      _logger?.error('[AudioQueue] Failed to process item ${item.id}', error: e, stackTrace: stack);
      item.status = AudioQueueStatus.failed;
      item.errorMessage = e.toString();
      await _saveToStorage();
      _notifyState();
    }
  }

  void dispose() {}
}

class PendingQueueCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int value) => state = value;
}

final pendingQueueCountProvider = NotifierProvider<PendingQueueCountNotifier, int>(() {
  return PendingQueueCountNotifier();
});

class FailedQueueCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int value) => state = value;
}

final failedQueueCountProvider = NotifierProvider<FailedQueueCountNotifier, int>(() {
  return FailedQueueCountNotifier();
});

class QueueItemsNotifier extends Notifier<List<AudioQueueItem>> {
  @override
  List<AudioQueueItem> build() => [];

  void setItems(List<AudioQueueItem> items) => state = List.unmodifiable(items);
}

final queueItemsProvider = NotifierProvider<QueueItemsNotifier, List<AudioQueueItem>>(() {
  return QueueItemsNotifier();
});

final audioQueueServiceProvider = Provider<AudioQueueService>((ref) {
  final sttService = ref.watch(sttServiceProvider);
  final llmService = ref.watch(llmServiceProvider);
  final notesRepo = ref.watch(notesRepositoryProvider);
  final modelLifecycle = ref.watch(modelLifecycleManagerProvider);
  final logger = ref.watch(appLoggerProvider);

  final service = AudioQueueService(
    sttService,
    llmService,
    notesRepo,
    modelLifecycle,
    logger: logger,
    onQueueChanged: (pending, failed) {
      ref.read(pendingQueueCountProvider.notifier).setCount(pending);
      ref.read(failedQueueCountProvider.notifier).setCount(failed);
    },
    onItemsChanged: (items) {
      ref.read(queueItemsProvider.notifier).setItems(items);
    },
    onNoteSaved: () {
      ref.invalidate(recentNotesProvider);
    },
  );

  ref.onDispose(() => service.dispose());
  return service;
});
