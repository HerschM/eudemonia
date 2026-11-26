import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';

import 'capture_test_doubles.dart';

void main() {
  late FakeNativeCaptureChannel channel;
  late FakeCaptureInboxIngestor ingestor;
  late RecordingModelLifecycleManager lifecycle;
  late ProviderContainer container;

  const savedRecording = PendingCapture(path: '/inbox/rec.wav', startedAtMs: 1700000000000);

  Future<CaptureController> boot() async {
    final controller = container.read(captureControllerProvider.notifier);
    container.read(captureControllerProvider);
    await controller.startupSync;
    return controller;
  }

  setUp(() {
    channel = FakeNativeCaptureChannel();
    ingestor = FakeCaptureInboxIngestor();
    lifecycle = RecordingModelLifecycleManager();
    container = ProviderContainer(
      overrides: [
        nativeCaptureChannelProvider.overrideWithValue(channel),
        captureInboxIngestorProvider.overrideWithValue(ingestor),
        modelLifecycleManagerProvider.overrideWithValue(lifecycle),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('state follows native events from any source', () {
    test('a recording started from the notification or widget turns the state on with its start time',
        () async {
      await boot();

      channel.emitState(const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000));

      expect(container.read(captureControllerProvider), isTrue);
      expect(container.read(captureControllerProvider.notifier).startedAt,
          DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('a stop from native turns it off and forgets the start time', () async {
      final controller = await boot();
      channel.emitState(const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000));

      channel.emitState(NativeCaptureState.idle);

      expect(container.read(captureControllerProvider), isFalse);
      expect(controller.startedAt, isNull);
    });

    test('a saved recording reported by native is ingested', () async {
      await boot();

      channel.emitSaved(savedRecording);
      await Future<void>.delayed(Duration.zero);

      expect(ingestor.ingested, [('/inbox/rec.wav', 1700000000000)]);
    });
  });

  group('model warm-up', () {
    test('starting warms the speech model once even when the reply and the event both report it',
        () async {
      final controller = await boot();

      await controller.handleTrigger();
      channel.emitState(channel.state);

      expect(lifecycle.warmupCalls, 1);
    });

    test('a start from another source warms the model; stopping does not warm again', () async {
      await boot();

      channel.emitState(const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000));
      expect(lifecycle.warmupCalls, 1);

      channel.emitState(NativeCaptureState.idle);
      expect(lifecycle.warmupCalls, 1);

      channel.emitState(const NativeCaptureState(isRecording: true, startedAtMs: 1700000009000));
      expect(lifecycle.warmupCalls, 2, reason: 'each recording gets its own warm-up');
    });

    test('a recording that could not start does not load the speech model', () async {
      channel.startSucceeds = false;
      final controller = await boot();

      await controller.handleTrigger();

      expect(lifecycle.warmupCalls, 0);
    });
  });

  group('handleTrigger (in-app capsule)', () {
    test('start flips the state before native answers', () async {
      final controller = await boot();
      channel.startGate = Completer<void>();

      final pending = controller.handleTrigger();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(captureControllerProvider), isTrue);
      expect(controller.startedAt, isNotNull);

      channel.startGate!.complete();
      await pending;
      expect(container.read(captureControllerProvider), isTrue);
    });

    test('start failure reverts the state and the next trigger tries a fresh start', () async {
      channel.startSucceeds = false;
      final controller = await boot();

      expect(await controller.handleTrigger(), isNull);
      expect(container.read(captureControllerProvider), isFalse);
      expect(controller.startedAt, isNull);

      channel.startSucceeds = true;
      await controller.handleTrigger();
      expect(container.read(captureControllerProvider), isTrue);
      expect(channel.stopCalls, 0);
    });

    test('stop returns the queue item of the recording native saved', () async {
      channel.saveOnStop = savedRecording;
      final controller = await boot();
      await controller.handleTrigger();

      final item = await controller.handleTrigger();

      expect(container.read(captureControllerProvider), isFalse);
      expect(channel.stopCalls, 1);
      expect(item?.audioFilePath, '/inbox/rec.wav');
      expect(item?.sequenceNumber, 1);
      expect(ingestor.ingested, [('/inbox/rec.wav', 1700000000000)]);
    });

    testWidgets('stop gives up after 5 seconds without a saved recording and returns null', (tester) async {
      final controller = await boot();
      await controller.handleTrigger();

      AudioResult? result;
      unawaited(controller.handleTrigger().then((item) => result = AudioResult(item)));
      await tester.pump(const Duration(seconds: 4));
      expect(result, isNull, reason: 'still waiting inside the window');

      await tester.pump(const Duration(seconds: 2));
      expect(result, isNotNull);
      expect(result!.item, isNull);
      expect(container.read(captureControllerProvider), isFalse);
    });

    test('a request that already matches the state is a no-op', () async {
      final controller = await boot();

      await controller.handleTrigger(desiredRecording: false);
      expect(channel.startCalls, 0);
      expect(channel.stopCalls, 0);

      await controller.handleTrigger(desiredRecording: true);
      await controller.handleTrigger(desiredRecording: true);
      expect(channel.startCalls, 1);
      expect(container.read(captureControllerProvider), isTrue);
    });

    test('a trigger while another is in flight is dropped', () async {
      final controller = await boot();
      channel.startGate = Completer<void>();

      final first = controller.handleTrigger();
      await Future<void>.delayed(Duration.zero);
      final second = await controller.handleTrigger();

      expect(second, isNull);
      expect(channel.startCalls, 1);
      expect(channel.stopCalls, 0);
      channel.startGate!.complete();
      await first;
    });

    test('the controller never talks to native before registering its listeners', () async {
      // The fake throws if used before setListeners; reading the provider must register first.
      await boot();
      expect(channel.hasListeners, isTrue);
    });
  });

  group('startup', () {
    test('syncs a recording already in progress and ingests what is waiting in the inbox', () async {
      channel.state = const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000);
      channel.pending = [savedRecording];

      final controller = await boot();

      expect(container.read(captureControllerProvider), isTrue);
      expect(controller.startedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(lifecycle.warmupCalls, 1);
      expect(ingestor.ingestPendingCalls, 1);
    });

    test('an idle native recorder leaves the state off', () async {
      await boot();

      expect(container.read(captureControllerProvider), isFalse);
      expect(ingestor.ingestPendingCalls, 1);
    });

    test('disposing the container detaches the native listeners', () async {
      await boot();
      container.dispose();

      expect(channel.hasListeners, isFalse);
      container = ProviderContainer();
    });
  });
}

/// Distinguishes "future not completed yet" from "completed with null".
class AudioResult {
  final Object? item;
  AudioResult(this.item);
}
