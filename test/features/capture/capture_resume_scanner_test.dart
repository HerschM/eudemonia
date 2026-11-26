import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/capture_resume_scanner.dart';

void main() {
  testWidgets('scans the inbox each time the app returns to the foreground, and only then', (tester) async {
    var scans = 0;
    final scanner = CaptureResumeScanner(onResumed: () async => scans++)..start();
    addTearDown(scanner.stop);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(scans, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(scans, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(scans, 2);
  });

  testWidgets('stops scanning once stopped', (tester) async {
    var scans = 0;
    final scanner = CaptureResumeScanner(onResumed: () async => scans++)..start();
    scanner.stop();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(scans, 0);
  });
}
