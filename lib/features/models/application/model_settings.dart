import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

/// The user's lasting choices about on-device models. Download progress is not here: it is
/// transient and lives in the model library controller.
class ModelSettings {
  /// Id of the language model Synthesis uses, or `null` when none is chosen.
  final String? selectedLanguageModelId;

  /// Download only on Wi-Fi (the default); `false` also allows mobile data.
  final bool wifiOnly;

  /// The setup screen has been offered once on first launch.
  final bool setupShown;

  /// The stored values have been read; until then the others are defaults.
  final bool loaded;

  const ModelSettings({
    this.selectedLanguageModelId,
    this.wifiOnly = true,
    this.setupShown = false,
    this.loaded = false,
  });

  ModelSettings copyWith({
    String? selectedLanguageModelId,
    bool clearSelection = false,
    bool? wifiOnly,
    bool? setupShown,
    bool? loaded,
  }) =>
      ModelSettings(
        selectedLanguageModelId: clearSelection ? null : (selectedLanguageModelId ?? this.selectedLanguageModelId),
        wifiOnly: wifiOnly ?? this.wifiOnly,
        setupShown: setupShown ?? this.setupShown,
        loaded: loaded ?? this.loaded,
      );
}

/// Durable storage for [ModelSettings].
abstract class ModelSettingsStore {
  /// The stored settings, or the defaults when nothing was stored yet.
  Future<ModelSettings> load();
  Future<void> save(ModelSettings settings);
}

class SharedPreferencesModelSettingsStore implements ModelSettingsStore {
  static const _selectedKey = 'models.selectedLanguageModelId';
  static const _wifiOnlyKey = 'models.wifiOnly';
  static const _setupShownKey = 'models.setupShown';

  @override
  Future<ModelSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ModelSettings(
      selectedLanguageModelId: prefs.getString(_selectedKey),
      wifiOnly: prefs.getBool(_wifiOnlyKey) ?? true,
      setupShown: prefs.getBool(_setupShownKey) ?? false,
      loaded: true,
    );
  }

  @override
  Future<void> save(ModelSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final selected = settings.selectedLanguageModelId;
    if (selected == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, selected);
    }
    await prefs.setBool(_wifiOnlyKey, settings.wifiOnly);
    await prefs.setBool(_setupShownKey, settings.setupShown);
  }
}

final modelSettingsStoreProvider = Provider<ModelSettingsStore>((ref) => SharedPreferencesModelSettingsStore());

class ModelSettingsNotifier extends Notifier<ModelSettings> {
  bool _changedBeforeLoad = false;
  Future<void> _loading = Future.value();

  /// Completes once the stored values have been read (or have failed to be, leaving defaults).
  Future<void> get loadedFuture => _loading;

  @override
  ModelSettings build() {
    _loading = _load();
    return const ModelSettings();
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(modelSettingsStoreProvider).load();
      if (!ref.mounted) return;
      state = _changedBeforeLoad ? state.copyWith(loaded: true) : stored.copyWith(loaded: true);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(appLoggerProvider).warning('[Models] Could not load model settings; using defaults: $e');
      // Unreadable storage must not nag the user with the first-launch screen on every start.
      state = state.copyWith(loaded: true, setupShown: true);
    }
  }

  void selectLanguageModel(String id) => _update(state.copyWith(selectedLanguageModelId: id));

  void clearSelection() => _update(state.copyWith(clearSelection: true));

  void setWifiOnly(bool value) => _update(state.copyWith(wifiOnly: value));

  void markSetupShown() => _update(state.copyWith(setupShown: true));

  void _update(ModelSettings next) {
    _changedBeforeLoad = true;
    state = next;
    unawaited(_save(next));
  }

  Future<void> _save(ModelSettings settings) async {
    try {
      await ref.read(modelSettingsStoreProvider).save(settings);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(appLoggerProvider).warning('[Models] Could not save model settings: $e');
    }
  }
}

final modelSettingsProvider = NotifierProvider<ModelSettingsNotifier, ModelSettings>(ModelSettingsNotifier.new);
