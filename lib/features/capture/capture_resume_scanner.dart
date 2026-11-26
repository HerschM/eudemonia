import 'package:flutter/widgets.dart';

/// Runs [onResumed] each time the app returns to the foreground, so recordings that native
/// code saved while no Dart code was listening are picked up from the inbox.
class CaptureResumeScanner with WidgetsBindingObserver {
  final Future<void> Function() onResumed;

  CaptureResumeScanner({required this.onResumed});

  void start() => WidgetsBinding.instance.addObserver(this);

  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
