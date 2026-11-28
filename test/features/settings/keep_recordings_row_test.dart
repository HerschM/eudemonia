import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/recording_retention.dart';
import 'package:eudemonia/features/capture/recording_retention_settings.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

import 'fake_permission_gateway.dart';
import 'settings_test_harness.dart';

class _MemoryStore implements RecordingRetentionStore {
  RecordingRetention? stored;

  @override
  Future<RecordingRetention?> load() async => stored;

  @override
  Future<void> save(RecordingRetention value) async => stored = value;
}

void main() {
  setUp(mockHardwareChannel);

  final now = DateTime(2026, 11, 28, 12);
  late NotesRepository repo;
  late Map<String, int> files;
  late _MemoryStore store;
  ProviderContainer? container;

  setUp(() {
    container = null;
    // As in the app: every change to a thought bumps the notes revision.
    repo = NotesRepository(onChanged: () => container?.read(notesRevisionProvider.notifier).bump());
    files = {};
    store = _MemoryStore();
  });

  Future<Note> addThought(String name, int bytes, {int ageDays = 100}) async {
    final path = '/rec/$name.wav';
    files[path] = bytes;
    final note = Note(
      originalAudioPath: path,
      correctedText: 'text $name',
      createdAt: now.subtract(Duration(days: ageDays)),
    );
    await repo.saveNote(note);
    return note;
  }

  Future<void> pumpSettings(WidgetTester tester, {double height = 3000}) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          folderStoreProvider.overrideWithValue(InMemoryFolderStore()),
          notesRepositoryProvider.overrideWithValue(repo),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
          recordingRetentionStoreProvider.overrideWithValue(store),
          recordingRetentionServiceProvider.overrideWithValue(
            RecordingRetentionService(
              notes: repo,
              busyAudioPaths: () => {},
              playingAudioPath: () => null,
              now: () => now,
              fileSize: (path) async => files[path],
              deleteFile: (path) async => files.remove(path),
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
  }

  Future<void> scrollTo(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  Future<void> openChooser(WidgetTester tester) async {
    await scrollTo(tester, 'keep_recordings_row');
    await tester.tap(find.byKey(const Key('keep_recordings_row')));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('the Capture part of Settings has the row, the choice, the helper line and the size line', (tester) async {
    await addThought('a', 1900000);
    await addThought('b', 3800000, ageDays: 3);
    await pumpSettings(tester);

    final captureTop = tester.getTopLeft(find.text('CAPTURE')).dy;
    final rowTop = tester.getTopLeft(find.byKey(const Key('keep_recordings_row'))).dy;
    final phoneMemoryTop = tester.getTopLeft(find.text('PHONE MEMORY AND TEMPERATURE')).dy;
    expect(rowTop, greaterThan(captureTop));
    expect(rowTop, lessThan(phoneMemoryTop));
    expect(find.text('Keep original recordings'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_row')), matching: find.text('Always')), findsOneWidget);
    expect(textOf(tester, 'keep_recordings_help'),
        'A recording takes about 1.9 MB per minute. Only the audio is removed; the text and your notes always stay.');
    expect(textOf(tester, 'recordings_size_line'), 'Recordings on this phone: 5.7 MB in 2 recordings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stored choice is shown', (tester) async {
    store.stored = RecordingRetention.days30;
    await pumpSettings(tester);
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_row')), matching: find.text('30 days')), findsOneWidget);
  });

  testWidgets('the chooser lists Always, 90, 30 and 7 days and marks the current one', (tester) async {
    await pumpSettings(tester);
    await openChooser(tester);

    for (final suffix in ['always', '90', '30', '7']) {
      expect(find.byKey(Key('keep_recordings_option_$suffix')), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_option_always')), matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_option_7')), matching: find.byIcon(Icons.check)), findsNothing);
  });

  testWidgets('a period that removes nothing now is set without asking', (tester) async {
    await addThought('young', 1900000, ageDays: 3);
    await pumpSettings(tester);
    await openChooser(tester);

    await tester.tap(find.byKey(const Key('keep_recordings_option_90')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm_delete_button')), findsNothing);
    expect(store.stored, RecordingRetention.days90);
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_row')), matching: find.text('90 days')), findsOneWidget);
    expect(files, isNotEmpty);
  });

  testWidgets('a period that removes recordings now asks first, with how many and how many MB, then removes them', (tester) async {
    final old1 = await addThought('old1', 1900000);
    await addThought('old2', 3800000, ageDays: 45);
    final young = await addThought('young', 1000000, ageDays: 2);
    await pumpSettings(tester);
    await openChooser(tester);

    await tester.tap(find.byKey(const Key('keep_recordings_option_30')));
    await tester.pumpAndSettle();

    expect(find.textContaining('30 days'), findsWidgets);
    expect(find.textContaining('2 recordings (5.7 MB)'), findsOneWidget);
    expect(find.textContaining('5.7 MB'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(store.stored, isNull, reason: 'nothing changes before the user confirms');
    expect(files.length, 3);

    await tester.tap(find.byKey(const Key('confirm_delete_button')));
    await tester.pumpAndSettle();

    expect(store.stored, RecordingRetention.days30);
    expect(files.keys, ['/rec/young.wav']);
    expect((await repo.getNoteById(old1.id))!.originalAudioPath, isNull);
    expect((await repo.getNoteById(old1.id))!.correctedText, 'text old1');
    expect((await repo.getNoteById(young.id))!.originalAudioPath, isNotNull);
    expect(textOf(tester, 'recordings_size_line'), 'Recordings on this phone: 1.0 MB in 1 recording');
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_row')), matching: find.text('30 days')), findsOneWidget);
  });

  testWidgets('a single recording is worded in the singular', (tester) async {
    await addThought('old', 1900000);
    await pumpSettings(tester);
    await openChooser(tester);
    await tester.tap(find.byKey(const Key('keep_recordings_option_7')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 recording (1.9 MB)'), findsOneWidget);
    expect(find.textContaining('1.9 MB'), findsWidgets);
  });

  testWidgets('Cancel leaves the setting and the recordings as they were', (tester) async {
    await addThought('old1', 1900000);
    await pumpSettings(tester);
    await openChooser(tester);
    await tester.tap(find.byKey(const Key('keep_recordings_option_7')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_delete_cancel')));
    await tester.pumpAndSettle();

    expect(store.stored, isNull);
    expect(files, isNotEmpty);
    expect(find.descendant(of: find.byKey(const Key('keep_recordings_row')), matching: find.text('Always')), findsOneWidget);
    expect(textOf(tester, 'recordings_size_line'), 'Recordings on this phone: 1.9 MB in 1 recording');
  });

  testWidgets('choosing Always never asks and removes nothing', (tester) async {
    store.stored = RecordingRetention.days7;
    await addThought('old', 1900000);
    await pumpSettings(tester);
    await openChooser(tester);

    await tester.tap(find.byKey(const Key('keep_recordings_option_always')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm_delete_button')), findsNothing);
    expect(store.stored, RecordingRetention.always);
    expect(files, isNotEmpty);
  });

  testWidgets('with no recordings the size line says so', (tester) async {
    await pumpSettings(tester);
    expect(textOf(tester, 'recordings_size_line'), 'No recordings are kept on this phone.');
  });

  testWidgets('on a 360 x 800 phone the row, its lines, the chooser and the dialog fit without overflow', (tester) async {
    await addThought('old', 1900000);
    await pumpSettings(tester, height: 800);

    await scrollTo(tester, 'recordings_size_line');
    for (final key in ['keep_recordings_row', 'keep_recordings_help', 'recordings_size_line']) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.left, greaterThanOrEqualTo(0), reason: key);
      expect(rect.right, lessThanOrEqualTo(360), reason: key);
    }

    await openChooser(tester);
    for (final suffix in ['always', '90', '30', '7']) {
      final rect = tester.getRect(find.byKey(Key('keep_recordings_option_$suffix')));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(800));
      expect(rect.height, greaterThanOrEqualTo(48), reason: 'a comfortable tap target');
    }

    await tester.tap(find.byKey(const Key('keep_recordings_option_7')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm_delete_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
