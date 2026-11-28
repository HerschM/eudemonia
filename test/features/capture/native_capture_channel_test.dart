import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.eudemonia/capture');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late NativeCaptureChannel native;

  void mockNative(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  Future<void> sendFromNative(String method, Object? arguments) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  setUp(() {
    calls = [];
    native = NativeCaptureChannel();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('commands', () {
    test('getState, start and stop parse the state map', () async {
      mockNative((call) async => switch (call.method) {
            'getState' => {'isRecording': false, 'startedAtMs': null},
            'start' => {'isRecording': true, 'startedAtMs': 1700000000000},
            'stop' => {'isRecording': false},
            _ => null,
          });

      expect(await native.getState(), NativeCaptureState.idle);
      expect(await native.start(),
          const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000));
      expect(await native.stop(), NativeCaptureState.idle);
      expect(calls.map((c) => c.method), ['getState', 'start', 'stop']);
    });

    test('state replies carry the recording length limit when native reports it', () async {
      mockNative((call) async => switch (call.method) {
            'getState' => {'isRecording': false, 'startedAtMs': null, 'maxDurationMs': 300000},
            'start' => {'isRecording': true, 'startedAtMs': 1700000000000, 'maxDurationMs': 300000},
            'stop' => {'isRecording': false, 'maxDurationMs': 'five minutes'},
            _ => null,
          });

      expect(await native.getState(),
          const NativeCaptureState(isRecording: false, maxDurationMs: 300000));
      expect(await native.start(),
          const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000, maxDurationMs: 300000));
      expect((await native.stop()).maxDurationMs, isNull);
    });

    test('a state without a limit has none', () {
      expect(NativeCaptureState.fromMap({'isRecording': true, 'startedAtMs': 1}).maxDurationMs, isNull);
      expect(NativeCaptureState.idle.maxDurationMs, isNull);
    });

    test('listPendingCaptures keeps order and skips malformed rows', () async {
      mockNative((call) async => [
            {'path': '/inbox/a.wav', 'startedAtMs': 1},
            {'path': '', 'startedAtMs': 2},
            'garbage',
            {'path': '/inbox/b.wav', 'startedAtMs': 3},
          ]);

      final pending = await native.listPendingCaptures();

      expect(pending.map((p) => (p.path, p.startedAtMs)), [('/inbox/a.wav', 1), ('/inbox/b.wav', 3)]);
    });

    test('requestPinWidget returns the native answer', () async {
      mockNative((call) async => false);
      expect(await native.requestPinWidget(), isFalse);
      mockNative((call) async => true);
      expect(await native.requestPinWidget(), isTrue);
    });
  });

  group('without a platform implementation', () {
    test('everything behaves as idle and empty instead of throwing', () async {
      expect(await native.getState(), NativeCaptureState.idle);
      expect(await native.start(), NativeCaptureState.idle);
      expect(await native.stop(), NativeCaptureState.idle);
      expect(await native.listPendingCaptures(), isEmpty);
      expect(await native.requestPinWidget(), isFalse);
    });

    test('a platform error is treated the same way', () async {
      mockNative((call) async => throw PlatformException(code: 'boom'));

      expect(await native.start(), NativeCaptureState.idle);
      expect(await native.listPendingCaptures(), isEmpty);
    });
  });

  group('events from native', () {
    test('onStateChanged and onCaptureSaved reach the listeners', () async {
      final states = <NativeCaptureState>[];
      final saved = <PendingCapture>[];
      native.setListeners(onStateChanged: states.add, onCaptureSaved: saved.add);

      await sendFromNative('onStateChanged', {'isRecording': true, 'startedAtMs': 1700000000000});
      await sendFromNative('onCaptureSaved', {'path': '/inbox/a.wav', 'startedAtMs': 1700000000000});
      await sendFromNative('onCaptureSaved', {'path': 5});

      expect(states, [const NativeCaptureState(isRecording: true, startedAtMs: 1700000000000)]);
      expect(saved.single.path, '/inbox/a.wav');
    });

    test('onStateChanged carries the recording length limit', () async {
      final states = <NativeCaptureState>[];
      native.setListeners(onStateChanged: states.add, onCaptureSaved: (_) {});

      await sendFromNative('onStateChanged',
          {'isRecording': true, 'startedAtMs': 1700000000000, 'maxDurationMs': 300000});

      expect(states.single.maxDurationMs, 300000);
    });

    test('clearListeners stops delivery', () async {
      final states = <NativeCaptureState>[];
      native.setListeners(onStateChanged: states.add, onCaptureSaved: (_) {});
      native.clearListeners();

      await sendFromNative('onStateChanged', {'isRecording': true});

      expect(states, isEmpty);
    });
  });
}
