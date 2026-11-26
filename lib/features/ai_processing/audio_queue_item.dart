enum AudioQueueStatus {
  pending,
  transcribing,
  completed,
  failed,
}

/// What a recording with no recognised speech is reported as. A silent recording is not a
/// failure: screens show it as a calm note, offer no Retry and leave it out of failure counts.
const String silentRecordingMessage = 'Nothing was heard in this recording.';

/// Wording used before [silentRecordingMessage]; still found in queue files written by older builds.
const String _legacySilentRecordingMessage = 'No speech detected in audio recording.';

/// True when [message] (a queue item's `errorMessage` or a note's `failureReason`) says the
/// recording was silent. The single place that decides this.
bool isSilentRecordingMessage(String? message) =>
    message == silentRecordingMessage || message == _legacySilentRecordingMessage;

class AudioQueueItem {
  final String id;
  final String audioFilePath;
  final DateTime recordedAt;
  AudioQueueStatus status;
  String? rawTranscript;
  String? correctedText;
  String? errorMessage;
  int? sequenceNumber;

  /// A recording that was transcribed but held no speech.
  bool get isSilent => status == AudioQueueStatus.failed && isSilentRecordingMessage(errorMessage);

  AudioQueueItem({
    required this.id,
    required this.audioFilePath,
    required this.recordedAt,
    this.status = AudioQueueStatus.pending,
    this.rawTranscript,
    this.correctedText,
    this.errorMessage,
    this.sequenceNumber,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioFilePath': audioFilePath,
        'recordedAt': recordedAt.toIso8601String(),
        'status': status.name,
        'rawTranscript': rawTranscript,
        'correctedText': correctedText,
        'errorMessage': errorMessage,
        'sequenceNumber': sequenceNumber,
      };

  factory AudioQueueItem.fromJson(Map<String, dynamic> json) => AudioQueueItem(
        id: json['id'] as String,
        audioFilePath: json['audioFilePath'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        status: AudioQueueStatus.values.firstWhere(
          (e) => e.name == json['status'],
          // An unrecognised stored status waits for transcription again.
          orElse: () => AudioQueueStatus.pending,
        ),
        rawTranscript: json['rawTranscript'] as String?,
        correctedText: json['correctedText'] as String?,
        errorMessage: json['errorMessage'] as String?,
        sequenceNumber: json['sequenceNumber'] as int?,
      );
}
