import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/written_note_capture.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

import '../capture/capture_test_doubles.dart';
import '../settings/fake_permission_gateway.dart';

const _channel = MethodChannel('com.eudemonia/hardware_buttons');

/// Mocks the platform channels the shell talks to; call from `setUp`, undo with [unmockShellChannels].
void mockShellChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, (MethodCall call) async => call.method == 'isForegroundServiceRunning');
  messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async => null);
}

void unmockShellChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, null);
  messenger.setMockMethodCallHandler(SystemChannels.platform, null);
}

SynthesisCluster shellTestCluster(int n, {bool unread = false}) => SynthesisCluster(
      clusterId: 'cluster_$n',
      sequenceNumber: '#S-${n.toString().padLeft(2, '0')}',
      folder: 'Ideas',
      synthesizedContent: '# Note $n\n\nBody of note $n',
      sessionStart: DateTime(2026, 11, 20, 9, 0).add(Duration(minutes: n)),
      sessionEnd: DateTime(2026, 11, 20, 9, 5).add(Duration(minutes: n)),
      sessionDuration: const Duration(minutes: 5),
      originNotes: const [],
      isUnread: unread,
    );

/// The shell on a 360 x 800 screen with in-memory stores and a fake native recorder.
class ShellHarness {
  late FakeNativeCaptureChannel native;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    List<Note> notes = const [],
    List<SynthesisCluster> clusters = const [],
    PipelineStatus? status,
    int? maxDurationMs,
    int initialIndex = 0,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    native = FakeNativeCaptureChannel()
      ..maxDurationMs = maxDurationMs
      ..saveOnStop = const PendingCapture(path: '/inbox/1.wav', startedAtMs: 1700000000000);
    final repo = NotesRepository();
    for (final n in notes) {
      await repo.saveNote(n);
    }
    container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(repo),
      runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
      nativeCaptureChannelProvider.overrideWithValue(native),
      captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
      modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
      synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
      writtenNoteCaptureProvider.overrideWith(
        (ref) => WrittenNoteCapture(
          notes: repo,
          nextSequenceNumber: (day) async => (await repo.maxDailySequenceFor(day)) + 1,
          onSaved: () {},
        ),
      ),
      if (status != null) pipelineStatusProvider.overrideWithValue(status),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: MainNavigationShell(initialIndex: initialIndex)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Loads Roboto from the Flutter SDK (found through `FLUTTER_ROOT`, which `flutter test` sets) so a
/// test measures text as a phone draws it; the test font is about 1.7 times wider. Returns false,
/// leaving the test font, when the SDK files cannot be found.
Future<bool> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final files = [for (final w in ['Regular', 'Medium', 'Bold']) File('$root/bin/cache/artifacts/material_fonts/Roboto-$w.ttf')];
  if (!files.every((f) => f.existsSync())) return false;
  final loader = FontLoader('Roboto');
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
  return true;
}
