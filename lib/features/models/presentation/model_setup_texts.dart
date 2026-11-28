/// The words and numbers of the model setup screen, as pure functions. Pure Dart.
library;

import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';

/// Decimal units: `671 MB`, `2.5 GB`, `1.1 GB`. GB gets one decimal, MB none.
String formatModelBytes(int bytes) {
  final megabytes = (bytes / 1e6).round();
  if (megabytes < 1000) return '${megabytes < 1 && bytes > 0 ? 1 : megabytes} MB';
  return '${(bytes / 1e9).toStringAsFixed(1)} GB';
}

/// `312 MB of 671 MB`.
String describeProgress(ModelAvailability a) => '${formatModelBytes(a.downloadedBytes)} of ${formatModelBytes(a.totalBytes)}';

/// Why a download waits (paused) or stopped (failed), in plain words.
String describeModelReason(String? reason, {required bool failed}) {
  if (!failed) {
    return switch (reason) {
      'waiting_for_wifi' => 'Waiting for Wi-Fi',
      'waiting_for_network' => 'Waiting for a connection',
      'waiting_to_retry' => 'Retrying soon',
      'queued_wifi_only' => 'Waiting for Wi-Fi',
      'queued' => 'Waiting to start',
      _ => 'Paused',
    };
  }
  if (reason != null && reason.startsWith('http_')) {
    final code = reason.substring('http_'.length);
    if (code.isNotEmpty && int.tryParse(code) != null) {
      return 'The download server answered with an error ($code). Try again later.';
    }
  }
  return switch (reason) {
    'checksum' => 'The file was damaged in transfer. Try again.',
    'insufficient_space' => 'Not enough free storage on this phone.',
    'cancelled' => 'Download cancelled.',
    _ => 'The download did not finish. Try again.',
  };
}

/// `Needs a phone with 8 GB of memory. This phone has 6 GB.`
String describeModelDoesNotFit(ModelSpec spec, int? totalRamMb) {
  final needs = 'Needs a phone with ${spec.requiredNominalGb} GB of memory.';
  if (totalRamMb == null) return needs;
  return '$needs This phone has ${ModelCatalogue.nominalGb(totalRamMb)} GB.';
}

/// `Synthesis needs a phone with at least N GB of memory. ...`
String describeNoModelFits(int smallestGb) =>
    'Synthesis needs a phone with at least $smallestGb GB of memory. Capture and transcription work on this phone.';

/// `2.5 GB download · Uses about 3.7 GB of memory while writing`.
String describeModelDownload(ModelSpec spec) {
  final size = '${formatModelBytes(spec.totalBytes)} download';
  return spec.kind == ModelKind.language ? '$size · ${spec.memoryLine}' : size;
}

/// What the Settings row shows after `Speech model ·`: the chosen model's name once it is ready,
/// otherwise its state (`Downloading 45%`, ...). With none chosen: `Not chosen` when a model is
/// downloaded, else the state of the transfer under way, or `Not downloaded`.
String describeSpeechModelSummary({
  required ModelSpec? selected,
  required ModelAvailability availability,
  required bool anyDownloaded,
}) {
  if (selected != null && availability.isReady) return selected.displayName;
  if (selected == null && anyDownloaded && availability.kind == ModelAvailabilityKind.absent) return 'Not chosen';
  return describeSpeechModelState(availability);
}

/// One-line state of the speech model, for Settings: `Ready`, `Downloading 45%`, ...
String describeSpeechModelState(ModelAvailability a) => switch (a.kind) {
      ModelAvailabilityKind.ready => 'Ready',
      ModelAvailabilityKind.downloading => 'Downloading ${(a.fraction * 100).floor()}%',
      ModelAvailabilityKind.paused => describeModelReason(a.reason, failed: false),
      ModelAvailabilityKind.verifying => 'Checking file…',
      ModelAvailabilityKind.failed => 'Needs attention',
      ModelAvailabilityKind.absent => 'Not downloaded',
    };
