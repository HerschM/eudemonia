import 'package:eudemonia/features/notes/data/note_model.dart';

/// Lightweight representation of an origin raw note within a synthesis cluster.
class SynthesisOriginNote {
  final int id;
  final String formattedSequence;
  final String cleanedText;
  final String folder;
  final DateTime timestamp;
  final String? audioPath;

  const SynthesisOriginNote({
    required this.id,
    required this.formattedSequence,
    required this.cleanedText,
    required this.folder,
    required this.timestamp,
    this.audioPath,
  });

  factory SynthesisOriginNote.fromNote(Note note) {
    final seqNum = note.dailySequenceNumber ?? 1;
    final formattedSeq = '#${seqNum.toString().padLeft(2, '0')}';
    final text = note.correctedText.isNotEmpty ? note.correctedText : note.rawText;
    return SynthesisOriginNote(
      id: note.id,
      formattedSequence: formattedSeq,
      cleanedText: text,
      folder: note.folder,
      timestamp: note.createdAt ?? DateTime.now(),
      audioPath: note.originalAudioPath,
    );
  }
}

/// Clustered and synthesized thought session according to UX.md Section 6.
class SynthesisCluster {
  final String clusterId;
  final String sequenceNumber; // e.g. "#S-01"
  final String folder; // Predefined folder e.g. "Ideas", "Work", "Todos", "Journal", "Uncategorized"
  final String synthesizedContent;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final Duration sessionDuration;
  final List<SynthesisOriginNote> originNotes;
  final bool isExpanded;
  final bool isReprocessing; // True when marked yellow for re-synthesis
  final String appliedStyleId; // e.g. "concise", "bullets", "professional", etc.
  final bool isUnread; // Toggles electric blue unread indicator dot
  final bool isActionExtracted; // True when action extraction pass completed (Green)

  const SynthesisCluster({
    required this.clusterId,
    required this.sequenceNumber,
    required this.folder,
    required this.synthesizedContent,
    required this.sessionStart,
    required this.sessionEnd,
    required this.sessionDuration,
    required this.originNotes,
    this.isExpanded = false,
    this.isReprocessing = false,
    this.appliedStyleId = 'concise',
    this.isUnread = false,
    this.isActionExtracted = true,
  });

  SynthesisCluster copyWith({
    String? clusterId,
    String? sequenceNumber,
    String? folder,
    String? synthesizedContent,
    DateTime? sessionStart,
    DateTime? sessionEnd,
    Duration? sessionDuration,
    List<SynthesisOriginNote>? originNotes,
    bool? isExpanded,
    bool? isReprocessing,
    String? appliedStyleId,
    bool? isUnread,
    bool? isActionExtracted,
  }) {
    return SynthesisCluster(
      clusterId: clusterId ?? this.clusterId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      folder: folder ?? this.folder,
      synthesizedContent: synthesizedContent ?? this.synthesizedContent,
      sessionStart: sessionStart ?? this.sessionStart,
      sessionEnd: sessionEnd ?? this.sessionEnd,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      originNotes: originNotes ?? this.originNotes,
      isExpanded: isExpanded ?? this.isExpanded,
      isReprocessing: isReprocessing ?? this.isReprocessing,
      appliedStyleId: appliedStyleId ?? this.appliedStyleId,
      isUnread: isUnread ?? this.isUnread,
      isActionExtracted: isActionExtracted ?? this.isActionExtracted,
    );
  }
}

