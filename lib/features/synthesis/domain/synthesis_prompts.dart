/// Prompt builders and reply validation for the synthesis turns (organise, write).
/// Pure Dart. Wording was tuned in tool/synthesis_prompt_lab/syn.py; change both together.
library;

import 'folder_definition.dart';
import 'note_style.dart';
import 'synthesis_model_profile.dart';

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

/// Wraps [system] and [user] in the chat template of [format], ending at the assistant turn.
String _wrap(ChatFormat format, String system, String user) => switch (format) {
      ChatFormat.chatml => _chatml(system, user),
      ChatFormat.chatmlNoThink => '${_chatml(system, user)}<think>\n\n</think>\n\n',
      // No <|begin_of_text|>: the tokenizer adds it (the engine tokenizes with add_special).
      ChatFormat.llama3 => '<|start_header_id|>system<|end_header_id|>\n\n$system<|eot_id|>'
          '<|start_header_id|>user<|end_header_id|>\n\n$user<|eot_id|>'
          '<|start_header_id|>assistant<|end_header_id|>\n\n',
    };

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
  ChatFormat format = ChatFormat.chatml,
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
  return _wrap(format, system, user.toString());
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

String buildWritePrompt(List<String> thoughts, {ChatFormat format = ChatFormat.chatml}) =>
    _wrap(format, _writeSystem, 'Thoughts:\n${_numbered(thoughts)}\n\nWrite the note.');

/// Writes the thoughts as a note in [style] (see [noteStyles]): its system text, then the
/// numbered thoughts and the style's request.
String buildStyleWritePrompt(List<String> thoughts, NoteStyleSpec style, {ChatFormat format = ChatFormat.chatml}) =>
    _wrap(format, style.systemPrompt, 'Thoughts:\n${_numbered(thoughts)}\n\n${style.request}');

/// Writes the thoughts as a titled note of bullets under topic headings ([NoteStyle.structured]),
/// the organised style. Needs a model larger than Qwen2.5-1.5B to keep the facts (TASK-070). The
/// worked example and the rule that every thought must appear were added after Qwen3-4B wrote
/// telegraphic notes that dropped details (lab comparison 2026-11-22); without the example the
/// format is unstable.
String buildStructuredWritePrompt(List<String> thoughts, {ChatFormat format = ChatFormat.chatml}) =>
    buildStyleWritePrompt(thoughts, noteStyleById(defaultNoteStyleId), format: format);

/// Output token budget for a structured write turn. Measured with Qwen3-4B: a complete note takes
/// 1.2-2.1 tokens per spoken word (headings and full sentences).
int structuredOutputBudget(int inputWords) => (inputWords * 1.3).round() + 96;

/// Output token budget for an organise turn: one short "n: Folder" line per thought.
int organiseOutputBudget(int thoughtCount) => 8 * thoughtCount + 8;

/// GBNF grammar for the reply to an organise turn of [thoughtCount] thoughts: exactly the lines
/// `1: <folder>` … `n: <folder>` separated by `\n`, each folder one of [folders], nothing else.
/// The form is fixed; which folder is the model's choice. [parseOrganiseReply] stays the check.
String buildOrganiseGrammar(int thoughtCount, List<FolderDefinition> folders) {
  if (thoughtCount <= 0) throw ArgumentError.value(thoughtCount, 'thoughtCount', 'must be positive');
  if (folders.isEmpty) throw ArgumentError.value(folders, 'folders', 'must not be empty');
  final lines = [for (var i = 1; i <= thoughtCount; i++) '"${i == 1 ? '' : r'\n'}$i: " folder'];
  return 'root ::= ${lines.join(' ')}\n'
      'folder ::= ${folders.map((f) => '"${_gbnfEscape(f.name)}"').join(' | ')}\n';
}

/// Escapes [text] for the inside of a GBNF string literal.
String _gbnfEscape(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    switch (rune) {
      case 0x5C:
        out.write(r'\\');
      case 0x22:
        out.write(r'\"');
      case 0x0A:
        out.write(r'\n');
      case 0x0D:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      case < 0x20:
        out.write('\\x${rune.toRadixString(16).padLeft(2, '0')}');
      default:
        out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Output token budget for a write turn, from the words in its input.
int writeOutputBudget(int inputWords) => (inputWords * 1.6).round() + 96;

final RegExp _organiseEntry = RegExp(r'^(\d+)\s*[.:)]\s*(.+)$');

/// Returns one folder name per thought, or null unless the reply is exactly `thoughtCount`
/// entries `"{i}: {Folder}"` (1-based, in order) with every folder a known name.
///
/// Only the form is read leniently, never the choice: the number may be followed by `:`, `.`
/// or `)`, blank lines are skipped, and one heading line before the entries (text ending in a
/// colon, without digits, such as an echoed `Thoughts:`) is ignored. Any other extra text, a
/// missing or extra entry, wrong numbering or an unknown folder makes the reply invalid.
List<String>? parseOrganiseReply(String reply, int thoughtCount, List<FolderDefinition> folders) {
  if (thoughtCount <= 0) return null;
  final lines = [
    for (final line in reply.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  if (lines.isEmpty) return null;
  final first = lines.first;
  if (first.endsWith(':') && !first.contains(RegExp(r'\d'))) lines.removeAt(0);
  if (lines.length != thoughtCount) return null;
  final names = {for (final f in folders) f.name};
  final labels = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final entry = _organiseEntry.firstMatch(lines[i]);
    if (entry == null || entry[1] != '${i + 1}') return null;
    final folder = entry[2]!.trim();
    if (!names.contains(folder)) return null;
    labels.add(folder);
  }
  return labels;
}

const Set<String> _commonWords = {
  'that', 'this', 'with', 'have', 'will', 'from', 'they', 'them', 'then', 'than', 'what', 'when', 'where', 'which',
  'would', 'could', 'should', 'about', 'there', 'their', 'been', 'were', 'into', 'just', 'also', 'very', 'really',
  'think', 'because', 'going', 'still', 'some', 'more', 'most', 'much', 'many', 'only', 'even', 'like', 'yeah',
  'okay', 'well', 'want', 'need',
};

/// Distinctive words of [text], cut to five letters so that word endings do not matter.
Set<String> _contentWords(String text) => {
      for (final m in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase()))
        if ((m[0]!.length >= 4 || int.tryParse(m[0]!) != null) && !_commonWords.contains(m[0]))
          m[0]!.length > 5 ? m[0]!.substring(0, 5) : m[0]!,
    };

/// Share of the distinctive words of [thought] that appear in [note] (1.0 when it has none).
double thoughtCoverage(String thought, String note) {
  final words = _contentWords(thought);
  if (words.isEmpty) return 1;
  return words.intersection(_contentWords(note)).length / words.length;
}

/// A note that shares fewer distinctive words than this with a thought has left the thought out.
/// Measured with Qwen3-4B on the user's sessions: a dropped thought scores 0.0, a telegraphic
/// summary 0.28-0.42, a faithful note 0.67-1.0.
const double minThoughtCoverage = 0.3;

/// 1-based positions of the thoughts that [note] leaves out. Thoughts with fewer than four
/// distinctive words are not judged.
List<int> thoughtsMissingFrom(String note, List<String> thoughts) => [
      for (var i = 0; i < thoughts.length; i++)
        if (_contentWords(thoughts[i]).length >= 4 && thoughtCoverage(thoughts[i], note) < minThoughtCoverage) i + 1,
    ];
