import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_test_doubles.dart';

void main() {
  late FakeModelFilesChannel channel;
  late InMemoryModelSettingsStore store;

  const speech = ModelCatalogue.parakeetV2;
  const big = ModelCatalogue.qwen3_4b;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 1800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        modelFilesChannelProvider.overrideWithValue(channel),
        modelSettingsStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: ModelSetupScreen()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  setUp(() {
    channel = FakeModelFilesChannel();
    store = InMemoryModelSettingsStore();
  });

  testWidgets('shows the title and a loader until the phone has been read', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 1800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        modelFilesChannelProvider.overrideWithValue(channel),
        modelSettingsStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: ModelSetupScreen()),
    ));
    expect(find.text('On-device models'), findsOneWidget);
    expect(find.byKey(const Key('model_no_fit_message')), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(find.text('Qwen3 4B'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Download starts every speech file, then progress is polled and Ready appears', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(Key('model_download_${speech.id}')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(channel.downloads.map((d) => d['relativePath']), speech.files.map((f) => f.relativePath).toList());
    expect(channel.downloads.every((d) => d['wifiOnly'] == true), isTrue);
    expect(find.byKey(Key('model_progress_${speech.id}')), findsOneWidget);

    channel.setFile(speech.files[0].relativePath, ModelFileState.running,
        downloaded: 326141147, total: speech.files[0].sizeBytes);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    // User decision 2026-11-28 (v3 removed; v2 is 661 MB): was '326 MB of 671 MB'.
    expect(find.text('326 MB of 661 MB'), findsOneWidget);

    channel.setModel(speech, ModelFileState.ready);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    // The only downloaded speech model was chosen for the user.
    expect(find.byKey(Key('model_ready_${speech.id}')), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
    await unmount(tester);
  });

  // User decision 2026-11-28: "let's have parakeet v2 itself as default STT for now. and let's remove the option of
  // parakeet v3 since we've not tested the european languages model writing cleanup."
  // Was: "both speech models ready: choosing one stores it, the other can be deleted".
  testWidgets('the only speech model ready is chosen automatically; deleting it clears the choice', (tester) async {
    channel.setModel(speech, ModelFileState.ready);
    store.stored = const ModelSettings(setupShown: true);
    await pumpScreen(tester);

    expect(find.text('In use'), findsOneWidget);
    expect(store.stored.selectedSpeechModelId, speech.id);
    expect(find.byKey(Key('model_use_${speech.id}')), findsNothing);

    await tester.tap(find.byKey(Key('model_menu_${speech.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('model_delete_${speech.id}')));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(channel.deletes, speech.files.map((f) => f.relativePath).toList());
    expect(store.stored.selectedSpeechModelId, isNull);
    expect(find.text('In use'), findsNothing);
    expect(find.byKey(Key('model_download_${speech.id}')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Cancel stops the transfer and the card reports it', (tester) async {
    channel.setModel(speech, ModelFileState.running);
    await pumpScreen(tester);

    await tester.tap(find.byKey(Key('model_cancel_${speech.id}')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(channel.cancels, hasLength(4));
    expect(find.text('Download cancelled.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Use this model and the Wi-Fi switch change the stored choices', (tester) async {
    channel.setModel(big, ModelFileState.ready);
    store.stored = const ModelSettings(setupShown: true);
    await pumpScreen(tester);
    // The only downloaded model was chosen for the user.
    expect(find.text('In use'), findsOneWidget);

    await tester.tap(find.byKey(const Key('model_wifi_only_switch')));
    await tester.pump();
    await tester.pump();
    expect(store.stored.wifiOnly, isFalse);

    await tester.tap(find.byKey(Key('model_menu_${big.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('model_delete_${big.id}')));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(channel.deletes, [big.files.single.relativePath]);
    expect(store.stored.selectedLanguageModelId, isNull);
    expect(find.text('In use'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a phone too small shows the honest message and still offers the speech model', (tester) async {
    channel.device = const DeviceInfo(totalRamMb: 3600);
    await pumpScreen(tester);

    expect(find.byKey(const Key('model_no_fit_message')), findsOneWidget);
    expect(find.byKey(Key('model_download_${speech.id}')), findsOneWidget);
    await unmount(tester);
  });
}
