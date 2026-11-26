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

/// Whether language models still in testing are offered; the app shows them in debug builds only.
final includeCandidateModelsProvider = Provider<bool>((ref) => kDebugMode);

/// Reads the state of the model files from native code, starts and stops their downloads and
/// keeps the selection of the language model consistent with what is on the phone.
///
/// Progress is polled once a second, only while a file is queued, running, paused or being
/// verified; native `onChanged` events and app resumes (via [refresh]) also refresh it.
class ModelLibraryController extends Notifier<ModelLibraryState> {
  static const Duration pollInterval = Duration(seconds: 1);

  /// Called each time the speech model turns from missing to ready, so recordings that waited
  /// for it are transcribed. Set by whoever owns the queue; a plain callback because it must
  /// fire even when no screen is listening.
  void Function()? onSpeechModelReady;

  Timer? _timer;
  Future<void> _chain = Future.value();
  bool _statusPending = false;

  ModelFilesChannel get _channel => ref.read(modelFilesChannelProvider);

  List<ModelSpec> get _visibleLanguageModels =>
      ModelCatalogue.visibleLanguageModels(includeCandidates: ref.read(includeCandidateModelsProvider));

  List<ModelSpec> get _trackedModels => [ModelCatalogue.speech, ..._visibleLanguageModels];

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
    final speechWasReady = state.of(ModelCatalogue.speech.id).isReady;
    state = state.copyWith(loaded: true, files: files, availability: availability);
    if (!speechWasReady && availability[ModelCatalogue.speech.id]!.isReady) onSpeechModelReady?.call();
    _syncTimer(availability.values.any((a) => a.isBusy));
    _reconcileSelection();
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

  /// With no language model chosen, a single downloaded one that fits is chosen for the user,
  /// so a phone that already has the file keeps working.
  void _reconcileSelection() {
    final settings = ref.read(modelSettingsProvider);
    if (!settings.loaded || !state.loaded) return;
    final current = ModelCatalogue.byId(settings.selectedLanguageModelId);
    if (current != null && _visibleLanguageModels.contains(current)) return;
    final usable = [for (final m in _visibleLanguageModels) if (_isUsable(m)) m];
    if (usable.length == 1) {
      ref.read(modelSettingsProvider.notifier).selectLanguageModel(usable.single.id);
    }
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

  /// Removes every file of [modelId]; a deleted language model stops being the selected one.
  Future<void> delete(String modelId) async {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null) return;
    for (final file in spec.files) {
      await _channel.delete(file.relativePath);
    }
    // Read the files first: clearing the choice re-runs the automatic choice, which must see the model gone.
    await _refreshStatus();
    if (ref.mounted && ref.read(modelSettingsProvider).selectedLanguageModelId == modelId) {
      ref.read(modelSettingsProvider.notifier).clearSelection();
    }
  }

  /// Makes [modelId] the language model Synthesis uses. Only a downloaded, visible language
  /// model that fits the phone can be chosen; returns whether it was.
  bool select(String modelId) {
    final spec = ModelCatalogue.byId(modelId);
    if (spec == null || spec.kind != ModelKind.language) return false;
    if (!_visibleLanguageModels.contains(spec) || !_isUsable(spec)) return false;
    ref.read(modelSettingsProvider.notifier).selectLanguageModel(modelId);
    return true;
  }

  void setWifiOnly(bool value) => ref.read(modelSettingsProvider.notifier).setWifiOnly(value);
}

final modelLibraryControllerProvider =
    NotifierProvider<ModelLibraryController, ModelLibraryState>(ModelLibraryController.new);

/// The speech model is complete and verified.
final speechModelReadyProvider = Provider<bool>(
  (ref) => ref.watch(modelLibraryControllerProvider.select((s) => s.of(ModelCatalogue.speech.id).isReady)),
);

/// The speech model's download state, for the Capture banner.
final speechModelAvailabilityProvider = Provider<ModelAvailability>(
  (ref) => ref.watch(modelLibraryControllerProvider.select((s) => s.of(ModelCatalogue.speech.id))),
);

/// How synthesis runs with the chosen language model: its profile when the model is selected,
/// downloaded, visible and fits the phone; `null` otherwise (Synthesis then asks for a model).
final activeSynthesisProfileProvider = Provider<SynthesisModelProfile?>((ref) {
  final selectedId = ref.watch(modelSettingsProvider.select((s) => s.selectedLanguageModelId));
  final library = ref.watch(modelLibraryControllerProvider);
  final includeCandidates = ref.watch(includeCandidateModelsProvider);
  final spec = ModelCatalogue.byId(selectedId);
  if (spec == null || spec.kind != ModelKind.language) return null;
  if (!ModelCatalogue.visibleLanguageModels(includeCandidates: includeCandidates).contains(spec)) return null;
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
