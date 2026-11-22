import 'package:isar_community/isar.dart';

part 'note_model.g.dart';

enum ThoughtState {
  enqueued,
  processed,
  failed,
  synthesized,
}

@collection
class Note {
  Id id = Isar.autoIncrement;

  String? originalAudioPath;
  
  late String rawText;
  
  late String correctedText;
  
  DateTime? createdAt;

  int? dailySequenceNumber;

  @Enumerated(EnumType.name)
  ThoughtState state = ThoughtState.processed;

  bool isRead = false;

  String? failureReason;

  /// Synthesis runs that got a model answer but could not file or write this thought.
  int synthesisAttempts = 0;

  Note({
    this.originalAudioPath,
    this.rawText = '',
    this.correctedText = '',
    DateTime? createdAt,
    this.dailySequenceNumber,
    this.state = ThoughtState.processed,
    this.isRead = false,
    this.failureReason,
  }) : createdAt = createdAt ?? DateTime.now();
}
