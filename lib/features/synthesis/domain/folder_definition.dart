/// A folder a thought can be filed under, with the description the language model sees.
class FolderDefinition {
  final String name;
  final String description;

  const FolderDefinition({required this.name, required this.description});
}

/// The folders offered to the model when organising thoughts. Order is the order shown in the prompt.
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
