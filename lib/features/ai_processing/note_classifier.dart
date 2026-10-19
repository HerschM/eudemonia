import 'dart:convert';

/// Result of processing and categorizing a raw speech transcript.
class NoteClassificationResult {
  final String rawText;
  final String correctedText;
  final String selectedFolder;
  final Map<String, double> folderScores;
  final String? reasoning;
  final bool usedFallback;

  /// Alias for selectedFolder to maintain compatibility with existing callers.
  String get folder => selectedFolder;

  const NoteClassificationResult({
    required this.rawText,
    required this.correctedText,
    required this.selectedFolder,
    required this.folderScores,
    this.reasoning,
    this.usedFallback = false,
  });

  /// Formatted confidence scores for logging and display.
  String get formattedScores {
    return folderScores.entries
        .map((e) => '${e.key}: ${(e.value * 100).toStringAsFixed(0)}%')
        .join(' | ');
  }

  /// Print structured debug logs requested for observability.
  void printDebugLog() {
    print('=================== [AI Note Processing] ===================');
    print('[Raw Transcript]             : "$rawText"');
    print('[Language Corrected]         : "$correctedText"');
    print('[Folder Confidence Scores]   : $formattedScores');
    print('[Selected Folder]            : "$selectedFolder"');
    if (reasoning != null && reasoning!.isNotEmpty) {
      print('[Reasoning]                  : $reasoning');
    }
    if (usedFallback) {
      print('[Notice]                     : Processed via heuristic fallback classifier');
    }
    print('============================================================');
  }
}

/// Classifier and parser for note language correction and folder categorization.
class NoteClassifier {
  static const List<String> allowedFolders = ['Work', 'Ideas', 'Todos', 'Journal'];
  static const String defaultFolder = 'Uncategorized';

  /// Construct a ChatML prompt formatted for Qwen 2.5 Instruct.
  static String buildPrompt(String rawText) {
    return '''<|im_start|>system
You are an expert voice note editor and classifier.
Your task has two strict requirements:
1. LANGUAGE CORRECTION:
   - Fix grammar, punctuation, and capitalization.
   - Remove conversational disfluencies and filler words ("um", "uh", "er", "ah", "like", "you know", "basically", "so yeah").
   - Preserve the speaker's authentic voice, tone, and specific details. Do NOT summarize or invent new information.
2. FOLDER CATEGORIZATION:
   Categorize the note into EXACTLY ONE of the following 4 folders:
   - "Work": Professional projects, meetings, colleagues, clients, career, business communications.
   - "Ideas": Creative concepts, inventions, startup or product brainstorms, hypotheses, design ideas.
   - "Todos": Action items, chores, errands, shopping lists, immediate tasks to do or buy.
   - "Journal": Personal reflections, diary entries, emotions, mood, gratitude, wellness, daily life memories.

Provide confidence scores between 0.0 and 1.0 for each of the 4 folders (they should sum to approximately 1.0).
Select the single folder with the highest confidence as "folder". The "folder" value MUST be a single folder name, NOT a list or combination.

Output STRICTLY valid JSON with no markdown wrapping and no additional explanation:
{
  "corrected_text": "<grammar-corrected text without filler words>",
  "confidence_scores": {
    "Work": 0.05,
    "Ideas": 0.85,
    "Todos": 0.05,
    "Journal": 0.05
  },
  "folder": "Ideas",
  "reasoning": "<brief one-sentence rationale>"
}
<|im_end|>
<|im_start|>user
Raw speech transcript:
"$rawText"
<|im_end|>
<|im_start|>assistant
''';
  }

  /// Parses the LLM's response into a validated [NoteClassificationResult].
  static NoteClassificationResult parseResponse(String rawText, String llmOutput) {
    try {
      final jsonMap = _extractJson(llmOutput);
      if (jsonMap == null) {
        return fallbackClassify(rawText, reason: 'No valid JSON found in model output');
      }

      // 1. Extract and validate corrected text
      String corrected = (jsonMap['corrected_text'] ?? '').toString().trim();
      if (corrected.isEmpty) {
        corrected = cleanRawText(rawText);
      }

      // 2. Extract and validate confidence scores
      final scores = _parseScores(jsonMap['confidence_scores'] ?? jsonMap['folder_scores']);

      // 3. Extract and disambiguate folder
      final rawFolder = (jsonMap['folder'] ?? '').toString().trim();
      final folder = _resolveSingleFolder(rawFolder, scores, corrected.isNotEmpty ? corrected : rawText);

      // 4. Extract reasoning
      final reasoning = jsonMap['reasoning']?.toString().trim();

      return NoteClassificationResult(
        rawText: rawText,
        correctedText: corrected,
        selectedFolder: folder,
        folderScores: scores,
        reasoning: reasoning,
        usedFallback: false,
      );
    } catch (e) {
      return fallbackClassify(rawText, reason: 'JSON parse error: $e');
    }
  }

  /// Fallback heuristic classifier when LLM is uninitialized, times out, or fails JSON parsing.
  static NoteClassificationResult fallbackClassify(String rawText, {String? reason}) {
    final cleaned = cleanRawText(rawText);
    final scores = computeKeywordScores(cleaned);

    // Pick folder with highest score, or Uncategorized if all 0
    String selected = defaultFolder;
    double maxScore = 0.0;
    for (final folder in allowedFolders) {
      final score = scores[folder] ?? 0.0;
      if (score > maxScore) {
        maxScore = score;
        selected = folder;
      }
    }

    return NoteClassificationResult(
      rawText: rawText,
      correctedText: cleaned,
      selectedFolder: selected,
      folderScores: scores,
      reasoning: reason ?? 'Classified via keyword heuristic matching',
      usedFallback: true,
    );
  }

  /// Basic rule-based text cleaning (removes common filler words, fixes capitalization & punctuation).
  static String cleanRawText(String text) {
    if (text.trim().isEmpty) return text;

    // Remove filler words
    final fillerPattern = RegExp(r'\b(um|uh|er|ah|umm|uhh|you know|basically)\b', caseSensitive: false);
    String cleaned = text.replaceAll(fillerPattern, ' ');

    // Normalize multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return text.trim();

    // Capitalize first letter
    cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);

    // Ensure ending punctuation
    if (!RegExp(r'[.!?]$').hasMatch(cleaned)) {
      cleaned = '$cleaned.';
    }

    return cleaned;
  }

  /// Extracts the JSON object from raw LLM output, handling markdown fences and extraneous text.
  static Map<String, dynamic>? _extractJson(String text) {
    try {
      // Strip markdown code block markers if present
      String clean = text.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
                         .replaceAll(RegExp(r'```\s*'), '')
                         .trim();

      final firstBrace = clean.indexOf('{');
      final lastBrace = clean.lastIndexOf('}');

      if (firstBrace == -1 || lastBrace == -1 || firstBrace >= lastBrace) {
        return null;
      }

      final jsonSubstring = clean.substring(firstBrace, lastBrace + 1);
      final decoded = jsonDecode(jsonSubstring);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses confidence scores safely, ensuring all 4 folders are represented.
  static Map<String, double> _parseScores(dynamic rawScores) {
    final Map<String, double> result = {
      'Work': 0.0,
      'Ideas': 0.0,
      'Todos': 0.0,
      'Journal': 0.0,
    };

    if (rawScores is Map) {
      for (final folder in allowedFolders) {
        final val = rawScores[folder] ?? rawScores[folder.toLowerCase()];
        if (val is num) {
          result[folder] = val.toDouble().clamp(0.0, 1.0);
        } else if (val is String) {
          final parsed = double.tryParse(val);
          if (parsed != null) {
            result[folder] = parsed.clamp(0.0, 1.0);
          }
        }
      }
    }

    // If all scores parsed as 0.0, keep as 0.0 (or unclassified)
    final sum = result.values.fold(0.0, (a, b) => a + b);
    if (sum > 0.0) {
      // Normalize to sum to 1.0
      for (final folder in allowedFolders) {
        result[folder] = double.parse((result[folder]! / sum).toStringAsFixed(2));
      }
    }

    return result;
  }

  /// Resolves the raw folder string into exactly ONE valid folder name.
  /// Fixes composite/slash strings (e.g., "Work/Ideas/Todos/Journal" or "Work/Ideas") by using
  /// confidence scores and keyword heuristics to pick the best single folder.
  static String _resolveSingleFolder(String rawFolder, Map<String, double> scores, String text) {
    final trimmed = rawFolder.trim();

    // 1. Direct exact match (case-insensitive)
    for (final folder in allowedFolders) {
      if (folder.toLowerCase() == trimmed.toLowerCase()) {
        return folder;
      }
    }

    // 2. Check if rawFolder is a composite/slash string (e.g. "Work/Ideas/Todos/Journal" or "Work/Ideas")
    final isComposite = trimmed.contains('/') || trimmed.contains('|') || trimmed.contains(',');

    if (!isComposite) {
      // Common synonyms mapping for single-category names
      final lower = trimmed.toLowerCase();
      if (lower.contains('task') || lower == 'todo' || lower.contains('chore') || lower.contains('errand')) {
        return 'Todos';
      }
      if (lower.contains('idea') || lower.contains('concept') || lower.contains('brainstorm')) {
        return 'Ideas';
      }
      if (lower.contains('personal') || lower.contains('diary') || lower.contains('reflection') || lower.contains('emotion')) {
        return 'Journal';
      }
      if (lower == 'work' || lower.contains('job') || lower.contains('business') || lower.contains('meeting') || lower.contains('career')) {
        return 'Work';
      }
    }

    // 3. For composite strings or unmapped folders:
    // Disambiguate using highest confidence score among allowed folders
    String bestByScore = allowedFolders.first;
    double maxScore = -1.0;
    for (final folder in allowedFolders) {
      final score = scores[folder] ?? 0.0;
      if (score > maxScore) {
        maxScore = score;
        bestByScore = folder;
      }
    }

    // If one folder clearly has higher confidence (> 0.35), use it
    if (maxScore > 0.35) {
      return bestByScore;
    }

    // 4. Otherwise, use deterministic keyword matching across the text
    final keywordScores = computeKeywordScores(text);
    String bestByKeyword = allowedFolders.first;
    double maxKeywordScore = 0.0;
    for (final folder in allowedFolders) {
      final kScore = keywordScores[folder] ?? 0.0;
      if (kScore > maxKeywordScore) {
        maxKeywordScore = kScore;
        bestByKeyword = folder;
      }
    }

    if (maxKeywordScore > 0.0) {
      return bestByKeyword;
    }

    return bestByScore;
  }

  /// Calculates folder scores based on domain keywords and intent patterns.
  static Map<String, double> computeKeywordScores(String text) {
    final lower = text.toLowerCase();

    final todoKeywords = [
      'todo', 'to do', 'need to', 'remember to', 'don\'t forget', 'dont forget',
      'buy', 'purchase', 'call', 'schedule', 'pick up', 'finish', 'clean', 'task',
      'groceries', 'remind me', 'order', 'checklist', 'send email to', 'doctor appointment',
    ];

    final workKeywords = [
      'client', 'meeting', 'project', 'boss', 'colleague', 'presentation', 'report',
      'sprint', 'deadline', 'quarterly', 'office', 'team', 'revenue', 'budget',
      'contract', 'company', 'standup', 'stakeholder', 'deliverable', 'investor', 'pitch',
    ];

    final ideaKeywords = [
      'what if', 'idea', 'concept', 'feature', 'invent', 'brainstorm', 'could build',
      'app where', 'maybe we can', 'maybe we could', 'hypothesis', 'innovative',
      'startup', 'product idea', 'design concept', 'new approach', 'experiment',
    ];

    final journalKeywords = [
      'today', 'yesterday', 'felt', 'feeling', 'tired', 'happy', 'grateful', 'diary',
      'morning', 'night', 'reflection', 'mood', 'anxious', 'sad', 'hopeful', 'dream',
      'sleep', 'walk', 'stress', 'peaceful', 'overwhelmed', 'thankful', 'meditation',
    ];

    int countMatches(List<String> keywords) {
      int count = 0;
      for (final kw in keywords) {
        if (lower.contains(kw)) {
          count++;
        }
      }
      return count;
    }

    final todoCount = countMatches(todoKeywords);
    final workCount = countMatches(workKeywords);
    final ideaCount = countMatches(ideaKeywords);
    final journalCount = countMatches(journalKeywords);

    final total = todoCount + workCount + ideaCount + journalCount;
    if (total == 0) {
      return {
        'Work': 0.0,
        'Ideas': 0.0,
        'Todos': 0.0,
        'Journal': 0.0,
      };
    }

    return {
      'Work': double.parse((workCount / total).toStringAsFixed(2)),
      'Ideas': double.parse((ideaCount / total).toStringAsFixed(2)),
      'Todos': double.parse((todoCount / total).toStringAsFixed(2)),
      'Journal': double.parse((journalCount / total).toStringAsFixed(2)),
    };
  }
}
