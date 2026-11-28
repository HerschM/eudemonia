import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_test_doubles.dart';

/// Remembers every directory it was initialised from and fails loudly when used while unloaded.
class _Stt extends STTService {
  final List<String> loadedFrom = [];
  int disposals = 0;
  bool _ready = false;

  @override
  bool get isInitialized => _ready;

  @override
  Future<void> initialize(String modelDir) async {
    loadedFrom.add(modelDir);
    _ready = true;
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!_ready) throw StateError('STT used before initialize');
    return 'a thought';
  }

  @override
  void dispose() {
    disposals++;
    _ready = false;
  }
}

void main() {
  // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
  // parakeet v3 since we've not tested the european languages model writing cleanup." Parakeet v2 is the only
  // speech model; the tests below that used two speech models now use this one.
  const v2 = ModelCatalogue.parakeetV2;
  const big = ModelCatalogue.qwen3_4b;

  late FakeModelFilesChannel channel;
  late InMemoryModelSettingsStore store;
  late ProviderContainer container;

  /// Starts the app's model library on what [channel] and [store] hold, and lets it read.
  Future<void> start() async {
    container = ProviderContainer(overrides: [
      modelFilesChannelProvider.overrideWithValue(channel),
      modelSettingsStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    container.read(modelLibraryControllerProvider);
    container.read(modelSettingsProvider);
    await pumpEventQueue(times: 50);
  }

  ModelLibraryController controller() => container.read(modelLibraryControllerProvider.notifier);
  ModelSettings settings() => container.read(modelSettingsProvider);
  bool ready() => container.read(speechModelReadyProvider);

  /// Native reports a change and the controller reads the files again.
  Future<void> filesChanged() async {
    channel.emitChanged();
    await pumpEventQueue(times: 50);
  }

  setUp(() {
    channel = FakeModelFilesChannel();
    store = InMemoryModelSettingsStore();
  });

  group('which speech model is chosen', () {
    // Was: v3 files and no stored choice ends up with v3 chosen.
    test('an install that has the v2 files and no stored choice ends up with v2 chosen', () async {
      channel.setModel(v2, ModelFileState.ready);
      await start();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(ready(), isTrue);
      expect(container.read(selectedSpeechModelProvider), v2);
      expect(store.stored.selectedSpeechModelId, v2.id, reason: 'the automatic choice is stored');
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // No migration code: a stored choice naming the removed v3 model is simply no choice, and v2 is chosen.
    test('a stored choice naming the removed v3 model is replaced by the downloaded v2', () async {
      store.stored = const ModelSettings(selectedSpeechModelId: 'parakeet-tdt-0.6b-v3-int8');
      channel.setModel(v2, ModelFileState.ready);
      await start();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(ready(), isTrue);
      expect(store.stored.selectedSpeechModelId, v2.id);
    });

    test('a lone downloaded v2 is chosen automatically', () async {
      channel.setModel(v2, ModelFileState.ready);
      await start();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(ready(), isTrue);
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: two usable models and no stored choice: nothing is chosen and nothing is ready.
    test('exactly one speech model is offered and it is chosen automatically once its files are present', () async {
      expect(ModelCatalogue.speechModels, [v2]);
      await start();
      expect(settings().selectedSpeechModelId, isNull);
      expect(ready(), isFalse);

      channel.setModel(v2, ModelFileState.ready);
      await filesChanged();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(container.read(selectedSpeechModelProvider), v2);
      expect(ready(), isTrue);
      expect(container.read(speechModelAvailabilityProvider).isReady, isTrue);
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: a stored choice is kept when both models are ready.
    test('a stored choice is kept when its model is ready', () async {
      store.stored = const ModelSettings(selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8');
      channel.setModel(v2, ModelFileState.ready);
      await start();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(ready(), isTrue);
    });

    test('a stored choice is kept even when its files are missing, and then nothing is ready', () async {
      store.stored = const ModelSettings(selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8');
      await start();

      expect(settings().selectedSpeechModelId, v2.id, reason: 'a stored choice is never replaced automatically');
      expect(ready(), isFalse);
      expect(container.read(speechModelAvailabilityProvider).kind, ModelAvailabilityKind.absent);
    });

    test('nothing downloaded: nothing is chosen, not ready, and the first-launch setup is offered', () async {
      await start();

      expect(settings().selectedSpeechModelId, isNull);
      expect(ready(), isFalse);
      expect(container.read(shouldOfferModelSetupProvider), isTrue);
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: a model that arrives while another is in use does not take over.
    test('a files change while the chosen model stays ready changes nothing and tells no one', () async {
      channel.setModel(v2, ModelFileState.ready);
      await start();
      var readyCalls = 0;
      controller().onSpeechModelReady = () => readyCalls++;

      await filesChanged();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(ready(), isTrue);
      expect(readyCalls, 0, reason: 'no recording was waiting: the chosen model was ready all along');
    });

    test('the first model to finish downloading is chosen and tells the queue', () async {
      await start();
      var readyCalls = 0;
      controller().onSpeechModelReady = () => readyCalls++;

      channel.setModel(v2, ModelFileState.ready);
      await filesChanged();

      expect(settings().selectedSpeechModelId, v2.id);
      expect(ready(), isTrue);
      expect(readyCalls, 1);
    });

    test('while no model is chosen the banner follows the transfer furthest along', () async {
      // Was: both models ready and none chosen. With one speech model, none chosen means none downloaded.
      await start();
      expect(container.read(speechModelAvailabilityProvider), ModelAvailability.absent);

      final progress = ModelAvailability(ModelAvailabilityKind.downloading, downloadedBytes: 1, totalBytes: 2);
      expect(furthestSpeechTransfer([ModelAvailability.absent, progress]), progress);
      const failed = ModelAvailability(ModelAvailabilityKind.failed, reason: 'checksum');
      expect(furthestSpeechTransfer([failed, progress]), progress);
      expect(furthestSpeechTransfer([failed, ModelAvailability.absent]), failed);
      expect(
          furthestSpeechTransfer([
            const ModelAvailability(ModelAvailabilityKind.ready),
            ModelAvailability.absent,
          ]),
          ModelAvailability.absent);
    });
  });

  group('choosing and deleting speech models', () {
    test('selectSpeech accepts a ready speech model only', () async {
      channel.setModel(big, ModelFileState.ready);
      channel.setModel(v2, ModelFileState.running);
      await start();

      expect(controller().selectSpeech(v2.id), isFalse, reason: 'still downloading');
      expect(controller().selectSpeech(big.id), isFalse, reason: 'a writing model');
      expect(controller().selectSpeech('nope'), isFalse);
      expect(controller().selectSpeech('parakeet-tdt-0.6b-v3-int8'), isFalse, reason: 'the removed model');
      expect(settings().selectedSpeechModelId, isNull);

      channel.setModel(v2, ModelFileState.ready);
      await filesChanged();
      expect(controller().selectSpeech(v2.id), isTrue);
      expect(settings().selectedSpeechModelId, v2.id);
      expect(store.stored.selectedSpeechModelId, v2.id);
      expect(settings().selectedLanguageModelId, big.id, reason: 'the writing choice is separate');
    });

    test('the writing-model select does not accept a speech model, as before', () async {
      channel.setModel(v2, ModelFileState.ready);
      await start();
      expect(controller().select(v2.id), isFalse);
    });

    test('choosing the model already in use changes nothing and unloads nothing', () async {
      channel.setModel(v2, ModelFileState.ready);
      await start();
      var changes = 0;
      controller().onSpeechSelectionChanged = () => changes++;

      expect(controller().selectSpeech(v2.id), isTrue);
      expect(changes, 0);
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: choosing a model while none was chosen tells the queue once (two ready models, the user picks).
    test('the speech model chosen automatically tells the queue once; choosing it again waits for no one', () async {
      await start();
      var readyCalls = 0;
      controller().onSpeechModelReady = () => readyCalls++;

      channel.setModel(v2, ModelFileState.ready);
      await filesChanged();
      expect(ready(), isTrue);
      expect(readyCalls, 1);

      expect(controller().selectSpeech(v2.id), isTrue);
      expect(readyCalls, 1, reason: 'choosing the model already in use waits for no one');
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: deleting the chosen model clears the choice and, with one other ready, chooses that one.
    test('deleting the chosen model clears the choice and tells the owner of the loaded model once', () async {
      channel.setModel(v2, ModelFileState.ready);
      store.stored = const ModelSettings(selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8');
      await start();
      var changes = 0;
      controller().onSpeechSelectionChanged = () => changes++;

      await controller().delete(v2.id);
      await pumpEventQueue(times: 50);

      expect(channel.deletes, v2.files.map((f) => f.relativePath).toList());
      expect(settings().selectedSpeechModelId, isNull);
      expect(ready(), isFalse);
      expect(changes, 1, reason: 'cleared; no other speech model exists to be chosen');
    });

    test('deleting the only model clears the choice and nothing is ready', () async {
      channel.setModel(v2, ModelFileState.ready);
      await start();
      expect(settings().selectedSpeechModelId, v2.id);

      await controller().delete(v2.id);
      await pumpEventQueue(times: 50);

      expect(settings().selectedSpeechModelId, isNull);
      expect(store.stored.selectedSpeechModelId, isNull);
      expect(ready(), isFalse);
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: deleting a speech model that is not chosen leaves the choice (two speech models).
    test('deleting a writing model leaves the speech choice and unloads nothing', () async {
      channel.setModel(v2, ModelFileState.ready);
      channel.setModel(big, ModelFileState.ready);
      await start();
      var changes = 0;
      controller().onSpeechSelectionChanged = () => changes++;

      await controller().delete(big.id);
      await pumpEventQueue(times: 50);

      expect(settings().selectedSpeechModelId, v2.id);
      expect(changes, 0);
      expect(ready(), isTrue);
    });

  });

  group('switching the speech model while one is in memory', () {
    late _Stt stt;
    late ModelLifecycleManager manager;

    Future<void> startWithManager() async {
      await start();
      stt = _Stt();
      manager = ModelLifecycleManager(
        stt,
        modelsDirResolver: () async => '/models',
        speechModelDirName: () => container.read(selectedSpeechModelProvider)?.directory,
      );
      unloadSpeechModelOnSwitch(controller(), manager);
      addTearDown(manager.dispose);
    }

    test('the chosen model\'s own directory is loaded', () async {
      channel.setModel(v2, ModelFileState.ready);
      await startWithManager();

      await manager.ensureModelsLoaded();

      expect(stt.loadedFrom, ['/models/parakeet-v2']);
    });

    // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
    // parakeet v3 since we've not tested the european languages model writing cleanup."
    // Was: choosing another model unloads the loaded one, and the next load reads the new directory (v3 -> v2).
    test('a stored choice naming the removed v3 model loads the v2 directory', () async {
      channel.setModel(v2, ModelFileState.ready);
      store.stored = const ModelSettings(selectedSpeechModelId: 'parakeet-tdt-0.6b-v3-int8');
      await startWithManager();

      await manager.ensureModelsLoaded();

      expect(stt.loadedFrom, ['/models/parakeet-v2']);
      expect(manager.state, ModelLifecycleState.ready);
    });

    test('re-choosing the loaded model keeps it in memory', () async {
      channel.setModel(v2, ModelFileState.ready);
      await startWithManager();
      await manager.ensureModelsLoaded();

      expect(controller().selectSpeech(v2.id), isTrue);
      await pumpEventQueue(times: 20);

      expect(manager.state, ModelLifecycleState.ready);
      expect(stt.loadedFrom, ['/models/parakeet-v2']);
    });

    test('deleting the loaded model unloads it', () async {
      channel.setModel(v2, ModelFileState.ready);
      await startWithManager();
      await manager.ensureModelsLoaded();

      await controller().delete(v2.id);
      await pumpEventQueue(times: 50);

      expect(manager.state, ModelLifecycleState.unloaded);
    });

    test('with no model chosen a load fails like a missing model, and recordings wait', () async {
      // Was: both models ready and none chosen. With one speech model, none chosen means none downloaded.
      await startWithManager();
      expect(settings().selectedSpeechModelId, isNull);

      await expectLater(manager.ensureModelsLoaded(), throwsA(isA<Exception>()));

      expect(stt.loadedFrom, isEmpty, reason: 'no model is mapped when none is chosen');
      expect(manager.state, ModelLifecycleState.unloaded);
    });

    test('without a resolver the manager loads the catalogue\'s speech model folder', () async {
      final plain = _Stt();
      final unresolved = ModelLifecycleManager(plain, modelsDirResolver: () async => '/models');
      addTearDown(unresolved.dispose);
      await unresolved.ensureModelsLoaded();
      expect(plain.loadedFrom, ['/models/${ModelCatalogue.parakeetV2.directory}']);
      expect(plain.loadedFrom, ['/models/parakeet-v2']);
    });
  });

  test('the app\'s lifecycle provider wires the unload callback and releases it with the container', () async {
    await start();
    final models = controller();
    expect(models.onSpeechSelectionChanged, isNull);

    container.read(modelLifecycleManagerProvider);
    expect(models.onSpeechSelectionChanged, isNotNull);

    container.dispose();
    expect(models.onSpeechSelectionChanged, isNull);
  });

  test('the stored choice of speech model round-trips through SharedPreferences', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefsStore = SharedPreferencesModelSettingsStore();
    expect((await prefsStore.load()).selectedSpeechModelId, isNull);

    await prefsStore.save(const ModelSettings(selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8', setupShown: true));
    final back = await prefsStore.load();
    expect(back.selectedSpeechModelId, 'parakeet-tdt-0.6b-v2-int8');
    expect(back.selectedLanguageModelId, isNull);

    await prefsStore.save(const ModelSettings(setupShown: true));
    expect((await prefsStore.load()).selectedSpeechModelId, isNull);
  });

  test('copyWith keeps and clears the two choices independently', () {
    const both = ModelSettings(selectedLanguageModelId: 'qwen3-4b', selectedSpeechModelId: 'parakeet-tdt-0.6b-v2-int8');
    expect(both.copyWith(clearSpeechSelection: true).selectedSpeechModelId, isNull);
    expect(both.copyWith(clearSpeechSelection: true).selectedLanguageModelId, 'qwen3-4b');
    expect(both.copyWith(clearSelection: true).selectedSpeechModelId, 'parakeet-tdt-0.6b-v2-int8');
    expect(both.copyWith(clearSelection: true).selectedLanguageModelId, isNull);
  });
}
