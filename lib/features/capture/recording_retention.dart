import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/notes/audio_playback_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'recording_retention_settings.dart';

/// What a sweep removed (or, for [RecordingRetentionService.preview], would remove): recordings
/// whose audio file was deleted, the bytes they took, and the ones that could not be deleted.
class RecordingRemoval {
  final int count;
  final int bytes;
  final int failed;

  const RecordingRemoval({this.count = 0, this.bytes = 0, this.failed = 0});
}

/// The recordings that stored thoughts point to and are still on the phone.
class RecordingsOnPhone {
  final int count;
  final int bytes;

  const RecordingsOnPhone({required this.count, required this.bytes});
}

/// Sizes are decimal: a recording is 16 kHz mono 16-bit audio, 1.92 MB per minute.
String formatRecordingSize(int bytes) {
  if (bytes <= 0) return '0 MB';
  if (bytes < 1000000) return 'under 1 MB';
  final mb = bytes / 1000000;
  if (mb >= 1000) return '${(mb / 1000).toStringAsFixed(1)} GB';
  final decimal = mb.toStringAsFixed(1);
  if (mb < 10 && decimal != '10.0') return '$decimal MB';
  return '${mb.round()} MB';
}

/// "Recordings on this phone: 132 MB in 60 recordings".
String recordingsOnPhoneLine(RecordingsOnPhone size) {
  if (size.count == 0) return 'No recordings are kept on this phone.';
  final noun = size.count == 1 ? 'recording' : 'recordings';
  return 'Recordings on this phone: ${formatRecordingSize(size.bytes)} in ${size.count} $noun';
}

/// Removes the original audio of thoughts that are transcribed and older than the chosen
/// [RecordingRetention] period, and forgets the path. The text and notes always stay.
///
/// Never touched: a thought still waiting or being transcribed, a failed one (Retry needs its
/// audio), a recording the queue still holds (which includes a silent one the user has not dealt
/// with), the recording being played, a thought whose date is unknown, and anything at all when the
/// choice is `Always`. One failing delete is logged and the rest go on. Every file access is awaited.
class RecordingRetentionService {
  static const _sweepEvery = Duration(days: 1);

  final NotesRepository _notes;
  final Set<String> Function() _busyAudioPaths;
  final String? Function() _playingAudioPath;
  final DateTime Function() _now;
  final AppLogger? _logger;
  final Future<int?> Function(String path) _fileSize;
  final Future<void> Function(String path) _deleteFile;

  DateTime? _lastSweepAt;
  Future<void> _tail = Future.value();

  RecordingRetentionService({
    required this._notes,
    required this._busyAudioPaths,
    required this._playingAudioPath,
    required this._now,
    this._logger,
    Future<int?> Function(String path)? fileSize,
    Future<void> Function(String path)? deleteFile,
  })  : _fileSize = fileSize ?? _lengthOfFile,
        _deleteFile = deleteFile ?? _deleteFileFromDisk;

  /// Size of the file, or null when it is not there.
  static Future<int?> _lengthOfFile(String path) async {
    try {
      final file = File(path);
      return await file.exists() ? await file.length() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteFileFromDisk(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// What is on the phone now: every stored thought's recording that still exists.
  Future<RecordingsOnPhone> measure() async {
    var count = 0;
    var bytes = 0;
    try {
      for (final note in await _notes.getAllNotes()) {
        final path = note.originalAudioPath;
        if (path == null || path.isEmpty) continue;
        final size = await _fileSize(path);
        if (size == null) continue;
        count++;
        bytes += size;
      }
    } catch (e) {
      _logger?.warning('[Recordings] Could not measure the recordings: $e');
    }
    return RecordingsOnPhone(count: count, bytes: bytes);
  }

  /// What a sweep with [period] would remove right now. Changes nothing.
  Future<RecordingRemoval> preview(RecordingRetention period) async {
    final days = period.days;
    if (days == null) return const RecordingRemoval();
    var count = 0;
    var bytes = 0;
    try {
      for (final note in await _eligible(days)) {
        final size = await _fileSize(note.originalAudioPath!);
        if (size == null) continue;
        count++;
        bytes += size;
      }
    } catch (e) {
      _logger?.warning('[Recordings] Could not count the recordings to remove: $e');
    }
    return RecordingRemoval(count: count, bytes: bytes);
  }

  /// Removes what [period] says is too old. Sweeps never overlap: one asked for while another is
  /// running waits for it.
  Future<RecordingRemoval> sweep(RecordingRetention period) {
    final run = _tail.then((_) => _sweepNow(period));
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// A sweep for the app coming back to the foreground: at most one a day.
  Future<void> sweepIfDue(RecordingRetention period) async {
    if (period.days == null) return;
    final last = _lastSweepAt;
    if (last != null && _now().difference(last) < _sweepEvery) return;
    await sweep(period);
  }

  Future<RecordingRemoval> _sweepNow(RecordingRetention period) async {
    final days = period.days;
    if (days == null) return const RecordingRemoval();
    _lastSweepAt = _now();
    var count = 0;
    var bytes = 0;
    var failed = 0;
    try {
      for (final note in await _eligible(days)) {
        final path = note.originalAudioPath!;
        // The recording may have started playing since the list was read.
        if (_playingAudioPath() == path) continue;
        try {
          final size = await _fileSize(path);
          if (size != null) await _deleteFile(path);
          await _notes.clearAudioPath(note.id);
          if (size != null) {
            count++;
            bytes += size;
          }
        } catch (e) {
          failed++;
          _logger?.warning('[Recordings] Could not remove the recording of thought ${note.id}: $e');
        }
      }
    } catch (e) {
      _logger?.warning('[Recordings] The sweep of old recordings stopped: $e');
    }
    if (count > 0 || failed > 0) {
      _logger?.info('[Recordings] Removed $count recording(s), ${formatRecordingSize(bytes)}; $failed failed.');
    }
    return RecordingRemoval(count: count, bytes: bytes, failed: failed);
  }

  /// Thoughts whose recording may go: transcribed, with a path, strictly older than [days] days.
  Future<List<Note>> _eligible(int days) async {
    final cutoff = _now().subtract(Duration(days: days));
    final busy = _busyAudioPaths();
    final playing = _playingAudioPath();
    return [
      for (final note in await _notes.getAllNotes())
        if (_isEligible(note, cutoff, busy, playing)) note,
    ];
  }

  bool _isEligible(Note note, DateTime cutoff, Set<String> busy, String? playing) {
    final path = note.originalAudioPath;
    if (path == null || path.isEmpty) return false;
    if (note.state != ThoughtState.processed && note.state != ThoughtState.synthesized) return false;
    if (busy.contains(path) || path == playing) return false;
    final created = note.createdAt;
    return created != null && created.isBefore(cutoff);
  }
}

final recordingRetentionServiceProvider = Provider<RecordingRetentionService>((ref) {
  return RecordingRetentionService(
    notes: ref.watch(notesRepositoryProvider),
    // Everything the queue still holds: waiting, being transcribed, failed or silent.
    busyAudioPaths: () => {
      for (final item in ref.read(queueItemsProvider))
        if (item.status != AudioQueueStatus.completed) item.audioFilePath,
    },
    playingAudioPath: () {
      final playback = ref.read(audioPlaybackControllerProvider);
      return playback.isPlaying ? playback.currentAudioPath : null;
    },
    now: DateTime.now,
    logger: ref.watch(appLoggerProvider),
  );
});

/// What the Settings line "Recordings on this phone" shows; measured again whenever a thought changes.
final recordingsOnPhoneProvider = FutureProvider<RecordingsOnPhone>((ref) async {
  ref.watch(notesRevisionProvider);
  return ref.watch(recordingRetentionServiceProvider).measure();
});
