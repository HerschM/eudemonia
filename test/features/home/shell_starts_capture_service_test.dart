import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';

import 'shell_test_harness.dart';

/// The capture service must run whichever tab the app opens on: it keeps the Record button ready
/// and lets transcription and Synthesis finish after the app is left. Found on the Pixel 7a
/// (2026-11-28): opening on Synthesis never built the Capture screen, which used to start it, so a
/// Synthesis run had no service behind it and the process was killed when the app was left.
void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  final shell = ShellHarness();
  late List<String> calls;

  setUp(() {
    mockShellChannels();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'isForegroundServiceRunning';
    });
  });

  tearDown(unmockShellChannels);

  testWidgets('opening on Synthesis starts the capture service without the Capture screen', (tester) async {
    await shell.pump(tester, clusters: [shellTestCluster(1)], initialIndex: 1);

    expect(find.byType(CaptureScreen), findsNothing, reason: 'the Capture page is not built until it is visited');
    expect(calls, contains('startForegroundService'));
  });

  testWidgets('opening on Capture starts it too, once', (tester) async {
    await shell.pump(tester);

    expect(calls.where((m) => m == 'startForegroundService'), hasLength(1));
  });
}
