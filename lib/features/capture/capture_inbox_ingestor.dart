import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';

/// Turns a finished native recording into a queue item, crash-safely and idempotently.
///
/// The item is enqueued under its final path *before* the inbox file is renamed there, and
/// is held back from the queue worker until the rename is done. If the process dies between the two steps, the
/// next scan still finds the file in the inbox, sees the item already queued and only
/// completes the rename.
///
/// All calls are serialised, so a native event and a startup scan cannot enqueue the same
/// file twice.
class CaptureInboxIngestor {
  final NativeCaptureChannel _channel;
  final AudioQueueService _queue;
  final Future<Directory> Function() _documentsDirectory;
  final AppLogger? _logger;

  Future<void> _tail = Future.value();

  CaptureInboxIngestor({
    required this._channel,
    required this._queue,
    Future<Directory> Function()? documentsDirectory,
    this._logger,
  }) : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  /// Ingests one finished recording. Returns its queue item, or `null` when it could not be
  /// ingested (the failure is logged).
  Future<AudioQueueItem?> ingest(String path, int startedAtMs) =>
      _serialised(() => _ingest(path, startedAtMs));

  /// Ingests every recording waiting in the native inbox, oldest first. One failing file
  /// does not stop the others.
  Future<void> ingestPending() => _serialised(() async {
        final pending = await _channel.listPendingCaptures();
        for (final capture in pending) {
          await _ingest(capture.path, capture.startedAtMs);
        }
      });

  Future<T> _serialised<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<AudioQueueItem?> _ingest(String path, int startedAtMs) async {
    try {
      // The queue file is hydrated lazily; an item queued by a previous session must be
      // visible before deciding whether this recording is new.
      await _queue.loadFromStorage();

      final documents = await _documentsDirectory();
      final finalPath = '${documents.path}/recording_$startedAtMs.wav';
      final inboxFile = File(path);
      final inboxHasFile = path != finalPath && await inboxFile.exists();

      var item = _queuedItem(finalPath);
      if (item == null) {
        if (!inboxHasFile) {
          // Already ingested and processed earlier, or never written: nothing to queue.
          _logger?.warning('[CaptureInbox] Nothing to ingest at $path');
          return null;
        }
        item = await _queue.enqueue(
          finalPath,
          fileReady: false,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
        );
      }

      if (inboxHasFile) {
        await inboxFile.rename(finalPath);
      }
      _queue.markFileReady(item);

      // Never awaited: the lock must not be held for the duration of a transcription.
      unawaited(_queue.processPending());
      return item;
    } catch (e, stack) {
      _logger?.error('[CaptureInbox] Failed to ingest $path', error: e, stackTrace: stack);
      return null;
    }
  }

  AudioQueueItem? _queuedItem(String finalPath) {
    for (final item in _queue.items) {
      if (item.audioFilePath == finalPath) return item;
    }
    return null;
  }
}

final captureInboxIngestorProvider = Provider<CaptureInboxIngestor>((ref) {
  return CaptureInboxIngestor(
    channel: ref.watch(nativeCaptureChannelProvider),
    queue: ref.watch(audioQueueServiceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});
