import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/capture/presentation/capture_view_filter.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

import '../settings/fake_permission_gateway.dart';
import 'capture_test_doubles.dart';
import 'capture_view_test_helpers.dart';

class _Queue extends QueueItemsNotifier {
  final List<AudioQueueItem> initial;
  _Queue(this.initial);
  @override
  List<AudioQueueItem> build() => initial;
}

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  late ProviderContainer container;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpCapture(
    WidgetTester tester,
    List<Note> notes, {
    List<AudioQueueItem> queue = const [],
    // A transcribing card shimmers for ever, so such a screen never settles.
    bool settle = true,
    // The test font is wider than the real one: the transcribing card's line needs more than 360 dp here.
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWith(
            (ref) => NotesRepository(onChanged: () => ref.read(notesRevisionProvider.notifier).bump()),
          ),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(FakeNativeCaptureChannel()),
          captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          queueItemsProvider.overrideWith(() => _Queue(queue)),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
        ],
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(CaptureScreen)));
    final repo = container.read(notesRepositoryProvider);
    await tester.runAsync(() async {
      for (final n in notes) {
        await repo.saveNote(n);
      }
    });
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  String title(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('capture_view_title'))).data!;

  String count(WidgetTester tester, String row) => tester.widget<Text>(find.byKey(Key('${row}_count'))).data!;

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('capture_view_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> tapRow(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  // Two unread processed, one read processed, one read synthesized, one failed (a failed
  // recording counts as seen), one silent recording (not a failure).
  List<Note> mixed() => [
        Note(correctedText: 'Unread one.', createdAt: DateTime.now().subtract(const Duration(minutes: 1))),
        Note(correctedText: 'Unread two.', createdAt: DateTime.now().subtract(const Duration(minutes: 2))),
        Note(correctedText: 'Read one.', isRead: true, createdAt: DateTime.now().subtract(const Duration(minutes: 3))),
        Note(
            correctedText: 'Clubbed one.',
            state: ThoughtState.synthesized,
            isRead: true,
            createdAt: DateTime.now().subtract(const Duration(minutes: 4))),
        Note(
            correctedText: '',
            state: ThoughtState.failed,
            failureReason: 'Model crashed.',
            isRead: true,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5))),
        Note(
            correctedText: '',
            state: ThoughtState.failed,
            failureReason: silentRecordingMessage,
            isRead: true,
            createdAt: DateTime.now().subtract(const Duration(minutes: 6))),
      ];

  group('Capture view bar and panel (decision A, 2026-11-28)', () {
    testWidgets('one bar names the view; the two dropdowns are gone', (tester) async {
      await pumpCapture(tester, mixed());

      expect(title(tester), 'All thoughts');
      expect(find.byKey(const Key('capture_view_panel')), findsNothing);
      expect(find.byKey(const Key('capture_triage_filter_dropdown')), findsNothing);
      expect(find.byKey(const Key('capture_status_filter_dropdown')), findsNothing);
      expect(find.byType(DropdownButton<CaptureTriageFilter>), findsNothing);
      expect(find.byKey(const Key('capture_view_filter_badge')), findsNothing);
      await unmount(tester);
    });

    testWidgets('the panel has two groups with every choice and a count each', (tester) async {
      await pumpCapture(tester, mixed());
      await openPanel(tester);

      expect(find.byKey(const Key('capture_view_panel')), findsOneWidget);
      expect(find.text('SHOW'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      for (final label in ['All thoughts', 'Unread', 'Read', 'Any status', 'Processing', 'Processed', 'Synthesized', 'Failed']) {
        expect(find.descendant(of: find.byKey(const Key('capture_view_panel')), matching: find.text(label)), findsOneWidget,
            reason: label);
      }
      expect(count(tester, 'capture_view_show_all'), '6');
      expect(count(tester, 'capture_view_show_unread'), '2');
      expect(count(tester, 'capture_view_show_read'), '4');
      expect(count(tester, 'capture_view_status_all'), '6');
      expect(count(tester, 'capture_view_status_processing'), '0');
      expect(count(tester, 'capture_view_status_processed'), '3');
      expect(count(tester, 'capture_view_status_synthesized'), '1');
      expect(count(tester, 'capture_view_status_failed'), '1', reason: 'the silent recording is not a failure');
      await unmount(tester);
    });

    testWidgets('Show and Status combine: the title, the list and the counts follow', (tester) async {
      await pumpCapture(tester, mixed());
      await openPanel(tester);

      await tapRow(tester, 'capture_view_show_unread');
      expect(title(tester), 'Unread');
      expect(find.byKey(const Key('capture_view_filter_badge')), findsOneWidget);
      // The Status counts now count among the unread.
      expect(count(tester, 'capture_view_status_all'), '2');
      expect(count(tester, 'capture_view_status_processed'), '2');
      expect(count(tester, 'capture_view_status_failed'), '0');

      await tapRow(tester, 'capture_view_status_failed');
      expect(title(tester), 'Unread · Failed');
      // The Show counts now count among the failed.
      expect(count(tester, 'capture_view_show_all'), '1');
      expect(count(tester, 'capture_view_show_unread'), '0');
      expect(count(tester, 'capture_view_show_read'), '1');
      await tapRow(tester, 'capture_view_show_all');
      expect(title(tester), 'Failed');
      await tapRow(tester, 'capture_view_show_read');
      expect(title(tester), 'Read · Failed');

      await tapRow(tester, 'capture_view_status_all');
      expect(title(tester), 'Read');
      await tapRow(tester, 'capture_view_show_all');
      expect(title(tester), 'All thoughts');
      expect(find.byKey(const Key('capture_view_filter_badge')), findsNothing);
      await unmount(tester);
    });

    testWidgets('the list shows exactly what each combination means', (tester) async {
      await pumpCapture(tester, mixed());

      await pickCaptureView(tester, show: 'unread');
      expect(find.text('Unread one.'), findsOneWidget);
      expect(find.text('Unread two.'), findsOneWidget);
      expect(find.text('Read one.'), findsNothing);
      expect(find.text('Clubbed one.'), findsNothing);

      await pickCaptureView(tester, status: 'processed', show: 'read');
      expect(title(tester), 'Read · Processed');
      expect(find.text('Read one.'), findsOneWidget);
      expect(find.text('Unread one.'), findsNothing);
      expect(find.text('Clubbed one.'), findsNothing);

      await pickCaptureView(tester, status: 'synthesized', show: 'all');
      expect(find.text('Clubbed one.'), findsOneWidget);
      expect(find.text('Read one.'), findsNothing);

      await pickCaptureView(tester, status: 'failed');
      expect(find.text('Model crashed.'), findsOneWidget);
      expect(find.text(silentRecordingMessage), findsNothing, reason: 'a silent recording is not under Failed');

      await pickCaptureView(tester, status: 'all');
      await tester.scrollUntilVisible(find.text(silentRecordingMessage), 200);
      expect(find.text(silentRecordingMessage), findsOneWidget);

      await pickCaptureView(tester, show: 'read', status: 'processing');
      expect(find.text('No thoughts matching active filters'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a transcribing recording is listed under Processing', (tester) async {
      final item = AudioQueueItem(id: '1', audioFilePath: '/q.wav', recordedAt: DateTime.now());
      await pumpCapture(tester, [Note(correctedText: 'Stored one.')], queue: [item], settle: false, width: 600);

      await openPanel(tester);
      expect(count(tester, 'capture_view_status_processing'), '1');
      await tapRow(tester, 'capture_view_status_processing');
      expect(title(tester), 'Processing');
      expect(find.text('Stored one.'), findsNothing);
      expect(find.text('Transcribing & organizing speech...'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a thought read while Unread is open stays listed, though the counts move on', (tester) async {
      await pumpCapture(tester, mixed());
      await pickCaptureView(tester, show: 'unread');
      expect(find.text('Unread one.'), findsOneWidget);

      final stored = (await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!
          .firstWhere((n) => n.correctedText == 'Unread one.');
      await tester.runAsync(() => container.read(notesRepositoryProvider).markAsRead(stored.id));
      await tester.pumpAndSettle();

      expect(find.text('Unread one.'), findsOneWidget, reason: 'sticky while the Unread view is open');
      await openPanel(tester);
      expect(count(tester, 'capture_view_show_unread'), '1', reason: 'the count is the truth, not the sticky list');
      // Picking Unread again starts a fresh listing.
      await tapRow(tester, 'capture_view_show_unread');
      expect(find.text('Unread one.'), findsNothing);
      expect(find.text('Unread two.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a tap on the dimmed list or the bar button closes the panel; the choices stay', (tester) async {
      await pumpCapture(tester, mixed());
      await openPanel(tester);
      await tapRow(tester, 'capture_view_status_failed');

      expect(find.byKey(const Key('capture_view_panel')), findsOneWidget, reason: 'stays open to combine');
      await tester.tapAt(const Offset(345, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('capture_view_panel')), findsNothing);
      expect(title(tester), 'Failed');
      await unmount(tester);
    });

    testWidgets('the system back closes the panel before it leaves the screen', (tester) async {
      await pumpCapture(tester, mixed());
      await openPanel(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('capture_view_panel')), findsNothing);
      expect(find.byType(CaptureScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('360 dp: a long title stays on one line in the bar; the panel fits with every row visible',
        (tester) async {
      await pumpCapture(tester, mixed());
      await pickCaptureView(tester, show: 'unread', status: 'synthesized');
      expect(title(tester), 'Unread · Synthesized');
      final button = tester.getRect(find.byKey(const Key('capture_view_button')));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(360));

      await openPanel(tester);
      final panel = tester.getRect(find.byKey(const Key('capture_view_panel')));
      expect(panel.width, lessThanOrEqualTo(320));
      expect(panel.left, greaterThanOrEqualTo(0));
      for (final row in [
        for (final f in CaptureTriageFilter.values) 'capture_view_show_${f.name}',
        for (final f in CaptureStatusFilter.values) 'capture_view_status_${f.name}',
      ]) {
        final r = tester.getRect(find.byKey(Key(row)));
        expect(r.bottom, lessThanOrEqualTo(800), reason: row);
        expect(r.right, lessThanOrEqualTo(panel.right), reason: row);
        expect(r.height, greaterThanOrEqualTo(48), reason: '$row is a comfortable touch target');
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
