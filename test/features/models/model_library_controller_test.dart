import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_test_doubles.dart';

void main() {
  late FakeModelFilesChannel channel;
  late InMemoryModelSettingsStore store;
  late ProviderContainer container;

  const speech = ModelCatalogue.parakeetV3;
  const big = ModelCatalogue.qwen3_4b;
  const small = ModelCatalogue.qwen3_1_7b;

  ProviderContainer build() {
    container = ProviderContainer(overrides: [
      modelFilesChannelProvider.overrideWithValue(channel),
      modelSettingsStoreProvider.overrideWithValue(store),
    ]);
    // The controller reads files at construction, like the app does at launch.
    container.read(modelLibraryControllerProvider);
    container.read(modelSettingsProvider);
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  ModelLibraryController controller() => container.read(modelLibraryControllerProvider.notifier);
  ModelLibraryState library() => container.read(modelLibraryControllerProvider);
  ModelSettings settings() => container.read(modelSettingsProvider);

  setUp(() {
    channel = FakeModelFilesChannel();
    store = InMemoryModelSettingsStore();
  });

  group('aggregateAvailability', () {
    ModelAvailability of(Map<String, ModelFileStatus> files) => aggregateAvailability(speech, files);

    Map<String, ModelFileStatus> all(ModelFileState state, {String? reason}) => {
          for (final f in speech.files)
            f.relativePath: ModelFileStatus(
                relativePath: f.relativePath,
                state: state,
                downloadedBytes: state == ModelFileState.ready ? f.sizeBytes : 0,
                totalBytes: f.sizeBytes,
                reason: reason),
        };

    test('ready only when all four files are ready', () {
      final files = all(ModelFileState.ready);
      expect(of(files).kind, ModelAvailabilityKind.ready);
      expect(of(files).downloadedBytes, speech.totalBytes);

      files[speech.files.last.relativePath] = ModelFileStatus.absent(speech.files.last.relativePath);
      expect(of(files).kind, ModelAvailabilityKind.absent);
      expect(of(files).downloadedBytes, speech.totalBytes - speech.files.last.sizeBytes);
    });

    test('a failed file fails the model with its reason', () {
      final files = all(ModelFileState.running);
      files[speech.files[1].relativePath] =
          ModelFileStatus(relativePath: speech.files[1].relativePath, state: ModelFileState.failed, reason: 'checksum');
      final a = of(files);
      expect(a.kind, ModelAvailabilityKind.failed);
      expect(a.reason, 'checksum');
    });

    test('bytes are summed over the files and a paused file wins over running ones', () {
      final files = {
        speech.files[0].relativePath: ModelFileStatus(
            relativePath: speech.files[0].relativePath, state: ModelFileState.running, downloadedBytes: 1000),
        speech.files[1].relativePath: ModelFileStatus(
            relativePath: speech.files[1].relativePath,
            state: ModelFileState.paused,
            downloadedBytes: 500,
            reason: 'waiting_for_wifi'),
        speech.files[2].relativePath: ModelFileStatus.absent(speech.files[2].relativePath),
        speech.files[3].relativePath: ModelFileStatus(
            relativePath: speech.files[3].relativePath,
            state: ModelFileState.ready,
            downloadedBytes: speech.files[3].sizeBytes),
      };
      final a = of(files);
      expect(a.kind, ModelAvailabilityKind.paused);
      expect(a.reason, 'waiting_for_wifi');
      expect(a.downloadedBytes, 1500 + speech.files[3].sizeBytes);
      expect(a.totalBytes, speech.totalBytes);
      expect(a.fraction, closeTo(a.downloadedBytes / speech.totalBytes, 1e-9));
    });

    test('running is downloading; queued with nothing running waits; verifying only when nothing else is active', () {
      final queued = of(all(ModelFileState.queued));
      expect(queued.kind, ModelAvailabilityKind.paused);
      expect(queued.reason, 'queued');
      expect(of(all(ModelFileState.verifying)).kind, ModelAvailabilityKind.verifying);
      final mixed = all(ModelFileState.verifying);
      mixed[speech.files[0].relativePath] =
          ModelFileStatus(relativePath: speech.files[0].relativePath, state: ModelFileState.running);
      expect(of(mixed).kind, ModelAvailabilityKind.downloading);
    });

    test('no files at all is absent with zero bytes', () {
      final a = of(const {});
      expect(a.kind, ModelAvailabilityKind.absent);
      expect(a.downloadedBytes, 0);
      expect(a.fraction, 0);
    });
  });

  group('ModelLibraryController', () {
    testWidgets('reads the device and every file at start', (tester) async {
      channel.device = const DeviceInfo(totalRamMb: 5600, freeStorageBytes: 1);
      build();
      expect(library().loaded, isFalse);

      await settle(tester);

      expect(library().loaded, isTrue);
      expect(library().device.totalRamMb, 5600);
      expect(library().of(speech.id).kind, ModelAvailabilityKind.absent);
      expect(container.read(speechModelReadyProvider), isFalse);
      container.dispose();
    });

    testWidgets('the speech model is ready only when all four files are', (tester) async {
      for (final f in speech.files.take(3)) {
        channel.setFile(f.relativePath, ModelFileState.ready, downloaded: f.sizeBytes, total: f.sizeBytes);
      }
      build();
      await settle(tester);
      expect(container.read(speechModelReadyProvider), isFalse);

      channel.setModel(speech, ModelFileState.ready);
      await controller().refresh();
      await settle(tester);
      expect(container.read(speechModelReadyProvider), isTrue);
      container.dispose();
    });

    testWidgets('polling starts with a running transfer and stops when it finishes', (tester) async {
      channel.setModel(speech, ModelFileState.running);
      build();
      await settle(tester);
      final afterStart = channel.statusCalls;

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(channel.statusCalls, afterStart + 2);

      channel.setModel(speech, ModelFileState.ready);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      final afterFinish = channel.statusCalls;
      expect(library().of(speech.id).kind, ModelAvailabilityKind.ready);

      await tester.pump(const Duration(seconds: 5));
      expect(channel.statusCalls, afterFinish, reason: 'no reads once nothing is active');
      container.dispose();
    });

    testWidgets('an idle library never polls and leaves no timer behind', (tester) async {
      build();
      await settle(tester);
      final calls = channel.statusCalls;
      await tester.pump(const Duration(seconds: 10));
      expect(channel.statusCalls, calls);
      container.dispose();
    });

    testWidgets('a paused transfer keeps polling', (tester) async {
      channel.setModel(speech, ModelFileState.paused, reason: 'waiting_for_wifi');
      build();
      await settle(tester);
      final calls = channel.statusCalls;
      await tester.pump(const Duration(seconds: 1));
      expect(channel.statusCalls, calls + 1);
      expect(library().of(speech.id).reason, 'waiting_for_wifi');
      container.dispose();
    });

    testWidgets('onChanged refreshes without waiting for the next poll', (tester) async {
      build();
      await settle(tester);
      channel.setModel(speech, ModelFileState.ready);

      channel.emitChanged();
      await settle(tester);

      expect(container.read(speechModelReadyProvider), isTrue);
      container.dispose();
    });

    testWidgets('onSpeechModelReady fires once when the speech model turns ready, not before', (tester) async {
      build();
      var ready = 0;
      controller().onSpeechModelReady = () => ready++;
      await settle(tester);
      expect(ready, 0);

      channel.setModel(speech, ModelFileState.ready);
      channel.emitChanged();
      await settle(tester);
      expect(ready, 1);

      channel.emitChanged();
      await settle(tester);
      expect(ready, 1, reason: 'already ready: no second call');

      channel.files.clear();
      channel.emitChanged();
      await settle(tester);
      channel.setModel(speech, ModelFileState.ready);
      channel.emitChanged();
      await settle(tester);
      expect(ready, 2, reason: 'deleted and downloaded again');
      container.dispose();
    });

    testWidgets('a stored choice among two ready models is kept', (tester) async {
      store.stored = const ModelSettings(selectedLanguageModelId: 'qwen3-1.7b');
      channel.setModel(big, ModelFileState.ready);
      channel.setModel(small, ModelFileState.ready);
      build();
      await settle(tester);

      expect(settings().selectedLanguageModelId, small.id);
      expect(container.read(activeSynthesisProfileProvider), SynthesisModelProfile.qwen3_1_7b);
      container.dispose();
    });

    testWidgets('download starts every non-ready file with the title and the Wi-Fi setting', (tester) async {
      build();
      await settle(tester);
      final first = speech.files.first;
      channel.setFile(first.relativePath, ModelFileState.ready, downloaded: first.sizeBytes, total: first.sizeBytes);
      await controller().refresh();
      await settle(tester);

      await controller().download(speech.id);
      await settle(tester);

      expect(channel.downloads.map((d) => d['relativePath']),
          speech.files.skip(1).map((f) => f.relativePath).toList());
      expect(channel.downloads.every((d) => d['wifiOnly'] == true && d['title'] == 'Parakeet v3 (25 languages)'), isTrue);
      expect(channel.downloads.first['url'], speech.files[1].url);
      expect(library().of(speech.id).isBusy, isTrue);

      controller().setWifiOnly(false);
      channel.downloads.clear();
      await controller().download(big.id);
      expect(channel.downloads.single['wifiOnly'], false);
      await controller().cancel(speech.id);
      await controller().cancel(big.id);
      await settle(tester);
      container.dispose();
    });

    testWidgets('a refused download reads as failed for lack of space', (tester) async {
      channel.refuseDownloads = true;
      build();
      await settle(tester);

      await controller().download(big.id);
      await settle(tester);

      final a = library().of(big.id);
      expect(a.kind, ModelAvailabilityKind.failed);
      expect(a.reason, 'insufficient_space');
      container.dispose();
    });

    testWidgets('cancel stops the unfinished files and delete removes them all', (tester) async {
      channel.setModel(speech, ModelFileState.running);
      build();
      await settle(tester);

      await controller().cancel(speech.id);
      await settle(tester);
      expect(channel.cancels, speech.files.map((f) => f.relativePath).toList());
      expect(library().of(speech.id).reason, 'cancelled');

      await controller().delete(speech.id);
      await settle(tester);
      expect(channel.deletes, speech.files.map((f) => f.relativePath).toList());
      expect(library().of(speech.id).kind, ModelAvailabilityKind.absent);
      container.dispose();
    });

    testWidgets('a single downloaded fitting language model is chosen automatically', (tester) async {
      channel.setModel(big, ModelFileState.ready);
      build();
      await settle(tester);

      expect(settings().selectedLanguageModelId, big.id);
      expect(store.stored.selectedLanguageModelId, big.id);
      expect(container.read(activeSynthesisProfileProvider), SynthesisModelProfile.qwen3_4b);
      container.dispose();
    });

    testWidgets('nothing is chosen automatically when two fitting models are ready', (tester) async {
      channel.setModel(big, ModelFileState.ready);
      channel.setModel(small, ModelFileState.ready);
      build();
      await settle(tester);

      expect(settings().selectedLanguageModelId, isNull);
      expect(container.read(activeSynthesisProfileProvider), isNull);
      container.dispose();
    });

    testWidgets('a downloaded model that does not fit is not chosen and gives no profile', (tester) async {
      channel.device = const DeviceInfo(totalRamMb: 5600);
      channel.setModel(big, ModelFileState.ready);
      build();
      await settle(tester);

      expect(settings().selectedLanguageModelId, isNull);
      expect(container.read(activeSynthesisProfileProvider), isNull);
      container.dispose();
    });

    testWidgets('a lone downloaded 1.7B is chosen automatically on a phone that fits both', (tester) async {
      channel.device = const DeviceInfo(totalRamMb: 7600);
      channel.setModel(small, ModelFileState.ready);
      build();
      await settle(tester);

      expect(settings().selectedLanguageModelId, small.id);
      expect(container.read(activeSynthesisProfileProvider), SynthesisModelProfile.qwen3_1_7b);
      container.dispose();
    });

    testWidgets('a 6 GB phone cannot select the 4B but can select the 1.7B', (tester) async {
      channel.device = const DeviceInfo(totalRamMb: 5600);
      channel.setModel(big, ModelFileState.ready);
      build();
      await settle(tester);
      expect(controller().select(big.id), isFalse, reason: 'does not fit 5.6 GB');
      expect(settings().selectedLanguageModelId, isNull);

      channel.setModel(small, ModelFileState.ready);
      await controller().refresh();
      await settle(tester);
      expect(controller().select(small.id), isTrue);
      expect(settings().selectedLanguageModelId, small.id);
      expect(container.read(activeSynthesisProfileProvider), SynthesisModelProfile.qwen3_1_7b);
      container.dispose();
    });

    testWidgets('delete clears the selection of the deleted model', (tester) async {
      channel.setModel(big, ModelFileState.ready);
      build();
      await settle(tester);
      expect(settings().selectedLanguageModelId, big.id);

      await controller().delete(big.id);
      await settle(tester);

      expect(settings().selectedLanguageModelId, isNull);
      expect(container.read(activeSynthesisProfileProvider), isNull);
      expect(store.stored.selectedLanguageModelId, isNull);
      container.dispose();
    });

    testWidgets('select refuses a model that is not ready, does not fit or is not a language model', (tester) async {
      channel.device = const DeviceInfo(totalRamMb: 5600);
      channel.setModel(big, ModelFileState.ready);
      channel.setModel(small, ModelFileState.ready);
      build();
      await settle(tester);

      expect(controller().select(big.id), isFalse, reason: 'does not fit 5.6 GB');
      expect(controller().select(speech.id), isFalse, reason: 'not a language model');
      expect(controller().select('nope'), isFalse);
      // The 1.7B is the only downloaded model that fits, so it was chosen automatically.
      expect(settings().selectedLanguageModelId, small.id);
      expect(controller().select(small.id), isTrue);
      container.dispose();
    });

    testWidgets('select refuses a model that is not downloaded, then accepts it once ready', (tester) async {
      build();
      await settle(tester);
      channel.setModel(big, ModelFileState.ready);
      channel.setModel(small, ModelFileState.running);
      await controller().refresh();
      await settle(tester);
      // The ready model was chosen automatically; switching to the one still downloading is refused.
      expect(settings().selectedLanguageModelId, big.id);
      expect(controller().select(small.id), isFalse);

      channel.setModel(small, ModelFileState.ready);
      await controller().refresh();
      await settle(tester);
      expect(controller().select(small.id), isTrue);
      expect(settings().selectedLanguageModelId, small.id);
      expect(container.read(activeSynthesisProfileProvider), SynthesisModelProfile.qwen3_1_7b);
      container.dispose();
    });

    testWidgets('setup is offered only after settings and files are read, with no speech model', (tester) async {
      build();
      expect(container.read(shouldOfferModelSetupProvider), isFalse);
      await settle(tester);
      expect(container.read(shouldOfferModelSetupProvider), isTrue);

      container.read(modelSettingsProvider.notifier).markSetupShown();
      expect(container.read(shouldOfferModelSetupProvider), isFalse);
      container.dispose();
    });

    testWidgets('setup is not offered when the speech model is already there', (tester) async {
      channel.setModel(speech, ModelFileState.ready);
      build();
      await settle(tester);
      expect(container.read(shouldOfferModelSetupProvider), isFalse);
      container.dispose();
    });
  });

  group('ModelSettings', () {
    testWidgets('wifiOnly defaults to true and is stored', (tester) async {
      build();
      await settle(tester);
      expect(settings().wifiOnly, isTrue);
      expect(settings().loaded, isTrue);

      controller().setWifiOnly(false);
      await settle(tester);
      expect(store.stored.wifiOnly, isFalse);
      container.dispose();
    });

    testWidgets('unreadable storage falls back to defaults and does not nag with setup', (tester) async {
      container = ProviderContainer(overrides: [
        modelFilesChannelProvider.overrideWithValue(channel),
        modelSettingsStoreProvider.overrideWithValue(_BrokenStore()),
      ]);
      container.read(modelLibraryControllerProvider);
      container.read(modelSettingsProvider);
      await settle(tester);

      expect(settings().loaded, isTrue);
      expect(settings().wifiOnly, isTrue);
      expect(container.read(shouldOfferModelSetupProvider), isFalse);
      container.dispose();
    });
  });

  test('SharedPreferences store round-trips every field', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefsStore = SharedPreferencesModelSettingsStore();
    final fresh = await prefsStore.load();
    expect(fresh.wifiOnly, isTrue);
    expect(fresh.setupShown, isFalse);
    expect(fresh.selectedLanguageModelId, isNull);

    await prefsStore.save(const ModelSettings(selectedLanguageModelId: 'qwen3-4b', wifiOnly: false, setupShown: true));
    final back = await prefsStore.load();
    expect(back.selectedLanguageModelId, 'qwen3-4b');
    expect(back.wifiOnly, isFalse);
    expect(back.setupShown, isTrue);

    await prefsStore.save(const ModelSettings(wifiOnly: false, setupShown: true));
    expect((await prefsStore.load()).selectedLanguageModelId, isNull);
  });

  test('the fake channel refuses use before its listener is set', () async {
    await expectLater(FakeModelFilesChannel().getDeviceInfo(), throwsStateError);
  });
}

class _BrokenStore implements ModelSettingsStore {
  @override
  Future<ModelSettings> load() async => throw StateError('disk unreadable');

  @override
  Future<void> save(ModelSettings settings) async => throw StateError('disk unwritable');
}
