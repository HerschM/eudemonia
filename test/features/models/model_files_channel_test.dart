import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.eudemonia/model_files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late ModelFilesChannel native;

  void mockNative(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  const queries = [
    ModelFileQuery(relativePath: 'a.bin', sizeBytes: 10),
    ModelFileQuery(relativePath: 'b.bin', sizeBytes: 20),
  ];

  setUp(() {
    calls = [];
    native = ModelFilesChannel();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('decoding', () {
    test('getDeviceInfo parses memory and storage', () async {
      mockNative((_) async => {'totalRamMb': 7600, 'freeStorageBytes': 12345678901});
      expect(await native.getDeviceInfo(), const DeviceInfo(totalRamMb: 7600, freeStorageBytes: 12345678901));
    });

    test('getDeviceInfo with a malformed reply is unknown', () async {
      mockNative((_) async => 'garbage');
      expect(await native.getDeviceInfo(), DeviceInfo.unknown);
    });

    test('status sends the files and decodes every field in order', () async {
      mockNative((_) async => [
            {'relativePath': 'a.bin', 'state': 'running', 'downloadedBytes': 4, 'totalBytes': 10, 'reason': null},
            {'relativePath': 'b.bin', 'state': 'paused', 'downloadedBytes': 1, 'totalBytes': 20, 'reason': 'waiting_for_wifi'},
          ]);

      final statuses = await native.status(queries);

      expect(statuses, const [
        ModelFileStatus(relativePath: 'a.bin', state: ModelFileState.running, downloadedBytes: 4, totalBytes: 10),
        ModelFileStatus(
          relativePath: 'b.bin',
          state: ModelFileState.paused,
          downloadedBytes: 1,
          totalBytes: 20,
          reason: 'waiting_for_wifi',
        ),
      ]);
      expect(calls.single.method, 'status');
      expect(calls.single.arguments, {
        'files': [
          {'relativePath': 'a.bin', 'sizeBytes': 10},
          {'relativePath': 'b.bin', 'sizeBytes': 20},
        ],
      });
    });

    test('status treats a missing, malformed or unknown-state entry as absent', () async {
      mockNative((_) async => [
            'garbage',
            {'relativePath': 'b.bin', 'state': 'from-the-future'},
          ]);

      final statuses = await native.status(queries);

      expect(statuses.map((s) => (s.relativePath, s.state)),
          [('a.bin', ModelFileState.absent), ('b.bin', ModelFileState.absent)]);
    });

    test('download passes every argument and returns native answer', () async {
      mockNative((_) async => true);
      final started = await native.download(
        relativePath: 'a.bin',
        url: 'https://x/a',
        sha256: 'ab',
        sizeBytes: 10,
        title: 'Speech model',
        wifiOnly: false,
      );
      expect(started, isTrue);
      expect(calls.single.method, 'download');
      expect(calls.single.arguments, {
        'relativePath': 'a.bin',
        'url': 'https://x/a',
        'sha256': 'ab',
        'sizeBytes': 10,
        'title': 'Speech model',
        'wifiOnly': false,
      });
    });

    test('cancel and delete pass the relative path', () async {
      mockNative((_) async => null);
      await native.cancel('a.bin');
      await native.delete('b.bin');
      expect(calls.map((c) => c.method), ['cancel', 'delete']);
      expect(calls[0].arguments, {'relativePath': 'a.bin'});
      expect(calls[1].arguments, {'relativePath': 'b.bin'});
    });
  });

  group('without a platform implementation', () {
    test('device unknown, every file absent, commands do nothing', () async {
      expect(await native.getDeviceInfo(), DeviceInfo.unknown);
      final statuses = await native.status(queries);
      expect(statuses.map((s) => (s.relativePath, s.state)),
          [('a.bin', ModelFileState.absent), ('b.bin', ModelFileState.absent)]);
      expect(
        await native.download(
            relativePath: 'a.bin', url: 'u', sha256: 's', sizeBytes: 1, title: 't', wifiOnly: true),
        isFalse,
      );
      await native.cancel('a.bin');
      await native.delete('a.bin');
    });

    test('a PlatformException never reaches the caller', () async {
      mockNative((_) async => throw PlatformException(code: 'MODEL_FILES_ERROR'));
      expect(await native.getDeviceInfo(), DeviceInfo.unknown);
      expect((await native.status(queries)).every((s) => s.state == ModelFileState.absent), isTrue);
      await native.cancel('a.bin');
      await native.delete('a.bin');
    });
  });

  group('onChanged', () {
    test('calls the listener until it is cleared', () async {
      var changes = 0;
      native.setChangedListener(() => changes++);
      Future<void> fromNative() => messenger.handlePlatformMessage(
          channel.name, const StandardMethodCodec().encodeMethodCall(const MethodCall('onChanged')), (_) {});

      await fromNative();
      expect(changes, 1);
      native.clearChangedListener();
      await fromNative();
      expect(changes, 1);
    });
  });
}
