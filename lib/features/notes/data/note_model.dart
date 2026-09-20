import 'package:isar/isar.dart';

part 'note_model.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  String? originalAudioPath;
  
  late String rawText;
  
  late String correctedText;
  
  @Index()
  late String folder;
  
  late DateTime createdAt;
}
