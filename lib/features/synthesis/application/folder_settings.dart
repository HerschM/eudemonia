import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';

/// Outcome of a folder change, for the UI to show. Anything but [done] changed nothing.
enum FolderChange {
  done,
  nameEmpty,
  nameTooLong,
  nameInvalid,
  nameTaken,
  tooManyFolders,
  descriptionTooLong,
  notFound,

  /// [uncategorizedFolderName] cannot be renamed, have its description edited or be removed.
  protectedFolder,

  /// The id is not a style that can be chosen (see [noteStyles]).
  styleUnknown,
}

const int maxFolderCount = 12;
const int maxFolderNameLength = 24;
const int maxFolderDescriptionLength = 200;

/// Durable storage for the user's folder list.
abstract class FolderStore {
  Future<List<FolderDefinition>?> load();
  Future<void> save(List<FolderDefinition> folders);
}

class SharedPreferencesFolderStore implements FolderStore {
  static const _key = 'synthesis.folders';

  @override
  Future<List<FolderDefinition>?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    return [
      for (final entry in jsonDecode(raw) as List)
        if (entry is Map && entry['name'] is String)
          FolderDefinition(
            name: entry['name'] as String,
            description: entry['description'] is String ? entry['description'] as String : '',
            // Missing in folders saved before default styles; an unknown id reads as organised.
            defaultStyleId: entry['defaultStyleId'] is String && isKnownNoteStyle(entry['defaultStyleId'] as String)
                ? entry['defaultStyleId'] as String
                : defaultNoteStyleId,
          ),
    ];
  }

  @override
  Future<void> save(List<FolderDefinition> folders) async {
    final raw = jsonEncode([
      for (final f in folders) {'name': f.name, 'description': f.description, 'defaultStyleId': f.defaultStyleId},
    ]);
    await (await SharedPreferences.getInstance()).setString(_key, raw);
  }
}

final folderStoreProvider = Provider<FolderStore>((ref) => SharedPreferencesFolderStore());

final FolderDefinition _uncategorized = defaultFolders.firstWhere((f) => f.name == uncategorizedFolderName);

/// The folders Synthesis files thoughts under, edited by the user and persisted. Starts with
/// [defaultFolders] and loads the stored list asynchronously; every change waits for [loaded].
/// [uncategorizedFolderName] always exists and is always last; only its default style can change.
class FolderSettingsNotifier extends Notifier<List<FolderDefinition>> {
  Future<void> _loaded = Future.value();

  @override
  List<FolderDefinition> build() {
    _loaded = _load();
    return defaultFolders;
  }

  /// Completes once the stored folders (if any) are in [state].
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    try {
      final stored = await ref.read(folderStoreProvider).load();
      if (stored != null) state = _normalized(stored);
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not load folders; using defaults: $e');
    }
  }

  /// A stored list as a valid one: invalid or repeated names dropped, at most [maxFolderCount]
  /// folders, Uncategorized last with its fixed description and its stored style, every unknown
  /// style read as organised.
  static List<FolderDefinition> _normalized(List<FolderDefinition> stored) {
    final out = <FolderDefinition>[];
    var uncategorized = _uncategorized;
    for (final f in stored) {
      final name = _cleanName(f.name);
      final style = _knownStyle(f.defaultStyleId);
      if (name == uncategorizedFolderName) uncategorized = _uncategorized.copyWith(defaultStyleId: style);
      if (out.length >= maxFolderCount - 1 || _nameProblem(name) != null) continue;
      if (_isTaken([...out, _uncategorized], name)) continue;
      out.add(FolderDefinition(name: name, description: _describe(name, f.description), defaultStyleId: style));
    }
    return [...out, uncategorized];
  }

  static String _knownStyle(String id) => isKnownNoteStyle(id) ? id : defaultNoteStyleId;

  Future<FolderChange> add(String name, String description, {String defaultStyleId = defaultNoteStyleId}) async {
    await _loaded;
    final clean = _cleanName(name);
    final problem = _nameProblem(clean) ?? _descriptionProblem(description);
    if (problem != null) return problem;
    if (!isKnownNoteStyle(defaultStyleId)) return FolderChange.styleUnknown;
    if (_isTaken(state, clean)) return FolderChange.nameTaken;
    if (state.length >= maxFolderCount) return FolderChange.tooManyFolders;
    final added =
        FolderDefinition(name: clean, description: _describe(clean, description), defaultStyleId: defaultStyleId);
    await _save([...state.take(state.length - 1), added, state.last]);
    return FolderChange.done;
  }

  Future<FolderChange> updateDescription(String name, String description) async {
    await _loaded;
    final problem = _editProblem(name) ?? _descriptionProblem(description);
    if (problem != null) return problem;
    await _save([
      for (final f in state)
        if (f.name == name) f.copyWith(description: _describe(name, description)) else f,
    ]);
    return FolderChange.done;
  }

  /// Sets the style new notes in folder [name] are written in, and notes moved into it are
  /// rewritten in. Allowed for every folder, [uncategorizedFolderName] included. Notes already in
  /// the folder keep their style.
  Future<FolderChange> updateDefaultStyle(String name, String styleId) async {
    await _loaded;
    if (!isKnownNoteStyle(styleId)) return FolderChange.styleUnknown;
    if (!state.any((f) => f.name == name)) return FolderChange.notFound;
    await _save([
      for (final f in state)
        if (f.name == name) f.copyWith(defaultStyleId: styleId) else f,
    ]);
    return FolderChange.done;
  }

  /// Renames a folder and files every session under it under the new name.
  Future<FolderChange> rename(String oldName, String newName) async {
    await _loaded;
    final clean = _cleanName(newName);
    final problem = _editProblem(oldName) ?? _nameProblem(clean);
    if (problem != null) return problem;
    if (_isTaken(state.where((f) => f.name != oldName), clean)) return FolderChange.nameTaken;
    if (clean == oldName) return FolderChange.done;
    final sessions = ref.read(synthesisRepositoryProvider.notifier);
    await sessions.hydrated;
    await _save([
      for (final f in state)
        if (f.name == oldName) f.copyWith(name: clean) else f,
    ]);
    sessions.renameFolder(oldName, clean);
    return FolderChange.done;
  }

  /// Removes a folder; its sessions move to [uncategorizedFolderName].
  Future<FolderChange> remove(String name) async {
    await _loaded;
    final problem = _editProblem(name);
    if (problem != null) return problem;
    final sessions = ref.read(synthesisRepositoryProvider.notifier);
    await sessions.hydrated;
    await _save([for (final f in state) if (f.name != name) f]);
    sessions.moveFolderSessions(name, uncategorizedFolderName);
    return FolderChange.done;
  }

  /// Why folder [name] cannot be changed, or null when it can.
  FolderChange? _editProblem(String name) {
    if (name == uncategorizedFolderName) return FolderChange.protectedFolder;
    return state.any((f) => f.name == name) ? null : FolderChange.notFound;
  }

  Future<void> _save(List<FolderDefinition> next) async {
    state = List.unmodifiable(next);
    try {
      await ref.read(folderStoreProvider).save(next);
    } catch (e) {
      ref.read(appLoggerProvider).warning('[Synthesis] Could not save folders: $e');
    }
  }

  /// Trimmed, with runs of whitespace (including line breaks) as one space.
  static String _cleanName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

  static FolderChange? _nameProblem(String name) {
    if (name.isEmpty) return FolderChange.nameEmpty;
    if (name.length > maxFolderNameLength) return FolderChange.nameTooLong;
    // A name is one line of the prompt and one literal of the reply grammar.
    if (name.runes.any((r) => r < 0x20 || r == 0x7F)) return FolderChange.nameInvalid;
    return null;
  }

  static FolderChange? _descriptionProblem(String description) =>
      _cleanDescription(description).length > maxFolderDescriptionLength ? FolderChange.descriptionTooLong : null;

  static String _cleanDescription(String description) => description.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _describe(String name, String description) {
    final clean = _cleanDescription(description);
    return clean.isEmpty ? 'Thoughts about $name.' : clean;
  }

  static bool _isTaken(Iterable<FolderDefinition> folders, String name) =>
      folders.any((f) => f.name.toLowerCase() == name.toLowerCase());
}

final foldersProvider =
    NotifierProvider<FolderSettingsNotifier, List<FolderDefinition>>(FolderSettingsNotifier.new);
