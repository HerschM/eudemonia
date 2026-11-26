import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

/// How the Synthesis list shows notes: Read mode (only the note) or Edit mode (with its
/// actions), and whether every note is shown opened or as a title that opens when tapped.
class NotesViewPrefs {
  final bool readMode;
  final bool notesOpenByDefault;

  const NotesViewPrefs({this.readMode = true, this.notesOpenByDefault = false});

  NotesViewPrefs copyWith({bool? readMode, bool? notesOpenByDefault}) => NotesViewPrefs(
        readMode: readMode ?? this.readMode,
        notesOpenByDefault: notesOpenByDefault ?? this.notesOpenByDefault,
      );
}

/// Durable storage for [NotesViewPrefs].
abstract class NotesViewPrefsStore {
  Future<NotesViewPrefs?> load();
  Future<void> save(NotesViewPrefs prefs);
}

class SharedPreferencesNotesViewPrefsStore implements NotesViewPrefsStore {
  static const _readModeKey = 'notes.readMode';
  static const _openByDefaultKey = 'notes.openByDefault';

  @override
  Future<NotesViewPrefs?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final readMode = prefs.getBool(_readModeKey);
    final openByDefault = prefs.getBool(_openByDefaultKey);
    if (readMode == null && openByDefault == null) return null;
    return NotesViewPrefs(readMode: readMode ?? true, notesOpenByDefault: openByDefault ?? false);
  }

  @override
  Future<void> save(NotesViewPrefs prefs) async {
    final store = await SharedPreferences.getInstance();
    await store.setBool(_readModeKey, prefs.readMode);
    await store.setBool(_openByDefaultKey, prefs.notesOpenByDefault);
  }
}

final notesViewPrefsStoreProvider =
    Provider<NotesViewPrefsStore>((ref) => SharedPreferencesNotesViewPrefsStore());

class NotesViewPrefsNotifier extends Notifier<NotesViewPrefs> {
  bool _changedBeforeLoad = false;

  @override
  NotesViewPrefs build() {
    unawaited(_load());
    return const NotesViewPrefs();
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(notesViewPrefsStoreProvider).load();
      if (stored != null && !_changedBeforeLoad) state = stored;
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not load the notes view settings; using defaults: $e');
    }
  }

  void setReadMode(bool value) => _update(state.copyWith(readMode: value));

  void setNotesOpenByDefault(bool value) => _update(state.copyWith(notesOpenByDefault: value));

  void _update(NotesViewPrefs next) {
    _changedBeforeLoad = true;
    state = next;
    unawaited(_save(next));
  }

  Future<void> _save(NotesViewPrefs prefs) async {
    try {
      await ref.read(notesViewPrefsStoreProvider).save(prefs);
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not save the notes view settings: $e');
    }
  }
}

final notesViewPrefsProvider =
    NotifierProvider<NotesViewPrefsNotifier, NotesViewPrefs>(NotesViewPrefsNotifier.new);
