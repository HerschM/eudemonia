import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_record.dart';

/// Every Isar collection of the app. A single Isar instance must be opened with all of them.
const List<CollectionSchema<dynamic>> appDatabaseSchemas = [
  NoteSchema,
  SynthesisSessionRecordSchema,
];

Future<Isar> openAppDatabase({String? directory}) async {
  final dirPath = directory ?? (await getApplicationDocumentsDirectory()).path;
  return Isar.open(appDatabaseSchemas, directory: dirPath);
}

/// The opened database, provided by `main()`. `null` (the default) makes
/// repositories fall back to in-memory storage, which unit and widget tests rely on.
final appDatabaseProvider = Provider<Isar?>((ref) => null);
