import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:eudemonia/features/ai_processing/native/native_release.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

// The C library's unlink and rmdir stand in for a native free function: their effect on the
// file system shows whether, and in which order, a callback ran. Their int result is ignored,
// as a NativeFinalizer callback returns void.
final DynamicLibrary _libc = DynamicLibrary.process();

class _Owner implements Finalizable {}

/// Owners stay reachable until the isolate ends, so only the isolate shutdown runs callbacks.
final List<_Owner> _owners = [];

/// The path strings stay allocated: a callback still reads them during the isolate shutdown.
Pointer<Void> _path(String path) => path.toNativeUtf8().cast();

/// [message]: reply port, then the file path, then whether to release it explicitly, then
/// whether to wait for a kill instead of exiting.
void _unlinkWorker(List<Object> message) {
  final reply = message[0] as SendPort;
  final release = NativeRelease(_libc.lookup<NativeFinalizerFunction>('unlink'));
  final owner = _Owner();
  _owners.add(owner);
  release.attach(owner, _path(message[1] as String));
  if (message[2] as bool) release.release(owner, () {});
  _endWorker(reply, waitForKill: message[3] as bool);
}

/// [message]: reply port, then a file inside a directory, then that directory, then whether to
/// wait for a kill. The file's finalizer is created first, so it must run first: rmdir only
/// removes an empty directory.
void _orderWorker(List<Object> message) {
  final reply = message[0] as SendPort;
  final unlink = NativeRelease(_libc.lookup<NativeFinalizerFunction>('unlink'));
  final rmdir = NativeRelease(_libc.lookup<NativeFinalizerFunction>('rmdir'));
  final owner = _Owner();
  _owners.add(owner);
  // Attached in the reverse order: the order of the finalizers decides, not that of the handles.
  rmdir.attach(owner, _path(message[2] as String));
  unlink.attach(owner, _path(message[1] as String));
  _endWorker(reply, waitForKill: message[3] as bool);
}

void _endWorker(SendPort reply, {required bool waitForKill}) {
  if (!waitForKill) {
    reply.send('ready');
    return;
  }
  // An open port keeps the isolate alive until it is killed.
  final port = ReceivePort();
  reply.send('ready');
  port.listen((_) {});
}

/// Runs [entry] in a new isolate and waits until it has ended, killing it when [kill].
Future<void> _runWorker(void Function(List<Object>) entry, List<Object> args, {required bool kill}) async {
  final replies = ReceivePort();
  final exit = ReceivePort();
  final ready = Completer<void>();
  replies.listen((_) => ready.complete());
  final isolate = await Isolate.spawn(entry, [replies.sendPort, ...args, kill], onExit: exit.sendPort);
  await ready.future;
  if (kill) isolate.kill(priority: Isolate.immediate);
  await exit.first.timeout(const Duration(seconds: 10));
  replies.close();
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('native_release_'));
  tearDown(() => temp.deleteSync(recursive: true));

  File newFile(String name) => File('${temp.path}/$name')..writeAsStringSync('x');

  group('NativeRelease', skip: Platform.isWindows ? 'Needs the POSIX unlink and rmdir.' : null, () {
    for (final kill in [false, true]) {
      final ending = kill ? 'is killed' : 'exits';
      test('frees an attached handle when its isolate $ending without a release', () async {
        final file = newFile('handle');
        await _runWorker(_unlinkWorker, [file.path, false], kill: kill);
        expect(file.existsSync(), isFalse);
      });

      test('never frees a released handle again when its isolate $ending', () async {
        final file = newFile('handle');
        await _runWorker(_unlinkWorker, [file.path, true], kill: kill);
        expect(file.existsSync(), isTrue);
      });

      test('runs the finalizers in the order they were created when the isolate $ending', () async {
        final dir = Directory('${temp.path}/dir')..createSync();
        final file = File('${dir.path}/inner')..writeAsStringSync('x');
        await _runWorker(_orderWorker, [file.path, dir.path], kill: kill);
        expect(file.existsSync(), isFalse);
        expect(dir.existsSync(), isFalse, reason: 'rmdir ran before unlink');
      });
    }

    test('release calls the free function once, in the calling isolate', () {
      final release = NativeRelease(_libc.lookup<NativeFinalizerFunction>('unlink'));
      final owner = _Owner();
      final file = newFile('handle');
      final path = _path(file.path);
      release.attach(owner, path);
      var freed = 0;
      release.release(owner, () => freed++);
      expect(freed, 1);
      expect(file.existsSync(), isTrue);
      malloc.free(path);
    });
  });
}
