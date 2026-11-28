/// The ways a session's note can be written (the style re-writer, FR5.3). Pure Dart. Each style is
/// data: its label and description for the picker, the system prompt of its write turn and the
/// rules a reply must meet. A reply that breaks its style's rules is invalid: nothing is written.
///
/// Every prompt ends with one worked example on the same invented thoughts, because the model
/// follows an example far better than instructions. The organised prompt is the one tuned on the
/// user's sessions (lab comparison 2026-11-22); change it together with
/// tool/synthesis_prompt_lab/syn.py.
library;

/// The style of a new session in a folder without another default, and of a stored session whose
/// style is unknown.
const String defaultNoteStyleId = 'organised';

/// The style id of a note the user edited by hand. Not one of [noteStyles]: it cannot be chosen,
/// has no prompt and is never rewritten automatically; new thoughts are appended under
/// [addedLaterHeading] (see [appendAddedLater]).
const String manualStyleId = 'manual';

const String manualStyleLabel = 'Edited by hand';

/// The heading above thoughts added to a note edited by hand.
const String addedLaterHeading = '**Added later**';

/// The label shown for the style [id], including [manualStyleId].
String noteStyleLabel(String id) => id == manualStyleId ? manualStyleLabel : noteStyleById(id).label;

/// [note], edited by hand, with [fragment] (newly written thoughts) appended: under a new
/// [addedLaterHeading], or under the existing one when it is already the note's last heading. The
/// fragment's title is dropped, unless it is all there is.
String appendAddedLater(String note, String fragment) {
  final body = _withoutTitle(fragment);
  final added = body.isEmpty ? fragment.trim() : body;
  final kept = note.trimRight();
  if (kept.isEmpty) return '$addedLaterHeading\n\n$added';
  final lastHeading = kept.split(RegExp(r'\r\n|\r|\n')).map((l) => l.trim()).lastWhere(_isHeading, orElse: () => '');
  return lastHeading == addedLaterHeading ? '$kept\n\n$added' : '$kept\n\n$addedLaterHeading\n\n$added';
}

/// The whole body of an actionable note when the thoughts contain nothing to do.
const String noNextStepsSentence = 'No next steps were mentioned.';

/// Why a session cannot be written as a short summary: it is over one write turn and a summary
/// is never written in pieces.
const String tooLongForShortSummary = 'too long for a short summary';

class NoteStyleSpec {
  final String id;
  final String label;

  /// One line for the picker.
  final String description;

  /// The system text of the write turn, ending with its worked example.
  final String systemPrompt;

  /// The system text of a write turn for a part of a split thought, and of the one retry of a
  /// turn with a long thought (see `longThoughtWords`) whose plain reply left something out:
  /// [systemPrompt] with [longThoughtRules] after the every-thought rule. Null for a style that
  /// does not keep everything; it then uses [systemPrompt] for every turn.
  final String? longThoughtSystemPrompt;

  /// The last line of the user turn, after the numbered thoughts. Read last, so a style whose
  /// form the model tends to drift from repeats it here.
  final String request;

  /// Reply word bounds relative to the spoken words (the maximum gets 30 words of slack, the
  /// minimum applies from 30 spoken words). Null takes the model profile's value, which is what
  /// the fact-keeping styles use.
  final double? minOutputRatio;
  final double? maxOutputRatio;

  /// Whether every numbered thought must be found in the reply (`thoughtsMissingFrom`).
  final bool requiresEveryThought;

  /// Why a reply is not in this style's form, or null when it is.
  final String? Function(String note) formProblem;

  /// Whether a session too long for one write turn may be written in pieces and joined.
  final bool splittable;

  /// Whether a joined piece keeps its own title (it then reads as a section heading).
  final bool keepsPieceTitles;

  /// The single body line that stands for "nothing in this style", dropped when another piece
  /// has content.
  final String? emptyBody;

  const NoteStyleSpec({
    required this.id,
    required this.label,
    required this.description,
    required this.systemPrompt,
    this.longThoughtSystemPrompt,
    required this.requiresEveryThought,
    required this.formProblem,
    this.request = 'Write the note.',
    this.minOutputRatio,
    this.maxOutputRatio,
    this.splittable = true,
    this.keepsPieceTitles = false,
    this.emptyBody,
  });

  /// The system text of a write turn: the long-thought text when it is asked for and this style
  /// has one, otherwise [systemPrompt].
  String systemPromptFor({required bool longThought}) =>
      longThought ? longThoughtSystemPrompt ?? systemPrompt : systemPrompt;

  /// [first] and [second], two pieces written in this style, as one note: one title, and for the
  /// actionable style at most one no-steps line. Organised and professional pieces are kept as
  /// written; a later piece's title then reads as a heading.
  String join(String first, String second) {
    if (keepsPieceTitles) return '$first\n\n$second';
    final lines = [...first.split('\n'), '', ..._withoutTitle(second).split('\n')];
    final empty = emptyBody;
    if (empty != null) {
      final hasContent = _bodyLines(lines.join('\n')).any((l) => l != empty && !_isHeading(l));
      var keptEmpty = false;
      lines.removeWhere((l) {
        if (l.trim() != empty) return false;
        if (hasContent || keptEmpty) return true;
        keptEmpty = true;
        return false;
      });
    }
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

/// The style [id] names; an unknown id (an old or damaged value) reads as organised.
NoteStyleSpec noteStyleById(String id) => noteStyles.firstWhere((s) => s.id == id, orElse: () => noteStyles.first);

/// Whether [id] is a style that can be chosen (one of [noteStyles]; not [manualStyleId]).
bool isKnownNoteStyle(String id) => noteStyles.any((s) => s.id == id);

/// The styles that can be chosen, in picker order; the first is [defaultNoteStyleId].
const List<NoteStyleSpec> noteStyles = [
  NoteStyleSpec(
    id: 'organised',
    label: 'Organised',
    description: 'A title, short headings and bullet points, with every detail kept.',
    systemPrompt: _organisedSystem,
    longThoughtSystemPrompt: _organisedLongSystem,
    requiresEveryThought: true,
    formProblem: _anyForm,
    keepsPieceTitles: true,
  ),
  NoteStyleSpec(
    id: 'concise',
    label: 'Short summary',
    description: 'A title and one to three sentences with the core of what you said.',
    systemPrompt: _conciseSystem,
    request: 'Write the note: the title, then at most three short sentences with only what was said.',
    requiresEveryThought: false,
    formProblem: _summaryProblem,
    minOutputRatio: 0,
    maxOutputRatio: 0.5,
    splittable: false,
  ),
  NoteStyleSpec(
    id: 'bullets',
    label: 'Key points',
    description: 'A title and one flat list of bullet points, with every detail kept.',
    systemPrompt: _bulletsSystem,
    longThoughtSystemPrompt: _bulletsLongSystem,
    requiresEveryThought: true,
    formProblem: _keyPointsProblem,
  ),
  NoteStyleSpec(
    id: 'professional',
    label: 'Professional',
    description: 'The organised note in polished, neutral business wording.',
    systemPrompt: _professionalSystem,
    longThoughtSystemPrompt: _professionalLongSystem,
    requiresEveryThought: true,
    formProblem: _anyForm,
    keepsPieceTitles: true,
  ),
  NoteStyleSpec(
    id: 'journal',
    label: 'Journal entry',
    description: 'A title and paragraphs in your own voice, keeping feelings and reasons.',
    systemPrompt: _journalSystem,
    longThoughtSystemPrompt: _journalLongSystem,
    request: 'Write the journal entry in your own clean sentences, without the filler of speech.',
    requiresEveryThought: true,
    formProblem: _proseProblem,
  ),
  NoteStyleSpec(
    id: 'actionable',
    label: 'Actionable next steps',
    description: 'A checklist of the things to do, each starting with a verb.',
    systemPrompt: _actionableSystem,
    request: 'Write the next steps: only what the speaker still has to do.',
    requiresEveryThought: false,
    formProblem: _stepsProblem,
    minOutputRatio: 0,
    emptyBody: noNextStepsSentence,
  ),
  NoteStyleSpec(
    id: 'casual',
    label: 'Casual note',
    description: 'A friendly, natural note, as you would write it to yourself.',
    systemPrompt: _casualSystem,
    longThoughtSystemPrompt: _casualLongSystem,
    request: 'Write the casual note in your own words, without the filler of speech such as "so yeah" or "like".',
    requiresEveryThought: true,
    formProblem: _proseProblem,
  ),
];

// ---- reply form ----

final RegExp _taskLine = RegExp(r'^[-*]\s+\[[ xX]\]\s+\S');
final RegExp _bulletLine = RegExp(r'^[-*•]\s+\S');
final RegExp _headingLine = RegExp(r'^(\*\*[^*]+\*\*:?|#{1,6}\s+.+)$');
final RegExp _sentenceEnd = RegExp(r'[.!?]+(?=\s|$)');

bool _isTask(String line) => _taskLine.hasMatch(line);
bool _isBullet(String line) => !_isTask(line) && _bulletLine.hasMatch(line);
bool _isHeading(String line) => _headingLine.hasMatch(line);

/// The note's non-blank lines, trimmed, after its title (a first line that is a heading).
List<String> _bodyLines(String note) {
  final lines = [
    for (final l in note.split(RegExp(r'\r\n|\r|\n')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (lines.isNotEmpty && _isHeading(lines.first)) lines.removeAt(0);
  return lines;
}

/// [piece] without its first line when that line is a heading (its title).
String _withoutTitle(String piece) {
  final lines = piece.split('\n');
  final first = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (first >= 0 && _isHeading(lines[first].trim())) lines.removeAt(first);
  return lines.join('\n').trim();
}

String? _anyForm(String note) => null;

String? _summaryProblem(String note) {
  final body = _bodyLines(note);
  if (body.isEmpty) return 'no summary under the title';
  if (body.any((l) => _isTask(l) || _isBullet(l))) return 'a list instead of sentences';
  if (body.any(_isHeading)) return 'a heading under the title';
  final text = body.join(' ');
  var sentences = _sentenceEnd.allMatches(text).length;
  if (!RegExp(r'[.!?]$').hasMatch(text)) sentences++;
  return sentences > 3 ? '$sentences sentences' : null;
}

String? _keyPointsProblem(String note) {
  final body = _bodyLines(note);
  if (body.any(_isTask)) return 'tasks instead of bullet points';
  if (body.any(_isHeading)) return 'a heading under the title';
  return body.any(_isBullet) ? null : 'no bullet points';
}

String? _proseProblem(String note) {
  final body = _bodyLines(note);
  if (body.isEmpty) return 'no text under the title';
  return body.any((l) => _isTask(l) || _isBullet(l)) ? 'bullet points instead of paragraphs' : null;
}

String? _stepsProblem(String note) {
  final body = _bodyLines(note);
  if (body.length == 1 && body.single == noNextStepsSentence) return null;
  if (body.any(_isBullet)) return 'plain bullet points instead of tasks';
  if (!body.any(_isTask)) return 'no tasks';
  if (body.any((l) => !_isTask(l) && !_isHeading(l))) return 'text that is not a task';
  return null;
}

// ---- prompts ----

const String _intro = 'The thoughts were dictated by one person, in order, and transcribed by speech recognition.\n';

const String _exampleThoughts = 'Example:\n'
    'Thoughts:\n'
    '1. Remind me to email Daniel the contract before Friday.\n'
    '2. Okay so, um, I went to see the flat on Park Street yesterday and honestly I liked it a lot, it has two bedrooms and the rent is eighteen hundred a month, which is, like, two hundred more than what we pay now. The landlord said we need to decide by the tenth. I already sent him our documents this morning. Sam still wants to see it, so we will go together on Sunday. I am a bit worried about the noise from the main road though. So yeah, that is where things are.\n'
    'Note:\n';

const String _keepFacts =
    '- Keep every fact: names, numbers, dates, times, places, items in lists, reasons, decisions, plans, purchases, feelings.\n';
const String _keepTense = '- Keep what has already happened, what is planned and what is only wished as the speaker said it.\n';
const String _leaveOut = '- Leave out filler, repetition, false starts and remarks about the recording itself.\n';
const String _corrections = '- When the speaker corrects themselves, keep only the corrected version.\n';
const String _everyThought =
    '- Every numbered thought must appear in the note. Go through them in order and leave none out, including what the speaker says at the very end.\n';

/// The rules of the long-thought text (see [NoteStyleSpec.longThoughtSystemPrompt]), after the
/// every-thought rule: a long thought (a story, something read aloud) must not be written as its
/// opening sentence alone, nor forced into the speaker's first person. Never the first try for an
/// unsplit thought: on ordinary sessions they made Qwen3-4B keep long thoughts nearly verbatim, in
/// fewer headings and longer bullets (TASK-104).
const String longThoughtRules =
    '- A thought can be long: a story, a description or something read aloud. Its opening words do not stand for the rest: write all of it into the note, in the order it was told. What is read aloud or dictated is never a remark about the recording.\n'
    '- A story, a description or a quote keeps its own point of view: "Maya opened the door" stays about Maya. Only what the speaker says about themselves is written in the first person.\n';

const String _organisedSystem = '$_organisedHead$_organisedTail';
const String _organisedLongSystem = '$_organisedHead$longThoughtRules$_organisedTail';

const String _organisedHead =
    'You turn spoken thoughts into one organised written note. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then bullet points, each starting with "- ". When there is more than one topic, put a short heading above each group.\n'
    '- Each bullet is one short, complete sentence in the first person, as the speaker.\n'
    '\n'
    'Rules:\n'
    '$_keepFacts'
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '$_everyThought';
const String _organisedTail =
    '- Add nothing that was not said. No advice, no summary sentence at the end.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    '**Tasks**\n'
    '- I need to email Daniel the contract before Friday.\n'
    '\n'
    '**Flat**\n'
    '- I saw the flat on Park Street yesterday and liked it a lot.\n'
    '- It has two bedrooms and the rent is 1,800 a month, 200 more than we pay now.\n'
    '- The landlord needs our decision by the 10th.\n'
    '- I already sent him our documents this morning.\n'
    '- Sam and I will see it together on Sunday.\n'
    '- I am a bit worried about the noise from the main road.';

const String _conciseSystem =
    'You turn spoken thoughts into one short summary note. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then one to three short sentences, at most 60 words in all, in the first person, as the speaker.\n'
    '- No bullet points and no headings.\n'
    '\n'
    'Rules:\n'
    '- This is a summary: keep only the main points and the most important names, numbers, dates and decisions. Leave out the smaller details.\n'
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '- Add nothing that was not said. No advice. When little was said, the summary is just as short.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    'I need to email Daniel the contract before Friday. I liked the two-bedroom flat on Park Street at 1,800 a month, '
    'I already sent our documents, and Sam and I will see it on Sunday before we decide by the 10th.';

const String _bulletsSystem = '$_bulletsHead$_bulletsTail';
const String _bulletsLongSystem = '$_bulletsHead$longThoughtRules$_bulletsTail';

const String _bulletsHead =
    'You turn spoken thoughts into one note of key points. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then one flat list of bullet points, each starting with "- ". No headings and no sub-points.\n'
    '- Each bullet is one short, complete sentence in the first person, as the speaker.\n'
    '\n'
    'Rules:\n'
    '$_keepFacts'
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '$_everyThought';
const String _bulletsTail =
    '- Add nothing that was not said. No advice, no summary sentence at the end.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    '- I need to email Daniel the contract before Friday.\n'
    '- I saw the flat on Park Street yesterday and liked it a lot.\n'
    '- It has two bedrooms and the rent is 1,800 a month, 200 more than we pay now.\n'
    '- The landlord needs our decision by the 10th.\n'
    '- I already sent him our documents this morning.\n'
    '- Sam and I will see it together on Sunday.\n'
    '- I am a bit worried about the noise from the main road.';

const String _professionalSystem = '$_professionalHead$_professionalTail';
const String _professionalLongSystem = '$_professionalHead$longThoughtRules$_professionalTail';

const String _professionalHead =
    'You turn spoken thoughts into one organised note in professional wording. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then bullet points, each starting with "- ". When there is more than one topic, put a short heading above each group.\n'
    '- Each bullet is one complete sentence in polished, neutral business wording, in the first person, as the speaker.\n'
    '\n'
    'Rules:\n'
    '$_keepFacts'
    '- Do not make anything sound more certain, more urgent or more formal an agreement than the speaker said.\n'
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '$_everyThought';
const String _professionalTail =
    '- Add nothing that was not said. No advice, no summary sentence at the end.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    '**Tasks**\n'
    '- I need to send Daniel the contract before Friday.\n'
    '\n'
    '**Flat**\n'
    '- I viewed the Park Street flat yesterday and was very positive about it.\n'
    '- It has two bedrooms; the rent is 1,800 per month, 200 above our current rent.\n'
    '- The landlord requires our decision by the 10th.\n'
    '- I submitted our documents to him this morning.\n'
    '- Sam and I will view it together on Sunday.\n'
    '- My one concern is noise from the main road.';

const String _journalSystem = '$_journalHead$_journalTail';
const String _journalLongSystem = '$_journalHead$longThoughtRules$_journalTail';

const String _journalHead =
    'You turn spoken thoughts into one journal entry. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then one or more paragraphs of full sentences in the first person, as the speaker, like a diary.\n'
    '- Write each reminder as a sentence about yourself, such as "I need to call the bank."\n'
    '- No bullet points, no lists and no headings.\n'
    '\n'
    'Rules:\n'
    '$_keepFacts'
    "- Keep the speaker's feelings and the reasons they gave, in their own tone.\n"
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '$_everyThought';
const String _journalTail =
    '- Add nothing that was not said. No advice, no lessons, no summary sentence at the end.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    'I need to email Daniel the contract before Friday.\n'
    '\n'
    'Yesterday I went to see the flat on Park Street, and honestly I liked it a lot. It has two bedrooms and the rent '
    'is 1,800 a month, which is 200 more than we pay now. The landlord said we need to decide by the 10th, and I '
    'already sent him our documents this morning. Sam still wants to see it, so we will go together on Sunday. I am a '
    'bit worried about the noise from the main road, though.';

const String _actionableSystem =
    'You turn spoken thoughts into one list of next steps. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then one line for each thing the speaker has to do, each starting with "- [ ] ".\n'
    '- Each step starts with a verb and keeps who, what, when and how many, as the speaker said them.\n'
    '- When the thoughts contain nothing to do, write the title and then only this line: $noNextStepsSentence\n'
    '\n'
    'Rules:\n'
    '- Only things the speaker still has to do become steps. Leave out everything else: descriptions, opinions, feelings, observations and test results.\n'
    '- Something already done is not a step: "I already bought the shoes" is left out.\n'
    '- A meeting, appointment or deadline the speaker has is a step, with its day and time.\n'
    '- Keep the meaning of each step exactly as said: "fix the screen that freezes" stays "Fix the screen that freezes."\n'
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '- Add nothing that was not said. No advice and no steps the speaker did not mention.\n'
    '- Do not number the steps and do not use plain "- " bullets.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    '- [ ] Email Daniel the contract before Friday.\n'
    '- [ ] See the Park Street flat with Sam on Sunday.\n'
    '- [ ] Give the landlord our decision on the flat by the 10th.';

const String _casualSystem = '$_casualHead$_casualTail';
const String _casualLongSystem = '$_casualHead$longThoughtRules$_casualTail';

const String _casualHead =
    'You turn spoken thoughts into one casual note. $_intro'
    '\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then a friendly, natural note in short paragraphs, as the speaker would write it to themselves, in the first person.\n'
    '- No bullet points, no lists and no headings.\n'
    '\n'
    'Rules:\n'
    '$_keepFacts'
    '$_keepTense'
    '$_leaveOut'
    '$_corrections'
    '$_everyThought';
const String _casualTail =
    '- Add nothing that was not said. No advice, no summary sentence at the end.\n'
    '- Output only the note.\n'
    '\n'
    '$_exampleThoughts'
    '**Contract and Park Street Flat**\n'
    '\n'
    'Email Daniel the contract before Friday!\n'
    '\n'
    'Saw the Park Street flat yesterday and honestly really liked it. Two bedrooms, 1,800 a month, so 200 more than we '
    'pay now. The landlord wants our decision by the 10th, and I already sent him our documents this morning. Sam '
    "still wants to see it, so we're going together on Sunday. My one worry is the noise from the main road.";
