/// Pure-Dart text metrics for the voice evaluation harness (no Flutter imports, host-testable).
library;

/// Filler words and phrases counted by [countFillers] and ignored by [contentRecall].
/// "like" is deliberately absent: it cannot be told apart from the real word.
const List<String> fillerPhrases = [
  'um',
  'umm',
  'uh',
  'uhh',
  'er',
  'ah',
  'you know',
  'basically',
  'so yeah',
];

final RegExp _fillerPattern = RegExp(
  // Longest alternatives first so "umm" is not matched as "um" + "m".
  '\\b(?:${(List<String>.of(fillerPhrases)..sort((a, b) => b.length.compareTo(a.length))).join('|')})\\b',
);

/// Lowercases, turns hyphens into spaces, drops all other punctuation and collapses whitespace.
/// "9:30" becomes "930" and "$42,000" becomes "42000" on both sides of a comparison.
String normalizeForComparison(String text) {
  return text
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r"[^a-z0-9\s]"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _words(String text) {
  final normalized = normalizeForComparison(text);
  return normalized.isEmpty ? const [] : normalized.split(' ');
}

/// Word error rate: word-level Levenshtein distance (substitutions + insertions + deletions)
/// divided by the number of reference words. An empty reference gives 0 for an empty
/// hypothesis and the hypothesis word count otherwise.
double wordErrorRate(String reference, String hypothesis) {
  final ref = _words(reference);
  final hyp = _words(hypothesis);
  if (ref.isEmpty) return hyp.length.toDouble();

  var previous = List<int>.generate(hyp.length + 1, (j) => j);
  for (var i = 1; i <= ref.length; i++) {
    final current = List<int>.filled(hyp.length + 1, 0)..[0] = i;
    for (var j = 1; j <= hyp.length; j++) {
      final cost = ref[i - 1] == hyp[j - 1] ? 0 : 1;
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
    previous = current;
  }
  return previous[hyp.length] / ref.length;
}

/// Share (0..1) of the source's non-filler words that are still present in [cleaned].
/// Returns 1 when the source has no content words.
double contentRecall(String source, String cleaned) {
  final sourceWords =
      _words(normalizeForComparison(source).replaceAll(_fillerPattern, ' '));
  if (sourceWords.isEmpty) return 1.0;
  final cleanedWords = _words(cleaned).toSet();
  final kept = sourceWords.where(cleanedWords.contains).length;
  return kept / sourceWords.length;
}

/// Number of filler words or phrases (see [fillerPhrases]) in [text].
int countFillers(String text) =>
    _fillerPattern.allMatches(normalizeForComparison(text)).length;

/// Returns the facts from [mustKeep] that are absent from [text]. Each fact is a list of
/// acceptable spellings; the fact survives when any spelling appears as whole words.
/// Each returned entry is the first spelling of the missing fact.
List<String> missingFacts(String text, List<List<String>> mustKeep) {
  final haystack = ' ${normalizeForComparison(text)} ';
  final missing = <String>[];
  for (final spellings in mustKeep) {
    final found = spellings.any((s) {
      final needle = normalizeForComparison(s);
      return needle.isNotEmpty && haystack.contains(' $needle ');
    });
    if (!found && spellings.isNotEmpty) missing.add(spellings.first);
  }
  return missing;
}
