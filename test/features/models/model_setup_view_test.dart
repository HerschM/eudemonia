import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view_data.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _speech = ModelCatalogue.parakeetV3;
const _speechV2 = ModelCatalogue.parakeetV2;
const _big = ModelCatalogue.qwen3_4b;
const _small = ModelCatalogue.qwen3_1_7b;

ModelAvailability _ready(ModelSpec m) =>
    ModelAvailability(ModelAvailabilityKind.ready, downloadedBytes: m.totalBytes, totalBytes: m.totalBytes);

ModelAvailability _downloading(ModelSpec m, int done) =>
    ModelAvailability(ModelAvailabilityKind.downloading, downloadedBytes: done, totalBytes: m.totalBytes);

void main() {
  late List<String> calls;
  late bool? wifiOnlyChange;

  setUp(() {
    calls = [];
    wifiOnlyChange = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    Map<String, ModelAvailability> availability = const {},
    int? ram = 7600,
    String? selected,
    String? selectedSpeech,
    bool loading = false,
    bool wifiOnly = true,
  }) async {
    tester.view.physicalSize = const Size(360 * 2, 1800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final data = ModelSetupData.build(
      loading: loading,
      totalRamMb: ram,
      availabilityOf: (id) => availability[id] ?? ModelAvailability.absent,
      selectedSpeechModelId: selectedSpeech,
      selectedLanguageModelId: selected,
      wifiOnly: wifiOnly,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModelSetupView(
          data: data,
          onDownload: (id) => calls.add('download:$id'),
          onCancel: (id) => calls.add('cancel:$id'),
          onDelete: (id) => calls.add('delete:$id'),
          onSelect: (id) => calls.add('select:$id'),
          onWifiOnlyChanged: (v) => wifiOnlyChange = v,
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no overflow at 360 dp');
  }

  testWidgets('nothing downloaded: every model offers Download with its size', (tester) async {
    await pump(tester);

    expect(find.text('Eudemonia runs on this phone. It needs two model files, downloaded once.'), findsOneWidget);
    expect(find.text('Speech model'), findsOneWidget);
    expect(find.text('Turns your recordings into text. Choose one.'), findsOneWidget);
    expect(find.text('Parakeet v3 (25 languages)'), findsOneWidget);
    expect(find.text('25 European languages. Good for mixed-language speakers.'), findsOneWidget);
    expect(find.text('671 MB download'), findsOneWidget);
    expect(find.text('Parakeet v2 (English)'), findsOneWidget);
    expect(find.text('English only. The most accurate for English.'), findsOneWidget);
    expect(find.text('661 MB download'), findsOneWidget);
    expect(find.text('Writing model'), findsOneWidget);
    expect(find.text('Used by Synthesis to turn your thoughts into notes. Choose one.'), findsOneWidget);
    expect(find.text('Qwen3 4B'), findsOneWidget);
    expect(find.text('Best notes. Well organised and keeps the details.'), findsOneWidget);
    expect(find.text('2.5 GB download · Uses about 3.7 GB of memory while writing'), findsOneWidget);
    expect(find.text('Qwen3 1.7B'), findsOneWidget);
    expect(
        find.text('Smaller and faster, for phones with 6 GB of memory. Notes are less tidy and can miss a detail now and then.'),
        findsOneWidget);
    expect(find.text('Testing'), findsNothing);
    expect(find.text('Download'), findsNWidgets(4));

    await tester.tap(find.byKey(const Key('model_download_parakeet-tdt-0.6b-v3-int8')));
    await tester.tap(find.byKey(const Key('model_download_parakeet-tdt-0.6b-v2-int8')));
    await tester.tap(find.byKey(const Key('model_download_qwen3-4b')));
    expect(calls, ['download:parakeet-tdt-0.6b-v3-int8', 'download:parakeet-tdt-0.6b-v2-int8', 'download:qwen3-4b']);
  });

  testWidgets('downloading shows a thin bar, the bytes and Cancel', (tester) async {
    await pump(tester, availability: {_speech.id: _downloading(_speech, 312000000)});

    final bar = tester.widget<LinearProgressIndicator>(find.byKey(Key('model_progress_${_speech.id}')));
    expect(bar.value, closeTo(312000000 / _speech.totalBytes, 1e-9));
    expect(bar.minHeight, lessThanOrEqualTo(4));
    expect(find.text('312 MB of 671 MB'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(Key('model_cancel_${_speech.id}')));
    expect(calls, ['cancel:${_speech.id}']);
  });

  testWidgets('paused says why', (tester) async {
    await pump(tester, availability: {
      _speech.id: ModelAvailability(ModelAvailabilityKind.paused,
          downloadedBytes: 100000000, totalBytes: _speech.totalBytes, reason: 'waiting_for_wifi'),
    });
    expect(find.text('Waiting for Wi-Fi · 100 MB of 671 MB'), findsOneWidget);
    expect(find.byKey(Key('model_cancel_${_speech.id}')), findsOneWidget);
  });

  testWidgets('verifying shows Checking file… with the dots loader', (tester) async {
    await pump(tester, availability: {
      _speech.id: ModelAvailability(ModelAvailabilityKind.verifying,
          downloadedBytes: _speech.totalBytes, totalBytes: _speech.totalBytes),
    });
    expect(find.text('Checking file…'), findsOneWidget);
    expect(find.byType(PulseDotsLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('speech ready: Ready with Delete in the overflow menu', (tester) async {
    await pump(tester, availability: {_speech.id: _ready(_speech)});

    expect(find.byKey(Key('model_ready_${_speech.id}')), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(Key('model_menu_${_speech.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('model_delete_${_speech.id}')));
    await tester.pumpAndSettle();
    expect(calls, ['delete:${_speech.id}']);
  });

  testWidgets('the overflow menu sits at the card\'s right edge, centred with the name', (tester) async {
    await pump(tester, availability: {
      _big.id: _ready(_big),
      _small.id: _ready(_small),
      _speech.id: _ready(_speech),
      _speechV2.id: _ready(_speechV2),
    });

    for (final spec in [_speech, _speechV2, _big, _small]) {
      final card = tester.getRect(find.byKey(Key('model_card_${spec.id}')));
      final menu = tester.getRect(find.byKey(Key('model_menu_${spec.id}')));
      expect(menu.right, closeTo(card.right - 14, 2), reason: '${spec.id}: menu at the right padding edge');

      final name = tester.getRect(find.text(spec.displayName));
      expect(menu.center.dy, closeTo(name.center.dy, 2), reason: '${spec.id}: centred with the name');
      expect(name.left, closeTo(card.left + 14, 2), reason: '${spec.id}: name at the left');
    }
  });

  testWidgets('failed shows the reason and Try again', (tester) async {
    await pump(tester, availability: {
      _speech.id: const ModelAvailability(ModelAvailabilityKind.failed, reason: 'checksum', totalBytes: 1),
      _big.id: const ModelAvailability(ModelAvailabilityKind.failed, reason: 'http_503', totalBytes: 1),
    });

    expect(find.text('The file was damaged in transfer. Try again.'), findsOneWidget);
    expect(find.text('The download server answered with an error (503). Try again later.'), findsOneWidget);
    await tester.tap(find.byKey(Key('model_retry_${_speech.id}')));
    expect(calls, ['download:${_speech.id}']);
  });

  testWidgets('a ready language model can be chosen; the chosen one reads In use', (tester) async {
    await pump(tester, availability: {_big.id: _ready(_big), _small.id: _ready(_small)});

    expect(find.text('Use this model'), findsNWidgets(2));
    await tester.tap(find.byKey(Key('model_use_${_small.id}')));
    expect(calls, ['select:${_small.id}']);

    await pump(tester,
        availability: {_big.id: _ready(_big), _small.id: _ready(_small)}, selected: _big.id);
    expect(find.text('In use'), findsOneWidget);
    expect(find.byKey(Key('model_use_${_big.id}')), findsNothing);
    expect(find.byKey(Key('model_use_${_small.id}')), findsOneWidget);
  });

  testWidgets('both speech models ready, none in use: each can be chosen', (tester) async {
    await pump(tester, availability: {_speech.id: _ready(_speech), _speechV2.id: _ready(_speechV2)});

    expect(find.text('In use'), findsNothing);
    expect(find.byKey(Key('model_use_${_speech.id}')), findsOneWidget);
    expect(find.byKey(Key('model_use_${_speechV2.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('model_use_${_speechV2.id}')));
    expect(calls, ['select:${_speechV2.id}']);
  });

  testWidgets('both speech models ready, one in use: it reads In use and the other offers Use this model',
      (tester) async {
    await pump(tester,
        availability: {_speech.id: _ready(_speech), _speechV2.id: _ready(_speechV2)}, selectedSpeech: _speechV2.id);

    expect(find.text('In use'), findsOneWidget);
    expect(find.byKey(Key('model_use_${_speechV2.id}')), findsNothing);
    expect(find.byKey(Key('model_use_${_speech.id}')), findsOneWidget);
    // Each card has its own Delete in its More menu.
    await tester.tap(find.byKey(Key('model_menu_${_speechV2.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('model_delete_${_speechV2.id}')));
    await tester.pumpAndSettle();
    expect(calls, ['delete:${_speechV2.id}']);
  });

  testWidgets('one speech model ready and in use, the other can still be downloaded', (tester) async {
    await pump(tester, availability: {_speech.id: _ready(_speech)}, selectedSpeech: _speech.id);

    expect(find.text('In use'), findsOneWidget);
    expect(find.byKey(Key('model_download_${_speechV2.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('model_download_${_speechV2.id}')));
    expect(calls, ['download:${_speechV2.id}']);
  });

  testWidgets('a model too large for the phone is greyed, explained and not tappable', (tester) async {
    await pump(tester, ram: 5600);

    expect(find.byKey(Key('model_greyed_${_big.id}')), findsOneWidget);
    expect(tester.widget<Opacity>(find.byKey(Key('model_greyed_${_big.id}'))).opacity, lessThan(0.6));
    expect(find.text('Needs a phone with 8 GB of memory. This phone has 6 GB.'), findsOneWidget);
    expect(find.byKey(Key('model_download_${_big.id}')), findsNothing);
    expect(find.byKey(Key('model_download_${_small.id}')), findsOneWidget, reason: 'the smaller one fits');
    expect(find.byKey(const Key('model_no_fit_message')), findsNothing);
  });

  testWidgets('no model fits: the honest message replaces the list', (tester) async {
    await pump(tester, ram: 3600);

    expect(find.text('Synthesis needs a phone with at least 6 GB of memory. Capture and transcription work on this phone.'),
        findsOneWidget);
    expect(find.text('Qwen3 4B'), findsNothing);
    expect(find.text('Qwen3 1.7B'), findsNothing);
    expect(find.byKey(Key('model_download_${_speech.id}')), findsOneWidget, reason: 'the speech model is unaffected');
  });

  testWidgets('before the phone is read a loader stands in for the writing models', (tester) async {
    await pump(tester, loading: true, ram: null);
    expect(find.byType(PulseDotsLoader), findsOneWidget);
    expect(find.byKey(const Key('model_no_fit_message')), findsNothing);
  });

  testWidgets('the Wi-Fi switch reports its change and shows its helper text', (tester) async {
    await pump(tester);
    expect(find.text('Download on Wi-Fi only'), findsOneWidget);
    expect(find.text('Models are large. Turn this off to allow mobile data.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('model_wifi_only_switch'))).value, isTrue);

    await tester.tap(find.byKey(const Key('model_wifi_only_switch')));
    expect(wifiOnlyChange, isFalse);
  });
}
