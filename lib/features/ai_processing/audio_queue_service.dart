import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/cpu_wake_lock.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';

class AudioQueueService {
  /// How long the CPU is kept awake per item; renewed before each item, so it only has to
  /// outlast the transcription of one recording.
  static const Duration wakeLockWindow = Duration(minutes: 5);

  final STTService _sttService;
  final NotesRepository _notesRepo;
  final ModelLifecycleManager _modelLifecycle;
  final AppLogger? _logger;
  final CpuWakeLock? _wakeLock;
  final Future<File> Function()? _storageFileResolver;
  final void Function(int pending, int failed)? _onQueueChanged;
  final void Function(List<AudioQueueItem> items)? _onItemsChanged;
  final void Function()? _onNoteSaved;

  /// While this returns false the worker leaves every item pending: a thought recorded before
  /// the speech model is downloaded waits, it is never failed (FR16.2). Null = always ready.
  final bool Function()? _isSpeechModelReady;

  final List<AudioQueueItem> _items = [];
  bool _isProcessing = false;
  File? _cachedFile;
  Future<void>? _loadingFuture;
  Future<void> _saveChain = Future.value();

  /// Highest daily sequence number handed out, per calendar day. A recording ingested late
  /// belongs to the day it was spoken, so several days can be live at once.
  final Map<int, int> _sequenceHighWater = {};

  /// Items whose audio file is not at its path yet (a native recording still being moved out
  /// of the capture inbox). The worker skips them until [markFileReady]. In memory only: after
  /// a restart the inbox scan completes the move before the worker starts.
  final Set<String> _awaitingFile = {};

  AudioQueueService(
    this._sttService,
    this._notesRepo,
    this._modelLifecycle, {
    this._logger,
    this._wakeLock,
    this._storageFileResolver,
    this._onQueueChanged,
    this._onItemsChanged,
    this._onNoteSaved,
    this._isSpeechModelReady,
    bool autoLoad = true,
  }) {
    if (autoLoad) {
      loadFromStorage();
    }
  }

  List<AudioQueueItem> get items => List.unmodifiable(_items);

  int get pendingCount => _items.where((i) =>
      i.status == AudioQueueStatus.pending ||
      i.status == AudioQueueStatus.transcribing).length;

  /// Real failures only: a silent recording is parked as failed internally but is not one for the user.
  int get failedCount => _items.where((i) => i.status == AudioQueueStatus.failed && !i.isSilent).length;

  AudioQueueItem? get currentProcessingItem => _items.cast<AudioQueueItem?>().firstWhere(
        (i) => i?.status == AudioQueueStatus.transcribing,
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
                if (item.status == AudioQueueStatus.transcribing) {
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

  /// Seeds the high-water mark of [day] from the persisted notes the first time it is needed.
  Future<void> _refreshSequenceHighWater(DateTime day) async {
    final key = _dayKey(day);
    if (_sequenceHighWater.containsKey(key)) return;
    int highWater = 0;
    try {
      highWater = await _notesRepo.maxDailySequenceFor(day);
    } catch (_) {}
    // Another caller may have seeded (and advanced) the same day while this one awaited.
    _sequenceHighWater.putIfAbsent(key, () => highWater);
  }

  /// Next daily sequence number (FR9.4) of the calendar day of [day]. Numbers are never
  /// reissued within a day, so deleting a thought leaves a gap instead of renumbering (FR9.5).
  Future<int> _nextSequenceNumber(DateTime day) async {
    await _refreshSequenceHighWater(day);
    final key = _dayKey(day);
    var highWater = _sequenceHighWater[key]!;
    for (final item in _items) {
      final seq = item.sequenceNumber;
      if (seq != null && seq > highWater && _dayKey(item.recordedAt) == key) {
        highWater = seq;
      }
    }
    return _sequenceHighWater[key] = highWater + 1;
  }

  /// Queues a finished recording. [recordedAt] is when it was spoken (defaults to now); the
  /// daily sequence number is taken from that calendar day.
  Future<AudioQueueItem> enqueue(
    String audioFilePath, {
    bool autoProcess = true,
    DateTime? recordedAt,
    bool fileReady = true,
  }) async {
    // Hydration replaces the in-memory list, so it must settle before a new item joins it.
    await loadFromStorage();

    final now = DateTime.now();
    final spokenAt = recordedAt ?? now;
    final nextSeq = await _nextSequenceNumber(spokenAt);

    final item = AudioQueueItem(
      id: now.microsecondsSinceEpoch.toString(),
      audioFilePath: audioFilePath,
      recordedAt: spokenAt,
      status: AudioQueueStatus.pending,
      sequenceNumber: nextSeq,
    );

    if (!fileReady) _awaitingFile.add(item.id);
    _items.add(item);
    // Surface the card before touching the disk so the UI never waits on I/O.
    _notifyState();
    await _saveToStorage();
    _logger?.info('[AudioQueue] Enqueued new thought: ${item.id} with sequence #$nextSeq (Total pending: $pendingCount)');

    if (autoProcess && fileReady) {
      unawaited(processPending());
    }

    return item;
  }

  /// Releases an item queued with `fileReady: false` once its audio file is in place.
  void markFileReady(AudioQueueItem item) => _awaitingFile.remove(item.id);

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
      if (item.status == AudioQueueStatus.failed && !item.isSilent) {
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
    var wakeLockHeld = false;

    try {
      while (true) {
        if (_isSpeechModelReady?.call() == false) break;
        final pendingItems = _items
            .where((i) => i.status == AudioQueueStatus.pending && !_awaitingFile.contains(i.id))
            .toList();
        if (pendingItems.isEmpty) break;

        final nextItem = pendingItems.first;
        await _wakeLock?.hold(wakeLockWindow);
        wakeLockHeld = true;
        await _processSingleItem(nextItem);
      }
    } finally {
      _isProcessing = false;
      if (_processingCompleter != null && !_processingCompleter!.isCompleted) {
        _processingCompleter!.complete();
      }
      _processingCompleter = null;
      // Sent after the state reset, so the hold of a run that starts next always follows it.
      if (wakeLockHeld) await _wakeLock?.release();
    }
  }

  /// True while [item] is still queued (the user may delete a thought mid-inference).
  bool _isQueued(AudioQueueItem item) => _items.contains(item);

  Future<void> _processSingleItem(AudioQueueItem item) async {
    try {
      // The lifecycle manager keeps the speech model resident for the whole item and
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
      item.errorMessage = silentRecordingMessage;
      await _saveToStorage();
      _notifyState();
      return;
    }

    // The thought is stored exactly as transcribed (fillers kept); no LLM cleanup or folder inference.
    final text = rawTranscription.trim();
    item.correctedText = text;

    // Step 2: Save to Isar Database
    final note = Note()
      ..rawText = rawTranscription
      ..correctedText = text
      ..createdAt = item.recordedAt
      ..originalAudioPath = item.audioFilePath
      ..dailySequenceNumber = item.sequenceNumber;

    await _notesRepo.saveNote(note);
    item.status = AudioQueueStatus.completed;
    _logger?.info('[AudioQueue] Completed processing note ${item.id}');

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
  final notesRepo = ref.watch(notesRepositoryProvider);
  final modelLifecycle = ref.watch(modelLifecycleManagerProvider);
  final logger = ref.watch(appLoggerProvider);

  final service = AudioQueueService(
    sttService,
    notesRepo,
    modelLifecycle,
    logger: logger,
    wakeLock: ref.watch(transcriptionWakeLockProvider),
    onQueueChanged: (pending, failed) {
      ref.read(pendingQueueCountProvider.notifier).setCount(pending);
      ref.read(failedQueueCountProvider.notifier).setCount(failed);
    },
    onItemsChanged: (items) {
      ref.read(queueItemsProvider.notifier).setItems(items);
    },
    onNoteSaved: () {
      unawaited(ref.read(synthesisTriggerControllerProvider).onThoughtSaved());
    },
    isSpeechModelReady: () => ref.read(speechModelReadyProvider),
  );

  // Thoughts that waited for the speech model are transcribed as soon as it is ready. A direct
  // callback, not ref.listen: the download may finish while no screen is mounted, and Riverpod
  // pauses the listeners of a provider nobody watches.
  final models = ref.read(modelLibraryControllerProvider.notifier);
  models.onSpeechModelReady = () => unawaited(service.processPending());
  ref.onDispose(() => models.onSpeechModelReady = null);

  ref.onDispose(() => service.dispose());
  return service;
});
