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
  Future<void> _saveChain = Future.value();

  /// Highest daily sequence number handed out for [_sequenceDayKey].
  int? _sequenceDayKey;
  int _sequenceHighWater = 0;

  AudioQueueService(
    this._sttService,
    this._llmService,
    this._notesRepo,
    this._modelLifecycle, {
    this._logger,
    this._storageFileResolver,
    this._onQueueChanged,
    this._onItemsChanged,
    this._onNoteSaved,
    bool autoLoad = true,
  }) {
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
          final hydrated = <AudioQueueItem>[];
          bool needsRewrite = false;
          for (final j in jsonList) {
            try {
              if (j is Map) {
                final item = AudioQueueItem.fromJson(Map<String, dynamic>.from(j));
                if (item.status == AudioQueueStatus.completed) {
                  // Already persisted as a note; keeping it would grow the queue file forever.
                  needsRewrite = true;
                  continue;
                }
                if (item.status == AudioQueueStatus.transcribing ||
                    item.status == AudioQueueStatus.categorizing) {
                  // The process died mid-inference: hand the item back to the worker.
                  item.status = AudioQueueStatus.pending;
                  needsRewrite = true;
                }
                hydrated.add(item);
              } else {
                _logger?.warning('Quarantining invalid non-map queue entry: $j');
              }
            } catch (itemErr) {
              _logger?.warning('Quarantining corrupt queue item: $itemErr');
            }
          }
          _items
            ..clear()
            ..addAll(hydrated);
          if (needsRewrite) {
            await _saveToStorage();
          }
          _notifyState();
        }
      }
    } catch (e) {
      _logger?.error('Error loading queue from storage', error: e);
    }
    // Warm the sequence counter so the first capture of the session skips the database.
    await _refreshSequenceHighWater(DateTime.now());
  }

  /// Hydrates the queue from disk and drains whatever a previous session left unfinished.
  Future<void> resumePendingWork() async {
    await loadFromStorage();
    await processPending();
  }

  /// Persists a snapshot of the queue. Writes are serialized and atomic so a
  /// process kill can never leave a truncated or interleaved queue file.
  Future<void> _saveToStorage() {
    final snapshot = jsonEncode(_items.map((i) => i.toJson()).toList());
    return _saveChain = _saveChain.then((_) async {
      try {
        final file = await _resolveStorageFile();
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(snapshot, flush: true);
        await tmp.rename(file.path);
      } catch (e) {
        _logger?.error('Error saving queue to storage', error: e);
      }
    });
  }

  void _notifyState() {
    _onQueueChanged?.call(pendingCount, failedCount);
    _onItemsChanged?.call(List.unmodifiable(_items));
  }

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Future<void> _refreshSequenceHighWater(DateTime now) async {
    final key = _dayKey(now);
    if (_sequenceDayKey == key) return;
    int highWater = 0;
    try {
      highWater = await _notesRepo.maxDailySequenceFor(now);
    } catch (_) {}
    _sequenceDayKey = key;
    _sequenceHighWater = highWater;
  }

  /// Next daily sequence number (FR9.4). Numbers are never reissued within a
  /// day, so deleting a thought leaves a gap instead of renumbering (FR9.5).
  Future<int> _nextSequenceNumber(DateTime now) async {
    await _refreshSequenceHighWater(now);
    final key = _dayKey(now);
    for (final item in _items) {
      final seq = item.sequenceNumber;
      if (seq != null && seq > _sequenceHighWater && _dayKey(item.recordedAt) == key) {
        _sequenceHighWater = seq;
      }
    }
    return ++_sequenceHighWater;
  }

  Future<AudioQueueItem> enqueue(String audioFilePath, {bool autoProcess = true}) async {
    // Hydration replaces the in-memory list, so it must settle before a new item joins it.
    await loadFromStorage();

    final now = DateTime.now();
    final nextSeq = await _nextSequenceNumber(now);

    final item = AudioQueueItem(
      id: now.microsecondsSinceEpoch.toString(),
      audioFilePath: audioFilePath,
      recordedAt: now,
      status: AudioQueueStatus.pending,
      sequenceNumber: nextSeq,
    );

    _items.add(item);
    // Surface the card before touching the disk so the UI never waits on I/O.
    _notifyState();
    await _saveToStorage();
    _logger?.info('[AudioQueue] Enqueued new thought: ${item.id} with sequence #$nextSeq (Total pending: $pendingCount)');

    if (autoProcess) {
      unawaited(processPending());
    }

    return item;
  }

  Future<void> removeItemByAudioPath(String audioFilePath) async {
    _items.removeWhere((i) => i.audioFilePath == audioFilePath);
    await _saveToStorage();
    _notifyState();
    _logger?.info('[AudioQueue] Removed item with audioFilePath: $audioFilePath');
    try {
      final file = File(audioFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _logger?.warning('[AudioQueue] Failed to delete audio file: $e');
    }
  }

  Future<void> removeItemById(String id) async {
    final match = _items.cast<AudioQueueItem?>().firstWhere((i) => i?.id == id, orElse: () => null);
    if (match != null) {
      await removeItemByAudioPath(match.audioFilePath);
    }
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
      // An explicit retry is the user's request to attempt model loading again.
      await _modelLifecycle.allowLoadRetry();
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

  /// True while [item] is still queued (the user may delete a thought mid-inference).
  bool _isQueued(AudioQueueItem item) => _items.contains(item);

  Future<void> _processSingleItem(AudioQueueItem item) async {
    try {
      // The lifecycle manager keeps both models resident for the whole item and
      // restarts the inactivity eviction countdown when it finishes, pass or fail.
      _logger?.info('[AudioQueue] Ensuring AI models are loaded in memory for item ${item.id}...');
      await _modelLifecycle.runWithModels(
        () => _transcribeAndSave(item),
        reason: 'Queue worker item ${item.id}',
      );
    } catch (e, stack) {
      _logger?.error('[AudioQueue] Failed to process item ${item.id}', error: e, stackTrace: stack);
      if (!_isQueued(item)) return;
      item.status = AudioQueueStatus.failed;
      item.errorMessage = e.toString().replaceFirst('Exception: ', '');
      await _saveToStorage();
      _notifyState();
    }
  }

  Future<void> _transcribeAndSave(AudioQueueItem item) async {
    // Step 1: Transcribe
    item.status = AudioQueueStatus.transcribing;
    _notifyState();
    await _saveToStorage();
    _logger?.info('[AudioQueue] Transcribing item: ${item.id} (${item.audioFilePath})');

    final rawTranscription = await _sttService.transcribe(item.audioFilePath);
    if (!_isQueued(item)) return;
    item.rawTranscript = rawTranscription;

    if (rawTranscription.trim().isEmpty) {
      _logger?.warning('[AudioQueue] Empty transcript for item ${item.id}');
      item.status = AudioQueueStatus.failed;
      item.errorMessage = 'No speech detected in audio recording.';
      await _saveToStorage();
      _notifyState();
      return;
    }

    // Step 2: Categorize with LLM
    item.status = AudioQueueStatus.categorizing;
    _notifyState();
    await _saveToStorage();
    _logger?.info('[AudioQueue] Categorizing item: ${item.id} with LLM');

    final llmResponse = await _llmService.processText(rawTranscription);
    if (!_isQueued(item)) return;
    item.folder = llmResponse.folder;
    item.correctedText = llmResponse.correctedText;

    // Step 3: Save to Isar Database
    final note = Note()
      ..rawText = rawTranscription
      ..correctedText = llmResponse.correctedText
      ..folder = llmResponse.folder
      ..createdAt = item.recordedAt
      ..originalAudioPath = item.audioFilePath
      ..dailySequenceNumber = item.sequenceNumber;

    await _notesRepo.saveNote(note);
    item.status = AudioQueueStatus.completed;
    _logger?.info('[AudioQueue] Completed processing note ${item.id} into folder: ${llmResponse.folder}');

    await _saveToStorage();
    _notifyState();
    _onNoteSaved?.call();
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
