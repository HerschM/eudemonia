import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';

/// In-memory stand-in for the native downloader. Like the real channel it only answers once
/// the controller has registered its change listener, so use before that throws.
class FakeModelFilesChannel implements ModelFilesChannel {
  VoidCallback? _onChanged;

  DeviceInfo device = const DeviceInfo(totalRamMb: 7600, freeStorageBytes: 50000000000);
  final Map<String, ModelFileStatus> files = {};
  final List<Map<String, Object?>> downloads = [];
  final List<String> cancels = [];
  final List<String> deletes = [];
  int statusCalls = 0;
  int deviceInfoCalls = 0;

  /// When true a download is refused, as native does for lack of space.
  bool refuseDownloads = false;

  bool get hasListener => _onChanged != null;

  void _requireInitialised() {
    if (!hasListener) throw StateError('ModelFilesChannel used before the change listener was set');
  }

  @override
  void setChangedListener(VoidCallback onChanged) => _onChanged = onChanged;

  @override
  void clearChangedListener() => _onChanged = null;

  /// Native finished a transfer or a verification.
  void emitChanged() {
    _requireInitialised();
    _onChanged!();
  }

  /// Sets what native reports for [relativePath].
  void setFile(String relativePath, ModelFileState state,
      {int downloaded = 0, int total = 0, String? reason}) {
    files[relativePath] = ModelFileStatus(
        relativePath: relativePath, state: state, downloadedBytes: downloaded, totalBytes: total, reason: reason);
  }

  /// Every file of [spec] in the same [state] (a finished file reports its full size).
  void setModel(ModelSpec spec, ModelFileState state, {String? reason}) {
    for (final f in spec.files) {
      setFile(f.relativePath, state,
          downloaded: state == ModelFileState.ready ? f.sizeBytes : 0, total: f.sizeBytes, reason: reason);
    }
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    _requireInitialised();
    deviceInfoCalls++;
    return device;
  }

  @override
  Future<List<ModelFileStatus>> status(List<ModelFileQuery> queries) async {
    _requireInitialised();
    statusCalls++;
    return [for (final q in queries) files[q.relativePath] ?? ModelFileStatus.absent(q.relativePath)];
  }

  @override
  Future<bool> download({
    required String relativePath,
    required String url,
    required String sha256,
    required int sizeBytes,
    required String title,
    required bool wifiOnly,
  }) async {
    _requireInitialised();
    downloads.add({'relativePath': relativePath, 'url': url, 'title': title, 'wifiOnly': wifiOnly});
    if (refuseDownloads) {
      setFile(relativePath, ModelFileState.failed, total: sizeBytes, reason: 'insufficient_space');
      return false;
    }
    setFile(relativePath, ModelFileState.queued, total: sizeBytes);
    return true;
  }

  @override
  Future<void> cancel(String relativePath) async {
    _requireInitialised();
    cancels.add(relativePath);
    setFile(relativePath, ModelFileState.failed, reason: 'cancelled');
  }

  @override
  Future<void> delete(String relativePath) async {
    _requireInitialised();
    deletes.add(relativePath);
    files.remove(relativePath);
  }
}

class InMemoryModelSettingsStore implements ModelSettingsStore {
  ModelSettings stored;
  int saves = 0;

  InMemoryModelSettingsStore({this.stored = const ModelSettings()});

  @override
  Future<ModelSettings> load() async => stored.copyWith(loaded: true);

  @override
  Future<void> save(ModelSettings settings) async {
    saves++;
    stored = settings;
  }
}
