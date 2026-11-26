/// Where one model stands in its download. Pure Dart.
library;

import 'package:flutter/foundation.dart' show immutable;

enum ModelAvailabilityKind { absent, downloading, paused, verifying, ready, failed }

/// Where one model stands, summed over all of its files.
@immutable
class ModelAvailability {
  final ModelAvailabilityKind kind;
  final int downloadedBytes;
  final int totalBytes;

  /// Why a paused or failed model is in that state (`waiting_for_wifi`, `checksum`, ...).
  final String? reason;

  const ModelAvailability(this.kind, {this.downloadedBytes = 0, this.totalBytes = 0, this.reason});

  static const ModelAvailability absent = ModelAvailability(ModelAvailabilityKind.absent);

  bool get isReady => kind == ModelAvailabilityKind.ready;

  /// A transfer or a check is under way or waiting to resume.
  bool get isBusy =>
      kind == ModelAvailabilityKind.downloading ||
      kind == ModelAvailabilityKind.paused ||
      kind == ModelAvailabilityKind.verifying;

  /// 0..1 share of the bytes that arrived.
  double get fraction => totalBytes <= 0 ? 0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is ModelAvailability &&
      other.kind == kind &&
      other.downloadedBytes == downloadedBytes &&
      other.totalBytes == totalBytes &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, downloadedBytes, totalBytes, reason);

  @override
  String toString() => 'ModelAvailability(${kind.name}, $downloadedBytes/$totalBytes, $reason)';
}
