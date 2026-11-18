import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

class FakePendingQueueCountNotifier extends PendingQueueCountNotifier {
  final int initial;
  FakePendingQueueCountNotifier(this.initial);
  @override
  int build() => initial;
}

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return call.method.startsWith('is') ? true : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpShell(WidgetTester tester, int pending) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          pendingQueueCountProvider.overrideWith(() => FakePendingQueueCountNotifier(pending)),
        ],
        child: const MaterialApp(home: MainNavigationShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('TASK-031: queue state is visible on cold start (FR13.3)', () {
    testWidgets('Pipeline pill and Capture badge show hydrated pending items immediately on launch',
        (tester) async {
      await pumpShell(tester, 3);

      expect(find.text('3 in Pipeline ▾'), findsOneWidget);
      expect(find.text('Capture (3)'), findsOneWidget);
    });

    testWidgets('Pipeline pill reads In Sync and the badge is suppressed when nothing is queued',
        (tester) async {
      await pumpShell(tester, 0);

      expect(find.text('In Sync ▾'), findsOneWidget);
      expect(find.text('Capture'), findsOneWidget);
    });

    testWidgets('Capture screen carries no machine-status banner; that lives in the pipeline pill',
        (tester) async {
      await pumpShell(tester, 3);

      expect(find.textContaining('Processing voice thought'), findsNothing);
      expect(find.text('3 pending'), findsNothing);
    });
  });
}
