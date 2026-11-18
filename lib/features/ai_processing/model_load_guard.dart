import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Raised when model loading is withheld because the previous attempt with the
/// same files killed the app. The message is shown to the user.
class ModelLoadBlockedException implements Exception {
  const ModelLoadBlockedException();

  @override
  String toString() =>
      'Loading the AI models stopped the app last time, so automatic loading is paused. '
      'The model files may be damaged (re-run download_models.sh) or the phone ran out of memory. '
      'Tap Retry to try again.';
}

/// Breaks crash loops caused by native model loading.
///
/// A marker file is written before the native load starts and removed once it
/// returns. If the process dies inside the native runtime (abort on a bad
/// file, out-of-memory kill), the marker survives; the next launch sees it and
/// refuses to load the same files automatically instead of dying again.
///
/// The block lifts when the model files change or the user explicitly retries.
class ModelLoadGuard {
  final Future<File> Function()? _markerResolver;
  File? _marker;

  ModelLoadGuard({this._markerResolver});

  Future<File> _markerFile() async {
    final cached = _marker;
    if (cached != null) return cached;
    final resolver = _markerResolver;
    if (resolver != null) return _marker = await resolver();
    final appDir = await getApplicationDocumentsDirectory();
    return _marker = File('${appDir.path}/model_load_in_progress');
  }

  /// Marks a load of the file set identified by [signature] as started.
  /// Throws [ModelLoadBlockedException] if the previous load of these files never finished.
  Future<void> begin(String signature) async {
    final marker = await _markerFile();
    if (await marker.exists() && await marker.readAsString() == signature) {
      throw const ModelLoadBlockedException();
    }
    await marker.writeAsString(signature, flush: true);
  }

  /// Marks the load as finished: the process survived it, whether it succeeded or threw.
  Future<void> finish() async {
    final marker = await _markerFile();
    if (await marker.exists()) await marker.delete();
  }

  /// Lifts a block so the next load is attempted (explicit user retry).
  Future<void> clearBlock() => finish();
}
