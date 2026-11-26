import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/settings/presentation/diagnostic_logging_section.dart';

// PARKED with the section it tests; see README.md. Restore to
// test/features/settings/diagnostic_logging_section_test.dart.
//
// The first test holds the assertions that production_settings_screen_test.dart made about this
// section ("6. Diagnostic Logging (2MB Rotating)") before it was removed from Settings.

/// A logger that keeps its lines in memory, so the tests need no file I/O.
class _InMemoryLogger extends AppLogger {
  final List<String> lines = [];

  @override
  Future<void> info(String message) async => lines.add(message);

  @override
  Future<String> getLogDump() async => lines.join('\n');

  @override
  Future<List<String>> getRecentLines({int count = 100}) async =>
      lines.length <= count ? List.of(lines) : lines.sublist(lines.length - count);

  @override
  Future<void> clearLogs() async => lines.clear();
}

void main() {
  late _InMemoryLogger logger;

  setUp(() => logger = _InMemoryLogger());

  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLoggerProvider.overrideWithValue(logger)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DiagnosticLoggingSection())),
        ),
      ),
    );
  }

  testWidgets('shows the header and the three actions at 360dp without overflow', (tester) async {
    await pumpSection(tester);

    expect(find.text('DIAGNOSTIC LOGGING (2MB ROTATING)'), findsOneWidget);
    expect(find.byKey(const Key('view_system_logs_button')), findsOneWidget);
    expect(find.byKey(const Key('copy_log_dump_button')), findsOneWidget);
    expect(find.byKey(const Key('clear_logs_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('View System Logs opens a sheet with the recent lines, or says there are none', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.byKey(const Key('view_system_logs_button')));
    await tester.pumpAndSettle();
    expect(find.text('On-Device Diagnostic Logs'), findsOneWidget);
    expect(find.text('No logs recorded yet.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await logger.info('hello from the test');
    await tester.tap(find.byKey(const Key('view_system_logs_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('hello from the test'), findsOneWidget);
  });

  testWidgets('Copy Diagnostic Log Dump puts the log on the clipboard', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await logger.info('line to copy');
    await pumpSection(tester);

    await tester.tap(find.byKey(const Key('copy_log_dump_button')));
    await tester.pumpAndSettle();

    expect(copied, contains('line to copy'));
    expect(find.text('Log dump copied to clipboard.'), findsOneWidget);
  });

  testWidgets('Clear Logs empties the log', (tester) async {
    await logger.info('line to clear');
    await pumpSection(tester);

    await tester.tap(find.byKey(const Key('clear_logs_button')));
    await tester.pumpAndSettle();

    expect(await logger.getRecentLines(), isEmpty);
    expect(find.text('Local logs cleared.'), findsOneWidget);
  });
}
