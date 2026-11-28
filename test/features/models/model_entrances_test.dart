import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../capture/capture_test_doubles.dart';
import '../settings/fake_permission_gateway.dart';
import 'model_test_doubles.dart';

class _FakeQueueItemsNotifier extends QueueItemsNotifier {
  @override
  List<Never> build() => const [];
}

/// Counts runs; any other use is a mistake in the test.
class _CountingRunner implements SynthesisRunner {
  int runs = 0;

  @override
  Future<SynthesisRunResult> run({required bool manual}) async {
    runs++;
    return SynthesisRunResult.completed;
  }

  @override
  bool get isRunning => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const hardwareChannel = MethodChannel('com.eudemonia/hardware_buttons');
  const speech = ModelCatalogue.parakeetV3;
  const big = ModelCatalogue.qwen3_4b;

  late FakeModelFilesChannel files;
  late InMemoryModelSettingsStore store;

  setUp(() {
    files = FakeModelFilesChannel();
    store = InMemoryModelSettingsStore(stored: const ModelSettings(setupShown: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hardwareChannel, (call) async => call.method == 'isForegroundServiceRunning');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hardwareChannel, null);
  });

  List<Override> modelOverrides() => [
        modelFilesChannelProvider.overrideWithValue(files),
        modelSettingsStoreProvider.overrideWithValue(store),
      ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Capture screen banner (FR16.2)', () {
    Future<void> pumpCapture(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...modelOverrides(),
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(FakeNativeCaptureChannel()),
          captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          queueItemsProvider.overrideWith(_FakeQueueItemsNotifier.new),
        ],
        child: const MaterialApp(home: CaptureScreen()),
      ));
      await settle(tester);
    }

    testWidgets('without the speech model it says so and Set up opens the setup screen', (tester) async {
      await pumpCapture(tester);

      expect(find.text('Speech model needed to turn recordings into text.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('capture_speech_model_setup')));
      await tester.pumpAndSettle();

      expect(find.text('On-device models'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('while it downloads the banner shows the percentage and no Set up button', (tester) async {
      for (final f in speech.files) {
        files.setFile(f.relativePath, ModelFileState.running, total: f.sizeBytes);
      }
      files.setFile(speech.files.first.relativePath, ModelFileState.running,
          downloaded: (speech.totalBytes * 0.45).ceil(), total: speech.files.first.sizeBytes);
      await pumpCapture(tester);

      expect(find.text('Downloading speech model… 45%'), findsOneWidget);
      expect(find.byKey(const Key('capture_speech_model_setup')), findsNothing);
      await unmount(tester);
    });

    testWidgets('two speech models downloaded and none chosen: the banner still asks, and choosing one hides it', (tester) async {
      files.setModel(speech, ModelFileState.ready);
      files.setModel(ModelCatalogue.parakeetV2, ModelFileState.ready);
      await pumpCapture(tester);
      expect(find.text('Speech model needed to turn recordings into text.'), findsOneWidget);
      await unmount(tester);

      store.stored = const ModelSettings(setupShown: true, selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8');
      await pumpCapture(tester);
      expect(find.byKey(const Key('capture_speech_model_banner')), findsNothing);
      await unmount(tester);
    });

    testWidgets('once the speech model is ready the banner is gone', (tester) async {
      files.setModel(speech, ModelFileState.ready);
      await pumpCapture(tester);

      expect(find.byKey(const Key('capture_speech_model_banner')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Synthesis screen without a writing model (FR16.5)', () {
    late _CountingRunner runner;

    Future<void> pumpSynthesis(WidgetTester tester) async {
      phone(tester);
      runner = _CountingRunner();
      final notes = NotesRepository();
      await notes.saveNote(Note(correctedText: 'A fresh thought', state: ThoughtState.processed));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...modelOverrides(),
          notesRepositoryProvider.overrideWithValue(notes),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
          synthesisRunnerProvider.overrideWithValue(runner),
        ],
        child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
      ));
      await settle(tester);
    }

    testWidgets('a card asks for a model and the Synthesize buttons open setup instead of running', (tester) async {
      await pumpSynthesis(tester);

      expect(find.text('Choose a writing model to turn your thoughts into notes.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('synthesize_now_banner_button')));
      await tester.pumpAndSettle();

      expect(runner.runs, 0);
      expect(find.text('On-device models'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Choose model opens the setup screen', (tester) async {
      await pumpSynthesis(tester);
      await tester.tap(find.byKey(const Key('choose_writing_model_button')));
      await tester.pumpAndSettle();
      expect(find.text('On-device models'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('with a chosen, downloaded model there is no card and the button runs synthesis', (tester) async {
      files.setModel(big, ModelFileState.ready);
      await pumpSynthesis(tester);

      expect(find.byKey(const Key('choose_writing_model_card')), findsNothing);
      await tester.tap(find.byKey(const Key('synthesize_now_banner_button')));
      await tester.pump();
      await tester.pump();

      expect(runner.runs, 1);
      expect(find.text('On-device models'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });
  });

  group('Settings: ON-DEVICE MODELS', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...modelOverrides(),
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('rows show what is missing and open the setup screen', (tester) async {
      await pumpSettings(tester);

      expect(find.text('ON-DEVICE MODELS'), findsOneWidget);
      expect(find.text('Speech model · Not downloaded'), findsOneWidget);
      expect(find.text('Writing model · Not chosen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_writing_model_row')));
      await tester.pumpAndSettle();
      expect(find.text('On-device models'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('rows show the ready speech model and the chosen writing model', (tester) async {
      files.setModel(speech, ModelFileState.ready);
      files.setModel(big, ModelFileState.ready);
      await pumpSettings(tester);

      expect(find.text('Speech model · Parakeet v3 (25 languages)'), findsOneWidget);
      expect(find.text('Writing model · Qwen3 4B'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('names the chosen model, v2 included', (tester) async {
      files.setModel(ModelCatalogue.parakeetV2, ModelFileState.ready);
      await pumpSettings(tester);

      expect(find.text('Speech model · Parakeet v2 (English)'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow at 360 dp');
      await unmount(tester);
    });

    testWidgets('two downloaded and none chosen reads Not chosen', (tester) async {
      files.setModel(speech, ModelFileState.ready);
      files.setModel(ModelCatalogue.parakeetV2, ModelFileState.ready);
      await pumpSettings(tester);

      expect(find.text('Speech model · Not chosen'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a chosen model that is downloading shows its progress', (tester) async {
      store.stored = const ModelSettings(setupShown: true, selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8');
      final v2 = ModelCatalogue.parakeetV2;
      files.setFile(v2.files[0].relativePath, ModelFileState.running,
          downloaded: v2.files[0].sizeBytes ~/ 2, total: v2.files[0].sizeBytes);
      await pumpSettings(tester);

      expect(find.textContaining('Speech model · Downloading'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('First-launch setup (FR16.1)', () {
    Future<void> pumpShell(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...modelOverrides(),
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(FakeNativeCaptureChannel()),
          captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          queueItemsProvider.overrideWith(_FakeQueueItemsNotifier.new),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
        ],
        child: const MaterialApp(home: MainNavigationShell()),
      ));
      await settle(tester);
    }

    testWidgets('opens the setup screen once and remembers it', (tester) async {
      store.stored = const ModelSettings();
      await pumpShell(tester);
      await tester.pumpAndSettle();

      expect(find.text('On-device models'), findsOneWidget);
      expect(store.stored.setupShown, isTrue);

      await tester.tap(find.byKey(const Key('model_setup_back_button')));
      await tester.pumpAndSettle();
      expect(find.text('On-device models'), findsNothing);
      await settle(tester);
      expect(find.text('On-device models'), findsNothing, reason: 'not offered a second time');
      await unmount(tester);
    });

    testWidgets('is not opened again once it has been shown', (tester) async {
      await pumpShell(tester);
      await tester.pumpAndSettle();
      expect(find.text('On-device models'), findsNothing);
      await unmount(tester);
    });

    testWidgets('is not opened when the speech model is already on the phone', (tester) async {
      store.stored = const ModelSettings();
      files.setModel(speech, ModelFileState.ready);
      await pumpShell(tester);
      await tester.pumpAndSettle();

      expect(find.text('On-device models'), findsNothing);
      expect(store.stored.setupShown, isFalse);
      await unmount(tester);
    });
  });
}
