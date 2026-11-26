import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ModelFileState { absent, queued, running, paused, verifying, ready, failed }

/// One file the app asks native code about: where it must end up and how big it must be.
class ModelFileQuery {
  final String relativePath;
  final int sizeBytes;

  const ModelFileQuery({required this.relativePath, required this.sizeBytes});
}

/// What native code reports for one file. [reason] explains a paused or failed state
/// (`waiting_for_wifi`, `checksum`, `http_404` and so on) and is `null` otherwise.
class ModelFileStatus {
  final String relativePath;
  final ModelFileState state;
  final int downloadedBytes;
  final int totalBytes;
  final String? reason;

  const ModelFileStatus({
    required this.relativePath,
    required this.state,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.reason,
  });

  const ModelFileStatus.absent(String relativePath) : this(relativePath: relativePath, state: ModelFileState.absent);

  /// `null` for a malformed entry, so one bad row cannot hide the others.
  static ModelFileStatus? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['relativePath'];
    if (path is! String || path.isEmpty) return null;
    final stateName = raw['state'];
    final state = ModelFileState.values.where((s) => s.name == stateName).firstOrNull ?? ModelFileState.absent;
    final downloaded = raw['downloadedBytes'];
    final total = raw['totalBytes'];
    final reason = raw['reason'];
    return ModelFileStatus(
      relativePath: path,
      state: state,
      downloadedBytes: downloaded is num ? downloaded.toInt() : 0,
      totalBytes: total is num ? total.toInt() : 0,
      reason: reason is String && reason.isNotEmpty ? reason : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModelFileStatus &&
      other.relativePath == relativePath &&
      other.state == state &&
      other.downloadedBytes == downloadedBytes &&
      other.totalBytes == totalBytes &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(relativePath, state, downloadedBytes, totalBytes, reason);

  @override
  String toString() => 'ModelFileStatus($relativePath, ${state.name}, $downloadedBytes/$totalBytes, $reason)';
}

/// What the phone can offer a download. A value is `null` while it is unknown.
class DeviceInfo {
  final int? totalRamMb;
  final int? freeStorageBytes;

  const DeviceInfo({this.totalRamMb, this.freeStorageBytes});

  static const DeviceInfo unknown = DeviceInfo();

  factory DeviceInfo.fromMap(Object? map) {
    if (map is! Map) return unknown;
    final ram = map['totalRamMb'];
    final storage = map['freeStorageBytes'];
    return DeviceInfo(
      totalRamMb: ram is num ? ram.toInt() : null,
      freeStorageBytes: storage is num ? storage.toInt() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo && other.totalRamMb == totalRamMb && other.freeStorageBytes == freeStorageBytes;

  @override
  int get hashCode => Object.hash(totalRamMb, freeStorageBytes);
}

/// Typed wrapper over the `com.eudemonia/model_files` channel. Native code downloads, verifies
/// and stores the model files; Dart only asks for state and issues commands.
///
/// A missing platform implementation (tests, non-Android hosts) behaves as: device unknown,
/// every file absent, commands do nothing. Callers never see an exception.
class ModelFilesChannel {
  static const MethodChannel _defaultChannel = MethodChannel('com.eudemonia/model_files');

  final MethodChannel _channel;

  ModelFilesChannel({MethodChannel? channel}) : _channel = channel ?? _defaultChannel;

  /// Calls [onChanged] whenever a transfer or a verification finishes. Replaces any listener.
  void setChangedListener(VoidCallback onChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onChanged') onChanged();
      return null;
    });
  }

  void clearChangedListener() => _channel.setMethodCallHandler(null);

  Future<DeviceInfo> getDeviceInfo() async {
    try {
      return DeviceInfo.fromMap(await _channel.invokeMethod<Object?>('getDeviceInfo'));
    } on MissingPluginException {
      return DeviceInfo.unknown;
    } on PlatformException {
      return DeviceInfo.unknown;
    }
  }

  /// One status per entry of [files], in the same order.
  Future<List<ModelFileStatus>> status(List<ModelFileQuery> files) async {
    final absent = [for (final f in files) ModelFileStatus.absent(f.relativePath)];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('status', {
        'files': [
          for (final f in files) {'relativePath': f.relativePath, 'sizeBytes': f.sizeBytes},
        ],
      });
      final byPath = <String, ModelFileStatus>{};
      for (final entry in raw ?? const <Object?>[]) {
        final parsed = ModelFileStatus.tryParse(entry);
        if (parsed != null) byPath[parsed.relativePath] = parsed;
      }
      return [for (final f in files) byPath[f.relativePath] ?? ModelFileStatus.absent(f.relativePath)];
    } on MissingPluginException {
      return absent;
    } on PlatformException {
      return absent;
    }
  }

  /// `false` when native refused to start (not enough free space) or cannot download.
  Future<bool> download({
    required String relativePath,
    required String url,
    required String sha256,
    required int sizeBytes,
    required String title,
    required bool wifiOnly,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('download', {
            'relativePath': relativePath,
            'url': url,
            'sha256': sha256,
            'sizeBytes': sizeBytes,
            'title': title,
            'wifiOnly': wifiOnly,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancel(String relativePath) => _fileCall('cancel', relativePath);

  Future<void> delete(String relativePath) => _fileCall('delete', relativePath);

  Future<void> _fileCall(String method, String relativePath) async {
    try {
      await _channel.invokeMethod<void>(method, {'relativePath': relativePath});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

final modelFilesChannelProvider = Provider<ModelFilesChannel>((ref) => ModelFilesChannel());
