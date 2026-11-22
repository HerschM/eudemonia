/// Per-model settings for the synthesis turns. Pure Dart.
library;

/// Chat template a model expects around the system and user text.
enum ChatFormat { chatml, llama3 }

/// How the write turn shapes a note.
enum NoteStyle { cleanUp, structured }

class SynthesisModelProfile {
  final String modelFileName;
  final ChatFormat chatFormat;
  final NoteStyle noteStyle;

  /// Max thoughts per organise turn.
  final int organiseBatchSize;

  /// Max input words per write turn.
  final int writeWordLimit;

  /// A reply with fewer words than this fraction of the input is invalid.
  final double minOutputRatio;

  /// A reply with more words than this fraction of the input (+30 words) is invalid.
  final double maxOutputRatio;

  const SynthesisModelProfile({
    required this.modelFileName,
    required this.chatFormat,
    required this.noteStyle,
    required this.organiseBatchSize,
    required this.writeWordLimit,
    required this.minOutputRatio,
    required this.maxOutputRatio,
  });

  static const qwen25_1_5b = SynthesisModelProfile(
    modelFileName: 'qwen2.5-1.5b.gguf',
    chatFormat: ChatFormat.chatml,
    noteStyle: NoteStyle.cleanUp,
    organiseBatchSize: 5,
    writeWordLimit: 700,
    minOutputRatio: 0.5,
    maxOutputRatio: 1.3,
  );
}
