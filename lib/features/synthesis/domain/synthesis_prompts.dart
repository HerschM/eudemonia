/// Prompt builders and reply validation for the synthesis turns (organise, write, update).
/// Pure Dart. Wording was tuned in tool/synthesis_prompt_lab/syn.py; change both together.
library;

import 'folder_definition.dart';

/// A note already in progress, shown to the model so new thoughts can continue it.
class OpenSessionContext {
  final String folder;
  final String note;

  const OpenSessionContext({required this.folder, required this.note});
}

/// Wraps [system] and [user] as a Qwen ChatML conversation ending at the assistant turn.
String _chatml(String system, String user) => '<|im_start|>system\n$system<|im_end|>\n'
    '<|im_start|>user\n$user<|im_end|>\n'
    '<|im_start|>assistant\n';

String _numbered(List<String> thoughts) => [
      for (var i = 0; i < thoughts.length; i++) '${i + 1}. ${thoughts[i]}',
    ].join('\n');

const String _organiseExample = 'Example:\nThoughts:\n1. Ask Dev to move the release to Monday.\n'
    '2. Buy stamps and post the letter.\n'
    '3. Also the login button should be bigger.\n4. Slept badly, feeling low today.\n'
    'Answer:\n1: Work\n2: Personal\n3: Work\n4: Journal';

String buildOrganisePrompt(
  List<String> thoughts, {
  List<FolderDefinition> folders = defaultFolders,
  List<OpenSessionContext> openSessions = const [],
}) {
  final rules = StringBuffer("Folders (each is a subject area of the speaker's life):\n");
  for (final f in folders) {
    rules.write('- ${f.name}: ${f.description}\n');
  }
  rules.write('\nChoose by what the thought is about, not by whether it is a task, a reminder or an idea.\n');

  final system = 'You sort the spoken thoughts of one person into folders. The thoughts were transcribed by '
      'speech recognition, so some words may be wrong.\n\n'
      '$rules'
      '\nA short or unclear thought usually continues the subject of the thoughts next to it.\n\n'
      '$_organiseExample';

  final user = StringBuffer();
  if (openSessions.isNotEmpty) {
    user.write('Notes already in progress:\n'
        '${openSessions.map((s) => '[${s.folder}] ${s.note}').join('\n')}\n\n');
  }
  user.write('Thoughts:\n${_numbered(thoughts)}\nAnswer:');
  return _chatml(system, user.toString());
}

const String _writeSystem =
    'You turn spoken thoughts into one clear written note. The thoughts were dictated by one person, in order, and '
    'transcribed by speech recognition.\n\n'
    'Rules:\n'
    '- Keep every fact: names, numbers, dates, times, places, items in lists, reasons.\n'
    '- When the speaker corrects themselves, keep only the corrected version.\n'
    '- Remove filler words, false starts and repetition.\n'
    '- Add nothing that was not said. Do not guess missing details, do not give advice, do not add a title or a closing remark.\n'
    '- Write in the first person, as the speaker, in plain sentences. Use a short list only when the speaker listed items.\n'
    '- All thoughts matter equally; do not give the last one more weight.\n'
    '- Output only the note. Begin with its first sentence, with no introduction.';

final String _updateSystem = _writeSystem
    .replaceFirst('You turn spoken thoughts into one clear written note.',
        'You update a written note with new spoken thoughts from the same person.')
    .replaceFirst(
        '- All thoughts matter equally; do not give the last one more weight.',
        '- Keep everything in the current note exactly as it is unless a new thought changes or corrects it.\n'
            '- Put each new thought where it belongs in the note; do not let it take over the note.');

String buildWritePrompt(List<String> thoughts) =>
    _chatml(_writeSystem, 'Thoughts:\n${_numbered(thoughts)}\n\nWrite the note.');

/// Experimental (TASK-070): condenses the thoughts into a titled, bulleted note. Measured to need a
/// model larger than Qwen2.5-1.5B to keep the facts; not used by production code yet.
String buildStructuredWritePrompt(List<String> thoughts) =>
    _chatml(_structuredSystem, 'Thoughts:\n${_numbered(thoughts)}\n\nWrite the note.');

const String _structuredSystem =
    'You turn spoken thoughts into one organised written note. The thoughts were dictated by one person, in order, '
    'and transcribed by speech recognition.\n\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then the content as short bullet points, grouped under a plain one-word or two-word heading when there is more than one topic.\n'
    '- Each bullet states one point in as few words as possible, in the first person.\n\n'
    'Rules:\n'
    '- Keep every fact: names, numbers, dates, times, places, items in lists, reasons, decisions, plans.\n'
    '- Leave out filler, repetition, false starts and remarks about the recording itself.\n'
    '- When the speaker corrects themselves, keep only the corrected version.\n'
    '- Add nothing that was not said. No advice, no summary sentence at the end.\n'
    '- Output only the note.';

/// Output token budget for a structured write turn.
int structuredOutputBudget(int inputWords) => inputWords + 96;

String buildUpdatePrompt(String currentNote, List<String> newThoughts) => _chatml(
    _updateSystem,
    'Current note:\n$currentNote\n\nNew thoughts:\n${_numbered(newThoughts)}\n\nWrite the updated note.');

/// Output token budget for an organise turn: one short "n: Folder" line per thought.
int organiseOutputBudget(int thoughtCount) => 8 * thoughtCount + 8;

/// Output token budget for a write or update turn, from the words in its input.
int writeOutputBudget(int inputWords) => (inputWords * 1.6).round() + 96;

/// Returns one folder name per thought, or null unless the reply is exactly
/// `thoughtCount` lines of `"{i}: {Folder}"` (1-based) with every folder a known name.
List<String>? parseOrganiseReply(String reply, int thoughtCount, List<FolderDefinition> folders) {
  final trimmed = reply.trim();
  if (trimmed.isEmpty || thoughtCount <= 0) return null;
  final lines = trimmed.split('\n');
  if (lines.length != thoughtCount) return null;
  final names = {for (final f in folders) f.name};
  final labels = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final colon = lines[i].indexOf(':');
    if (colon < 0) return null;
    if (lines[i].substring(0, colon).trim() != '${i + 1}') return null;
    final folder = lines[i].substring(colon + 1).trim();
    if (!names.contains(folder)) return null;
    labels.add(folder);
  }
  return labels;
}
