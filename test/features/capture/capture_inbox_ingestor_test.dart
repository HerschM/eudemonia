import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';

import 'capture_test_doubles.dart';

/// Queue double that behaves like the real one for the calls the ingestor makes, and throws
/// when used before `loadFromStorage` has run (the real queue is hydrated lazily).
class FakeQueue implements AudioQueueService {
  final List<AudioQueueItem> _items = [];
  final List<String> enqueued = [];
  final List<bool> finalFileExistedAtProcess = [];
  final Set<String> failingPaths = {};
  Duration enqueueDelay = Duration.zero;
  Completer<void>? processGate;
  bool loaded = false;
  int processPendingCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  List<AudioQueueItem> get items {
    if (!loaded) throw StateError('queue items read before loadFromStorage');
    return List.unmodifiable(_items);
  }

  void seed(AudioQueueItem item) => _items.add(item);

  @override
  Future<void> loadFromStorage({bool forceReload = false}) async {
    loaded = true;
  }

  @override
  Future<AudioQueueItem> enqueue(
    String audioFilePath, {
    bool autoProcess = true,
    DateTime? recordedAt,
    bool fileReady = true,
  }) async {
    if (!loaded) throw StateError('enqueue before loadFromStorage');
    expect(fileReady, isFalse, reason: 'the worker must not take the item before the rename');
    await Future<void>.delayed(enqueueDelay);
    if (failingPaths.any(audioFilePath.contains)) throw StateError('disk full');
    enqueued.add(audioFilePath);
    final item = AudioQueueItem(
      id: 'q-${enqueued.length}',
      audioFilePath: audioFilePath,
      recordedAt: recordedAt ?? DateTime.now(),
    );
    _items.add(item);
    return item;
  }

  final List<String> releasedWithFileInPlace = [];

  @override
  void markFileReady(AudioQueueItem item) {
    if (File(item.audioFilePath).existsSync()) releasedWithFileInPlace.add(item.audioFilePath);
  }

  @override
  Future<void> processPending() async {
    processPendingCalls++;
    finalFileExistedAtProcess.add(_items.isNotEmpty && File(_items.last.audioFilePath).existsSync());
    if (processGate != null) await processGate!.future;
  }
}

void main() {
  late Directory root;
  late Directory documents;
  late Directory inbox;
  late FakeNativeCaptureChannel channel;
  late FakeQueue queue;
  late CaptureInboxIngestor ingestor;

  File inboxFile(String name, {String content = 'RIFF'}) =>
      File('${inbox.path}/$name')..writeAsStringSync(content);

  String finalPathFor(int startedAtMs) => '${documents.path}/recording_$startedAtMs.wav';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ingestor_test_');
    documents = await Directory('${root.path}/documents').create();
    inbox = await Directory('${root.path}/inbox').create();
    channel = FakeNativeCaptureChannel()
      ..setListeners(onStateChanged: (_) {}, onCaptureSaved: (_) {});
    queue = FakeQueue();
    ingestor = CaptureInboxIngestor(
      channel: channel,
      queue: queue,
      documentsDirectory: () async => documents,
    );
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('enqueues under the final path, then moves the file there before processing starts', () async {
    final file = inboxFile('a.wav', content: 'audio-a');

    final item = await ingestor.ingest(file.path, 1700000000000);

    expect(item, isNotNull);
    expect(queue.enqueued, [finalPathFor(1700000000000)]);
    expect(file.existsSync(), isFalse);
    expect(File(finalPathFor(1700000000000)).readAsStringSync(), 'audio-a');
    expect(queue.processPendingCalls, 1);
    expect(queue.finalFileExistedAtProcess, [true], reason: 'processing must start after the rename');
    expect(queue.releasedWithFileInPlace, [finalPathFor(1700000000000)],
        reason: 'the item is released to the worker only once its file is in place');
  });

  test('recordedAt is taken from startedAtMs, not from the moment of ingestion', () async {
    final file = inboxFile('a.wav');

    final item = await ingestor.ingest(file.path, 1700000000000);

    expect(item!.recordedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('ingesting the same recording twice enqueues it once and returns the same item', () async {
    final file = inboxFile('a.wav');

    final first = await ingestor.ingest(file.path, 1700000000000);
    final second = await ingestor.ingest(file.path, 1700000000000);

    expect(queue.enqueued, hasLength(1));
    expect(second, same(first));
    expect(File(finalPathFor(1700000000000)).existsSync(), isTrue);
  });

  test('crash recovery: an item queued before the process died only needs its rename completed', () async {
    final file = inboxFile('a.wav');
    final finalPath = finalPathFor(1700000000000);
    final queued = AudioQueueItem(
      id: 'survivor',
      audioFilePath: finalPath,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    queue.seed(queued);

    final item = await ingestor.ingest(file.path, 1700000000000);

    expect(item, same(queued));
    expect(queue.enqueued, isEmpty);
    expect(file.existsSync(), isFalse);
    expect(File(finalPath).existsSync(), isTrue);
    expect(queue.finalFileExistedAtProcess, [true]);
  });

  test('a recording that is neither queued nor in the inbox is ignored', () async {
    final item = await ingestor.ingest('${inbox.path}/ghost.wav', 1700000000000);

    expect(item, isNull);
    expect(queue.enqueued, isEmpty);
    expect(queue.processPendingCalls, 0);
  });

  test('concurrent ingests of the same recording enqueue it once', () async {
    queue.enqueueDelay = const Duration(milliseconds: 30);
    final file = inboxFile('a.wav');

    // A native event, a duplicate event and a startup scan all name the same recording.
    channel.pending = [PendingCapture(path: file.path, startedAtMs: 1700000000000)];
    final first = ingestor.ingest(file.path, 1700000000000);
    final second = ingestor.ingest(file.path, 1700000000000);
    final scan = ingestor.ingestPending();

    expect(await first, same(await second));
    await scan;
    expect(queue.enqueued, hasLength(1));
  });

  test('ingestPending ingests every inbox recording, oldest first', () async {
    final a = inboxFile('a.wav');
    final b = inboxFile('b.wav');
    channel.pending = [
      PendingCapture(path: a.path, startedAtMs: 1700000000000),
      PendingCapture(path: b.path, startedAtMs: 1700000005000),
    ];

    await ingestor.ingestPending();

    expect(queue.enqueued, [finalPathFor(1700000000000), finalPathFor(1700000005000)]);
    expect(a.existsSync() || b.existsSync(), isFalse);
  });

  test('one failing file is logged and does not stop the next', () async {
    final bad = inboxFile('bad.wav');
    final good = inboxFile('good.wav');
    queue.failingPaths.add('recording_1700000000000');
    channel.pending = [
      PendingCapture(path: bad.path, startedAtMs: 1700000000000),
      PendingCapture(path: good.path, startedAtMs: 1700000005000),
    ];

    await ingestor.ingestPending();

    expect(queue.enqueued, [finalPathFor(1700000005000)]);
    expect(File(finalPathFor(1700000005000)).existsSync(), isTrue);
    expect(bad.existsSync(), isTrue, reason: 'a failed file stays in the inbox for the next scan');
  });

  test('a failing ingest returns null and later calls still work', () async {
    final bad = inboxFile('bad.wav');
    final good = inboxFile('good.wav');
    queue.failingPaths.add('recording_1700000000000');

    expect(await ingestor.ingest(bad.path, 1700000000000), isNull);
    expect(await ingestor.ingest(good.path, 1700000005000), isNotNull);
  });

  test('ingest does not wait for the transcription it kicks off', () async {
    queue.processGate = Completer<void>();
    final file = inboxFile('a.wav');

    final item = await ingestor.ingest(file.path, 1700000000000).timeout(const Duration(seconds: 2));
    expect(item, isNotNull);

    // The serial lock is free again while the worker is still busy.
    final next = inboxFile('b.wav');
    expect(await ingestor.ingest(next.path, 1700000005000).timeout(const Duration(seconds: 2)), isNotNull);
    queue.processGate!.complete();
  });

  test('queue items are read only after the queue has been hydrated', () async {
    final file = inboxFile('a.wav');
    // FakeQueue.items throws before loadFromStorage; a successful ingest proves the order.
    expect(await ingestor.ingest(file.path, 1700000000000), isNotNull);
    expect(queue.loaded, isTrue);
  });
}
