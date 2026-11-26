import 'note_style.dart';

/// A folder a thought can be filed under, with the description the language model sees.
class FolderDefinition {
  final String name;
  final String description;

  /// The style a new note in this folder is written in, and a note moved here is rewritten in
  /// (see [noteStyles]).
  final String defaultStyleId;

  const FolderDefinition({required this.name, required this.description, this.defaultStyleId = defaultNoteStyleId});

  FolderDefinition copyWith({String? name, String? description, String? defaultStyleId}) => FolderDefinition(
        name: name ?? this.name,
        description: description ?? this.description,
        defaultStyleId: defaultStyleId ?? this.defaultStyleId,
      );
}

/// The default style of folder [name] in [folders]: organised when the folder is not listed or
/// its default is not a style that can be chosen.
String folderDefaultStyle(List<FolderDefinition> folders, String name) {
  final id = folders.where((f) => f.name == name).firstOrNull?.defaultStyleId ?? defaultNoteStyleId;
  return isKnownNoteStyle(id) ? id : defaultNoteStyleId;
}

/// The folder that always exists, always last, for text that fits no other folder.
const String uncategorizedFolderName = 'Uncategorized';

/// The folders offered to the model when organising thoughts until the user changes them.
/// Order is the order shown in the prompt.
const List<FolderDefinition> defaultFolders = [
  FolderDefinition(
    name: 'Work',
    description: 'the job and the app or software being built; colleagues, clients, meetings, budgets, '
        'invoices, design, features, product plans, work travel.',
  ),
  FolderDefinition(
    name: 'Personal',
    description: "running the speaker's own life; shopping, errands, home, appointments, family plans, "
        'places and things to remember.',
  ),
  FolderDefinition(
    name: 'Journal',
    description: 'how the speaker feels; mood, sleep, health, exercise, reflections on the day.',
  ),
  FolderDefinition(
    name: 'Uncategorized',
    description: 'only when the text fits none of these or makes no sense.',
  ),
];
