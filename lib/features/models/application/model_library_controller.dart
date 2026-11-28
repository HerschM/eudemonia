import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';

export 'package:eudemonia/features/models/domain/model_availability.dart';

/// Combines the per-file states of [spec] into one. Ready only when every file is ready; failed
/// when any file failed; otherwise the most active state wins.
ModelAvailability aggregateAvailability(ModelSpec spec, Map<String, ModelFileStatus> files) {
  final statuses = [
    for (final f in spec.files) files[f.relativePath] ?? ModelFileStatus.absent(f.relativePath),
  ];
  var downloaded = 0;
  for (var i = 0; i < statuses.length; i++) {
    downloaded += statuses[i].state == ModelFileState.ready ? spec.files[i].sizeBytes : statuses[i].downloadedBytes;
  }
  final total = spec.totalBytes;
  ModelAvailability make(ModelAvailabilityKind kind, {String? reason}) =>
      ModelAvailability(kind, downloadedBytes: downloaded.clamp(0, total), totalBytes: total, reason: reason);

  ModelFileStatus? first(ModelFileState state) => statuses.where((s) => s.state == state).firstOrNull;

  final failed = first(ModelFileState.failed);
  if (failed != null) return make(ModelAvailabilityKind.failed, reason: failed.reason ?? 'unknown');
  if (statuses.every((s) => s.state == ModelFileState.ready)) return make(ModelAvailabilityKind.ready);
  final paused = first(ModelFileState.paused);
  if (paused != null) return make(ModelAvailabilityKind.paused, reason: paused.reason ?? 'unknown');
  if (statuses.any((s) => s.state == ModelFileState.running)) return make(ModelAvailabilityKind.downloading);
  // Nothing is moving yet: the system has the transfer but waits for a network it may use
  // (with Wi-Fi only, that is where a phone on mobile data stays).
  if (statuses.any((s) => s.state == ModelFileState.queued)) {
    return make(ModelAvailabilityKind.paused, reason: 'queued');
  }
  if (statuses.any((s) => s.state == ModelFileState.verifying)) return make(ModelAvailabilityKind.verifying);
  return make(ModelAvailabilityKind.absent);
}

/// Transient state of the downloads and of the phone. The user's choices (selected model,
/// Wi-Fi only) live in [ModelSettings].
@immutable
class ModelLibraryState {
  /// The first reading of the files has finished; until then every model reads as absent.
  final bool loaded;
  final DeviceInfo device;
  final Map<String, ModelAvailability> availability;
  final Map<String, ModelFileStatus> files;

  const ModelLibraryState({
    this.loaded = false,
    this.device = DeviceInfo.unknown,
    this.availability = const {},
    this.files = const {},
  });

  ModelAvailability of(String modelId) => availability[modelId] ?? ModelAvailability.absent;

  ModelLibraryState copyWith({
    bool? loaded,
    DeviceInfo? device,
    Map<String, ModelAvailability>? availability,
    Map<String, ModelFileStatus>? files,
  }) =>
      ModelLibraryState(
        loaded: loaded ?? this.loaded,
        device: device ?? this.device,
        availability: availability ?? this.availability,
        files: files ?? this.files,
      );
}

/// Reads the state of the model files from native code, starts and stops their downloads and
/// keeps the selection of the speech and language models consistent with what is on the phone.
///
/// Progress is polled once a second, only while a file is queued, running, paused or being
/// verified; native `onChanged` events and app resumes (via [refresh]) also refresh it.
class ModelLibraryController extends Notifier<ModelLibraryState> {
  static const Duration pollInterval = Duration(seconds: 1);

  /// Called each time the chosen speech model turns from missing to ready, so recordings that
  /// waited for it are transcribed. Set by whoever owns the queue; a plain callback because it
  /// must fire even when no screen is listening.
  void Function()? onSpeechModelReady;

  /// Called each time the chosen speech model changes or is cleared, so a model still in memory
  /// is unloaded and the next transcription loads the new one. Set by whoever owns the speech
  /// model's lifecycle; a plain callback for the same reason as [onSpeechModelReady].
  void Function()? onSpeechSelectionChanged;

  Timer? _timer;
  Future<void> _chain = Future.value();
  bool _statusPending = false;

  ModelFilesChannel get _channel => ref.read(modelFilesChannelProvider);

  List<ModelSpec> get _trackedModels => [...ModelCatalogue.speechModels, ...ModelCatalogue.languageModels];

  @override
  ModelLibraryState build() {
    final channel = _channel;
    channel.setChangedListener(() => unawaited(_refreshStatus()));
    ref.onDispose(() {
      channel.clearChangedListener();
      _timer?.cancel();
      _timer = null;
    });
    unawaited(refresh());
    return const ModelLibraryState();
  }

  /// Reads the phone's memory and storage and the state of every file.
  Future<void> refresh() => _enqueue(() async {
        // The stored choices must be known before the automatic choice can be made.
        await ref.read(modelSettingsProvider.notifier).loadedFuture;
        if (!ref.mounted) return;
        final device = await _channel.getDeviceInfo();
        if (!ref.mounted) return;
        state = state.copyWith(device: device);
        await _readStatus();
      });

  Future<void> _refreshStatus() => _enqueue(_readStatus);

  /// Runs reads one after the other so an older answer never overwrites a newer one.
  Future<void> _enqueue(Future<void> Function() job) {
    final next = _chain.then((_) => job()).catchError((Object e, StackTrace stack) {
      if (ref.mounted) ref.read(appLoggerProvider).error('[Models] Refresh failed', error: e, stackTrace: stack);
    });
    return _chain = next;
  }

  Future<void> _readStatus() async {
    final models = _trackedModels;
    final queries = [
      for (final m in models)
        for (final f in m.files) ModelFileQuery(relativePath: f.relativePath, sizeBytes: f.sizeBytes),
    ];
    final statuses = await _channel.status(queries);
    if (!ref.mounted) return;
    final files = {for (final s in statuses) s.relativePath: s};
    final availability = {for (final m in models) m.id: aggregateAvailability(m, files)};
    final speechWasReady = _isSpeechReady();
    state = state.copyWith(loaded: true, files: files, availability: availability);
    _syncTimer(availability.values.any((a) => a.isBusy));
    _reconcileSelection();
    if (!speechWasReady && _isSpeechReady()) onSpeechModelReady?.call();
  }

  /// The chosen speech model is downloaded and verified.
  bool _isSpeechReady() {
    final spec = ModelCatalogue.byId(ref.read(modelSettingsProvider).selectedSpeechModelId);
    return spec != null && spec.kind == ModelKind.speech && state.of(spec.id).isReady;
  }

  void _syncTimer(bool active) {
    if (active) {
      _timer ??= Timer.periodic(pollInterval, (_) {
        // A slow answer must not pile up more reads behind it.
        if (_statusPending) return;
        _statusPending = true;
        unawaited(_refreshStatus().whenComplete(() => _statusPending = false));
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// With no model chosen, a single downloaded one that fits is chosen for the user, so a phone
  /// that already has the file keeps working. Several usable models and no choice: the user picks.
  /// The same rule holds for the speech models and for the language models.
  void _reconcileSelection() {
    final settings = ref.read(modelSettingsProvider);
    if (!settings.loaded || !state.loaded) return;
    final notifier = ref.read(modelSettingsProvider.notifier);
    final language = _soleUsableWithoutChoice(ModelCatalogue.languageModels, settings.selectedLanguageModelId);
    if (language != null) notifier.selectLanguageModel(language.id);
    final speech = _soleUsableWithoutChoice(ModelCatalogue.speechModels, settings.selectedSpeechModelId);
    if (speech != null) _setSpeechSelection(speech.id);
  }

  /// The one usable model of [models] when [selectedId] names none of them; `null` otherwise.
  ModelSpec? _soleUsableWithoutChoice(List<ModelSpec> models, String? selectedId) {
    final current = ModelCatalogue.byId(selectedId);
    if (current != null && models.contains(current)) return null;
    final usable = [for (final m in models) if (_isUsable(m)) m];
    return usable.length == 1 ? usable.single : null;
  }

  /// Changes the chosen speech model (`null` clears it) and tells the owner of the loaded
  /// model, which unloads it. Does nothing when the choice is already [id].
  void _setSpeechSelection(String? id) {
    final notifier = ref.read(modelSettingsProvider.notifier);
    if (ref.read(modelSettingsProvider).selectedSpeechModelId == id) return;
    if (id == null) {
      notifier.clearSpeechSelection();
    } else {
      notifier.selectSpeechModel(id);
    }
    onSpeechSelectionChanged?.call();
  }

  bool _isUsable(ModelSpec spec) =>
      state.of(spec.id).isReady && ModelCatalogue.fitsDevice(spec, state.device.totalRamMb);

  /// Starts the download of every file of [modelId] that is not ready.
  Future<void> download(String modelId) async {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null) return;
    final wifiOnly = ref.read(modelSettingsProvider).wifiOnly;
    for (final file in spec.files) {
      if (state.files[file.relativePath]?.state == ModelFileState.ready) continue;
      await _channel.download(
        relativePath: file.relativePath,
        url: file.url,
        sha256: file.sha256,
        sizeBytes: file.sizeBytes,
        title: spec.displayName,
        wifiOnly: wifiOnly,
      );
    }
    await _refreshStatus();
  }

  /// Stops the transfer of every file of [modelId] that is not ready.
  Future<void> cancel(String modelId) async {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null) return;
    for (final file in spec.files) {
      if (state.files[file.relativePath]?.state == ModelFileState.ready) continue;
      await _channel.cancel(file.relativePath);
    }
    await _refreshStatus();
  }

  /// Removes every file of [modelId]; a deleted model stops being the selected one. A deleted
  /// speech model is unloaded first, so no file is removed under a model that is in memory.
  Future<void> delete(String modelId) async {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null) return;
    final speechWasReady = _isSpeechReady();
    if (spec.kind == ModelKind.speech && ref.read(modelSettingsProvider).selectedSpeechModelId == modelId) {
      _setSpeechSelection(null);
    }
    for (final file in spec.files) {
      await _channel.delete(file.relativePath);
    }
    // Read the files first: clearing the choice re-runs the automatic choice, which must see the model gone.
    await _refreshStatus();
    if (!ref.mounted) return;
    if (ref.read(modelSettingsProvider).selectedLanguageModelId == modelId) {
      ref.read(modelSettingsProvider.notifier).clearSelection();
    }
    // A model left as the only usable one is chosen now rather than at the next reading.
    _reconcileSelection();
    if (!speechWasReady && _isSpeechReady()) onSpeechModelReady?.call();
  }

  /// Makes [modelId] the language model Synthesis uses. Only a downloaded language
  /// model that fits the phone can be chosen; returns whether it was.
  bool select(String modelId) {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null || spec.kind != ModelKind.language) return false;
    if (!_isUsable(spec)) return false;
    ref.read(modelSettingsProvider.notifier).selectLanguageModel(modelId);
    return true;
  }

  /// Makes [modelId] the speech model that transcribes recordings. Only a downloaded speech
  /// model can be chosen; returns whether it was. A model already in memory is unloaded, and
  /// recordings that waited for a model are transcribed.
  bool selectSpeech(String modelId) {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null || spec.kind != ModelKind.speech) return false;
    if (!_isUsable(spec)) return false;
    final wasReady = _isSpeechReady();
    _setSpeechSelection(modelId);
    if (!wasReady && _isSpeechReady()) onSpeechModelReady?.call();
    return true;
  }

  void setWifiOnly(bool value) => ref.read(modelSettingsProvider.notifier).setWifiOnly(value);
}

final modelLibraryControllerProvider =
    NotifierProvider<ModelLibraryController, ModelLibraryState>(ModelLibraryController.new);

/// The speech model that transcribes recordings: the chosen one, or `null` when none is chosen.
final selectedSpeechModelProvider = Provider<ModelSpec?>((ref) {
  final spec = ModelCatalogue.byId(ref.watch(modelSettingsProvider.select((s) => s.selectedSpeechModelId)));
  return spec != null && spec.kind == ModelKind.speech ? spec : null;
});

/// The chosen speech model is complete and verified.
final speechModelReadyProvider = Provider<bool>((ref) {
  final spec = ref.watch(selectedSpeechModelProvider);
  if (spec == null) return false;
  return ref.watch(modelLibraryControllerProvider.select((s) => s.of(spec.id).isReady));
});

/// Where the speech model stands, for the Capture banner: the chosen model's download state.
/// With none chosen, the transfer furthest along (never "ready": nothing is chosen to use), or
/// absent.
final speechModelAvailabilityProvider = Provider<ModelAvailability>((ref) {
  final spec = ref.watch(selectedSpeechModelProvider);
  final library = ref.watch(modelLibraryControllerProvider);
  if (spec != null) return library.of(spec.id);
  return furthestSpeechTransfer([for (final m in ModelCatalogue.speechModels) library.of(m.id)]);
});

/// The most active of [availabilities] (downloading, then checking, then paused, then failed),
/// or [ModelAvailability.absent] when none of them is under way. A ready model is not under way.
ModelAvailability furthestSpeechTransfer(Iterable<ModelAvailability> availabilities) {
  for (final kind in const [
    ModelAvailabilityKind.downloading,
    ModelAvailabilityKind.verifying,
    ModelAvailabilityKind.paused,
    ModelAvailabilityKind.failed,
  ]) {
    for (final a in availabilities) {
      if (a.kind == kind) return a;
    }
  }
  return ModelAvailability.absent;
}

/// How synthesis runs with the chosen language model: its profile when the model is selected,
/// downloaded and fits the phone; `null` otherwise (Synthesis then asks for a model).
final activeSynthesisProfileProvider = Provider<SynthesisModelProfile?>((ref) {
  final selectedId = ref.watch(modelSettingsProvider.select((s) => s.selectedLanguageModelId));
  final library = ref.watch(modelLibraryControllerProvider);
  final spec = ModelCatalogue.byId(selectedId);
  if (spec == null || spec.kind != ModelKind.language) return null;
  if (!library.of(spec.id).isReady || !ModelCatalogue.fitsDevice(spec, library.device.totalRamMb)) return null;
  return spec.profile;
});

/// True once, when the speech model is missing and the first-launch setup screen has not been
/// offered yet. Waits for both the stored settings and the first reading of the files.
final shouldOfferModelSetupProvider = Provider<bool>((ref) {
  final settings = ref.watch(modelSettingsProvider);
  final library = ref.watch(modelLibraryControllerProvider);
  final speechReady = ref.watch(speechModelReadyProvider);
  return settings.loaded && library.loaded && !speechReady && !settings.setupShown;
});
