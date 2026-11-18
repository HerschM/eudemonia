import 'package:isar_community/isar.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

part 'synthesis_session_record.g.dart';

/// Snapshot of a raw capture note as it was when it joined a synthesis session.
@embedded
class SynthesisOriginRecord {
  int noteId = 0;
  String formattedSequence = '';
  String cleanedText = '';
  String folder = 'Uncategorized';
  DateTime? timestamp;
  String? audioPath;
}

/// Durable form of a [SynthesisCluster]. Transient view state (`isExpanded`) is not stored.
@collection
class SynthesisSessionRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late String clusterId;

  late String sequenceNumber;
  late String folder;
  late String synthesizedContent;
  late DateTime sessionStart;
  late DateTime sessionEnd;
  late int sessionDurationSeconds;
  List<SynthesisOriginRecord> originNotes = [];
  bool isReprocessing = false;
  String appliedStyleId = 'concise';
  bool isUnread = false;
  bool isActionExtracted = true;

  SynthesisSessionRecord();

  factory SynthesisSessionRecord.fromCluster(SynthesisCluster cluster) {
    return SynthesisSessionRecord()
      ..clusterId = cluster.clusterId
      ..sequenceNumber = cluster.sequenceNumber
      ..folder = cluster.folder
      ..synthesizedContent = cluster.synthesizedContent
      ..sessionStart = cluster.sessionStart
      ..sessionEnd = cluster.sessionEnd
      ..sessionDurationSeconds = cluster.sessionDuration.inSeconds
      ..originNotes = [
        for (final n in cluster.originNotes)
          SynthesisOriginRecord()
            ..noteId = n.id
            ..formattedSequence = n.formattedSequence
            ..cleanedText = n.cleanedText
            ..folder = n.folder
            ..timestamp = n.timestamp
            ..audioPath = n.audioPath,
      ]
      ..isReprocessing = cluster.isReprocessing
      ..appliedStyleId = cluster.appliedStyleId
      ..isUnread = cluster.isUnread
      ..isActionExtracted = cluster.isActionExtracted;
  }

  SynthesisCluster toCluster() {
    return SynthesisCluster(
      clusterId: clusterId,
      sequenceNumber: sequenceNumber,
      folder: folder,
      synthesizedContent: synthesizedContent,
      sessionStart: sessionStart,
      sessionEnd: sessionEnd,
      sessionDuration: Duration(seconds: sessionDurationSeconds),
      originNotes: [
        for (final n in originNotes)
          SynthesisOriginNote(
            id: n.noteId,
            formattedSequence: n.formattedSequence,
            cleanedText: n.cleanedText,
            folder: n.folder,
            timestamp: n.timestamp ?? sessionStart,
            audioPath: n.audioPath,
          ),
      ],
      isReprocessing: isReprocessing,
      appliedStyleId: appliedStyleId,
      isUnread: isUnread,
      isActionExtracted: isActionExtracted,
    );
  }
}
