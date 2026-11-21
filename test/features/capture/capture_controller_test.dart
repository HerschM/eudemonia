import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/batch_pipeline_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';

class RecordingModelLifecycleManager extends ModelLifecycleManager {
  int warmupCalls = 0;

  RecordingModelLifecycleManager() : super(STTService());

  @override
  void warmupOnRecordingStart() => warmupCalls++;
}

class FakeBatchPipelineService implements BatchPipelineService {
  bool startSucceeds = true;
  bool isCapturing = false;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> startRecording() async {
    startCalls++;
    if (isCapturing) throw StateError('startRecording called while already capturing');
    isCapturing = startSucceeds;
    return startSucceeds;
  }

  @override
  Future<AudioQueueItem?> stopRecordingAndProcess() async {
    stopCalls++;
    if (!isCapturing) throw StateError('stopRecordingAndProcess called without an active capture');
    isCapturing = false;
    return AudioQueueItem(
      id: 'captured-$stopCalls',
      audioFilePath: '/captures/$stopCalls.wav',
      recordedAt: DateTime.now(),
      sequenceNumber: stopCalls,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  late FakeBatchPipelineService pipeline;
  late RecordingModelLifecycleManager lifecycle;
  late ProviderContainer container;
  late List<bool> nativeRecordingStates;

  Future<void> sendTrigger([Map<String, Object?> args = const {'isLocked': false}]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('onHardwareTrigger', args)),
      (_) {},
    );
  }

  /// Triggers closer than 500ms apart are debounced, so tests space them out.
  Future<void> waitOutCooldown() =>
      Future<void>.delayed(CaptureController.triggerCooldown + const Duration(milliseconds: 20));

  setUp(() {
    pipeline = FakeBatchPipelineService();
    lifecycle = RecordingModelLifecycleManager();
    nativeRecordingStates = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'setRecordingState') {
        nativeRecordingStates.add((call.arguments as Map)['isRecording'] as bool);
      }
      return null;
    });
    container = ProviderContainer(
      overrides: [
        batchPipelineProvider.overrideWithValue(pipeline),
        modelLifecycleManagerProvider.overrideWithValue(lifecycle),
      ],
    );
    container.read(captureControllerProvider);
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hardware trigger starts recording and a second trigger stops and enqueues', () async {
    await sendTrigger();
    expect(container.read(captureControllerProvider), isTrue);
    expect(pipeline.startCalls, 1);

    await waitOutCooldown();
    await sendTrigger();
    expect(container.read(captureControllerProvider), isFalse);
    expect(pipeline.stopCalls, 1);
  });

  test('handleTrigger returns the queued capture only when it finishes a recording', () async {
    final controller = container.read(captureControllerProvider.notifier);

    expect(await controller.handleTrigger(), isNull);
    await waitOutCooldown();
    final captured = await controller.handleTrigger();

    expect(captured?.sequenceNumber, 1);
  });

  test('starting a recording warms the speech model once; stopping does not', () async {
    await sendTrigger();
    expect(lifecycle.warmupCalls, 1);

    await waitOutCooldown();
    await sendTrigger();
    expect(container.read(captureControllerProvider), isFalse);
    expect(lifecycle.warmupCalls, 1);
  });

  test('a recording that could not start does not load the speech model', () async {
    pipeline.startSucceeds = false;
    await sendTrigger();
    expect(lifecycle.warmupCalls, 0);
  });

  test('recording state reverts when the microphone could not start', () async {
    pipeline.startSucceeds = false;

    await sendTrigger();

    expect(container.read(captureControllerProvider), isFalse);

    // The next trigger must attempt a fresh start, not "stop" a recording that never existed.
    pipeline.startSucceeds = true;
    await waitOutCooldown();
    await sendTrigger();
    expect(container.read(captureControllerProvider), isTrue);
    expect(pipeline.stopCalls, 0);
  });

  test('native side is told the authoritative recording state after every trigger', () async {
    await sendTrigger();
    await waitOutCooldown();
    await sendTrigger();

    expect(nativeRecordingStates, [true, false]);
  });

  test('a failed start reports "not recording" to native so haptics and notification stay in sync', () async {
    pipeline.startSucceeds = false;
    await sendTrigger();
    expect(nativeRecordingStates, [false]);
  });

  test('explicit stop action while idle is a no-op that never starts a recording', () async {
    await sendTrigger({'isLocked': true, 'desiredRecording': false});

    expect(container.read(captureControllerProvider), isFalse);
    expect(pipeline.startCalls, 0);
    expect(nativeRecordingStates, [false]);
  });

  test('explicit start action while already recording does not stop the capture', () async {
    await sendTrigger({'isLocked': true, 'desiredRecording': true});
    await sendTrigger({'isLocked': true, 'desiredRecording': true});

    expect(container.read(captureControllerProvider), isTrue);
    expect(pipeline.startCalls, 1);
    expect(pipeline.stopCalls, 0);
  });

  test('a bounce within the 500ms cooldown is dropped', () async {
    await sendTrigger();
    await sendTrigger();

    expect(container.read(captureControllerProvider), isTrue);
    expect(pipeline.stopCalls, 0);
  });
}
