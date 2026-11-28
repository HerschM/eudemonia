import 'dart:io';
import 'dart:isolate';

import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records its release in a file inside the folder it was loaded from.
class _MarkerEngine implements SttEngine {
  String? _dir;

  @override
  void load(String modelDir) => _dir = modelDir;

  @override
  SttTranscript transcribe(String audioFilePath) => const SttTranscript(text: '', audioDuration: Duration.zero);

  @override
  void dispose() => File('$_dir/released').writeAsStringSync('released');
}

SttEngine _createMarkerEngine() => _MarkerEngine();

/// Stands for the app's main isolate: loads the speech model, then goes away without unloading
/// it, as happens when the Flutter engine is destroyed while the capture service keeps the process.
Future<void> _ownerThatLeaves(List<Object> args) async {
  final service = STTService(engineFactory: _createMarkerEngine);
  await service.initialize(args[0] as String);
  (args[1] as SendPort).send('loaded');
  Isolate.exit();
}

void main() {
  test('the worker frees the speech model when the isolate that owns it exits without unloading', () async {
    final dir = Directory.systemTemp.createTempSync('stt_owner_exit');
    addTearDown(() => dir.deleteSync(recursive: true));
    final loaded = ReceivePort();
    addTearDown(loaded.close);

    await Isolate.spawn(_ownerThatLeaves, [dir.path, loaded.sendPort]);
    expect(await loaded.first, 'loaded');

    final released = File('${dir.path}/released');
    for (var i = 0; i < 100 && !released.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(released.existsSync(), isTrue, reason: 'the worker was told its owner is gone and released the model');
  });

  test('an explicit unload still releases the model exactly once', () async {
    final dir = Directory.systemTemp.createTempSync('stt_owner_dispose');
    addTearDown(() => dir.deleteSync(recursive: true));
    final service = STTService(engineFactory: _createMarkerEngine);
    await service.initialize(dir.path);
    service.dispose();
    // A second load waits for the first worker to finish its release.
    await service.initialize(dir.path);
    expect(File('${dir.path}/released').existsSync(), isTrue);
    service.dispose();
  });
}
