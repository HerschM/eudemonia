import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

/// When automatic synthesis runs (FR11.8).
class SynthesisSettings {
  /// Eligible thoughts in Capture that start a run (1–10).
  final int noteThreshold;

  /// Minutes without a new thought after which a run starts (5–60).
  final int inactivityMinutes;

  const SynthesisSettings({this.noteThreshold = 3, this.inactivityMinutes = 15});

  SynthesisSettings copyWith({int? noteThreshold, int? inactivityMinutes}) => SynthesisSettings(
        noteThreshold: (noteThreshold ?? this.noteThreshold).clamp(1, 10),
        inactivityMinutes: (inactivityMinutes ?? this.inactivityMinutes).clamp(5, 60),
      );
}

/// Durable storage for [SynthesisSettings].
abstract class SynthesisSettingsStore {
  Future<SynthesisSettings?> load();
  Future<void> save(SynthesisSettings settings);
}

class SharedPreferencesSynthesisSettingsStore implements SynthesisSettingsStore {
  static const _thresholdKey = 'synthesis.noteThreshold';
  static const _inactivityKey = 'synthesis.inactivityMinutes';

  @override
  Future<SynthesisSettings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getInt(_thresholdKey);
    final inactivity = prefs.getInt(_inactivityKey);
    if (threshold == null && inactivity == null) return null;
    return const SynthesisSettings().copyWith(noteThreshold: threshold, inactivityMinutes: inactivity);
  }

  @override
  Future<void> save(SynthesisSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_thresholdKey, settings.noteThreshold);
    await prefs.setInt(_inactivityKey, settings.inactivityMinutes);
  }
}

final synthesisSettingsStoreProvider =
    Provider<SynthesisSettingsStore>((ref) => SharedPreferencesSynthesisSettingsStore());

class SynthesisSettingsNotifier extends Notifier<SynthesisSettings> {
  bool _changedBeforeLoad = false;

  @override
  SynthesisSettings build() {
    unawaited(_load());
    return const SynthesisSettings();
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(synthesisSettingsStoreProvider).load();
      if (stored != null && !_changedBeforeLoad) state = stored;
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not load trigger settings; using defaults: $e');
    }
  }

  void setNoteThreshold(int value) => _update(state.copyWith(noteThreshold: value));

  void setInactivityMinutes(int value) => _update(state.copyWith(inactivityMinutes: value));

  void _update(SynthesisSettings next) {
    _changedBeforeLoad = true;
    state = next;
    unawaited(_save(next));
  }

  Future<void> _save(SynthesisSettings settings) async {
    try {
      await ref.read(synthesisSettingsStoreProvider).save(settings);
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not save trigger settings: $e');
    }
  }
}

final synthesisSettingsProvider =
    NotifierProvider<SynthesisSettingsNotifier, SynthesisSettings>(SynthesisSettingsNotifier.new);
