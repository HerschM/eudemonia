enum AudioQueueStatus {
  pending,
  transcribing,
  categorizing,
  completed,
  failed,
}

class AudioQueueItem {
  final String id;
  final String audioFilePath;
  final DateTime recordedAt;
  AudioQueueStatus status;
  String? rawTranscript;
  String? folder;
  String? correctedText;
  String? errorMessage;

  AudioQueueItem({
    required this.id,
    required this.audioFilePath,
    required this.recordedAt,
    this.status = AudioQueueStatus.pending,
    this.rawTranscript,
    this.folder,
    this.correctedText,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioFilePath': audioFilePath,
        'recordedAt': recordedAt.toIso8601String(),
        'status': status.name,
        'rawTranscript': rawTranscript,
        'folder': folder,
        'correctedText': correctedText,
        'errorMessage': errorMessage,
      };

  factory AudioQueueItem.fromJson(Map<String, dynamic> json) => AudioQueueItem(
        id: json['id'] as String,
        audioFilePath: json['audioFilePath'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        status: AudioQueueStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => AudioQueueStatus.pending,
        ),
        rawTranscript: json['rawTranscript'] as String?,
        folder: json['folder'] as String?,
        correctedText: json['correctedText'] as String?,
        errorMessage: json['errorMessage'] as String?,
      );
}
