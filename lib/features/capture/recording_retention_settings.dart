import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

/// How long the original voice recording of a thought is kept. The text and the notes always
/// stay; only the audio is removed. [always] is the default: nothing is removed unless the user
/// chooses a period.
enum RecordingRetention {
  always(null, 'Always', 'always'),
  days90(90, '90 days', '90'),
  days30(30, '30 days', '30'),
  days7(7, '7 days', '7');

  /// Age in days after which a recording is removed; null keeps every recording.
  final int? days;
  final String label;

  /// Ends the key of this choice's option in the chooser (`keep_recordings_option_<keySuffix>`).
  final String keySuffix;

  const RecordingRetention(this.days, this.label, this.keySuffix);
}

/// Durable storage for the [RecordingRetention] choice.
abstract class RecordingRetentionStore {
  Future<RecordingRetention?> load();
  Future<void> save(RecordingRetention value);
}

class SharedPreferencesRecordingRetentionStore implements RecordingRetentionStore {
  static const _key = 'recordings.keepPeriod';

  @override
  Future<RecordingRetention?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    for (final value in RecordingRetention.values) {
      if (value.name == stored) return value;
    }
    return null;
  }

  @override
  Future<void> save(RecordingRetention value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}

final recordingRetentionStoreProvider =
    Provider<RecordingRetentionStore>((ref) => SharedPreferencesRecordingRetentionStore());

class RecordingRetentionNotifier extends Notifier<RecordingRetention> {
  bool _changedBeforeLoad = false;

  /// Completes once the stored choice has been read. Until then the state is [RecordingRetention.always],
  /// so a sweep that must follow the stored choice awaits this first.
  late Future<void> ready;

  @override
  RecordingRetention build() {
    ready = _load();
    return RecordingRetention.always;
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(recordingRetentionStoreProvider).load();
      if (stored != null && !_changedBeforeLoad) state = stored;
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Recordings] Could not load the keep-recordings choice; using Always: $e');
    }
  }

  void set(RecordingRetention value) {
    _changedBeforeLoad = true;
    state = value;
    unawaited(_save(value));
  }

  Future<void> _save(RecordingRetention value) async {
    try {
      await ref.read(recordingRetentionStoreProvider).save(value);
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Recordings] Could not save the keep-recordings choice: $e');
    }
  }
}

final recordingRetentionProvider =
    NotifierProvider<RecordingRetentionNotifier, RecordingRetention>(RecordingRetentionNotifier.new);
