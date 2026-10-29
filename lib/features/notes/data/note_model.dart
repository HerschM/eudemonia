import 'package:isar/isar.dart';

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
  
  @Index()
  late String folder;
  
  late DateTime createdAt;

  @ignore
  ThoughtState state = ThoughtState.processed;

  @ignore
  bool isRead = false;

  @ignore
  String? failureReason;

  Note({
    this.originalAudioPath,
    this.rawText = '',
    this.correctedText = '',
    this.folder = 'Uncategorized',
    DateTime? createdAt,
    this.state = ThoughtState.processed,
    this.isRead = false,
    this.failureReason,
  }) : createdAt = createdAt ?? DateTime.now();
}
