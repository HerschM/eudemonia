import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/cpu_wake_lock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingLogger implements AppLogger {
  final List<String> warnings = [];

  @override
  Future<void> warning(String message) async => warnings.add(message);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.eudemonia.eudemonia/processing_wake_lock');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  group('MethodChannelCpuWakeLock', () {
    test('hold sends the owner and the timeout in milliseconds', () async {
      mockChannel((_) async => null);

      await MethodChannelCpuWakeLock(owner: 'synthesis').hold(const Duration(minutes: 10));

      expect(calls.single.method, 'hold');
      expect(calls.single.arguments, {'owner': 'synthesis', 'timeoutMs': 600000});
    });

    test('release sends only the owner', () async {
      mockChannel((_) async => null);

      await MethodChannelCpuWakeLock(owner: 'transcription').release();

      expect(calls.single.method, 'release');
      expect(calls.single.arguments, {'owner': 'transcription'});
    });

    test('a platform error does not throw to the caller and is logged', () async {
      mockChannel((_) async => throw PlatformException(code: 'WAKE_LOCK_ERROR', message: 'denied'));
      final logger = RecordingLogger();
      final lock = MethodChannelCpuWakeLock(owner: 'synthesis', logger: logger);

      await lock.hold(const Duration(minutes: 1));
      await lock.release();

      expect(calls.map((c) => c.method), ['hold', 'release']);
      expect(logger.warnings, hasLength(2));
      expect(logger.warnings.first, allOf(contains('hold'), contains('synthesis'), contains('denied')));
    });

    test('a missing platform implementation does not throw to the caller', () async {
      // No handler registered: the channel reports MissingPluginException.
      final lock = MethodChannelCpuWakeLock(owner: 'synthesis');

      await lock.hold(const Duration(minutes: 1));
      await lock.release();
    });
  });

  group('providers', () {
    test('synthesis and transcription use separate owners', () async {
      mockChannel((_) async => null);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(synthesisWakeLockProvider).hold(const Duration(minutes: 1));
      await container.read(transcriptionWakeLockProvider).hold(const Duration(minutes: 1));

      expect(calls.map((c) => (c.arguments as Map)['owner']), ['synthesis', 'transcription']);
    });
  });
}
