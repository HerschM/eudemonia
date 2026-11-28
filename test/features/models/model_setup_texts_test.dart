import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_texts.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatModelBytes', () {
    test('decimal units, whole MB and one decimal GB', () {
      // User decision 2026-11-28 (v3 removed; v2 is the speech model): was parakeetV3 -> '671 MB'.
      expect(formatModelBytes(ModelCatalogue.parakeetV2.totalBytes), '661 MB');
      expect(formatModelBytes(ModelCatalogue.qwen3_4b.totalBytes), '2.5 GB');
      expect(formatModelBytes(ModelCatalogue.qwen3_1_7b.totalBytes), '1.1 GB');
      expect(formatModelBytes(312000000), '312 MB');
      expect(formatModelBytes(0), '0 MB');
      expect(formatModelBytes(100), '1 MB');
    });

    test('a value that rounds to 1000 MB is shown in GB', () {
      expect(formatModelBytes(999600000), '1.0 GB');
    });
  });

  group('describeModelReason', () {
    test('paused reasons', () {
      expect(describeModelReason('waiting_for_wifi', failed: false), 'Waiting for Wi-Fi');
      expect(describeModelReason('waiting_for_network', failed: false), 'Waiting for a connection');
      expect(describeModelReason('waiting_to_retry', failed: false), 'Retrying soon');
      expect(describeModelReason('unknown', failed: false), 'Paused');
      expect(describeModelReason(null, failed: false), 'Paused');
    });

    test('failed reasons', () {
      expect(describeModelReason('checksum', failed: true), 'The file was damaged in transfer. Try again.');
      expect(describeModelReason('insufficient_space', failed: true), 'Not enough free storage on this phone.');
      expect(describeModelReason('http_404', failed: true),
          'The download server answered with an error (404). Try again later.');
      expect(describeModelReason('cancelled', failed: true), 'Download cancelled.');
      for (final other in ['file_error', 'unknown', 'http_', 'http_abc', null]) {
        expect(describeModelReason(other, failed: true), 'The download did not finish. Try again.', reason: '$other');
      }
    });
  });

  group('ModelSetupData', () {
    ModelSetupData build({int? ram = 7600, String? selected, String? selectedSpeech}) => ModelSetupData.build(
          loading: false,
          totalRamMb: ram,
          availabilityOf: (_) => ModelAvailability.absent,
          selectedSpeechModelId: selectedSpeech,
          selectedLanguageModelId: selected,
          wifiOnly: true,
        );

    test('a big enough phone lists both models with no warning', () {
      final data = build();
      expect(data.languageModels.map((c) => c.spec.id), ['qwen3-4b', 'qwen3-1.7b']);
      expect(data.languageModels.every((c) => c.fits), isTrue);
      expect(data.noModelFitsMessage, isNull);
    });

    test('a model the phone cannot hold is greyed with both memory figures', () {
      final data = build(ram: 5600);
      final big = data.languageModels.firstWhere((c) => c.spec.id == 'qwen3-4b');
      expect(big.fits, isFalse);
      expect(big.doesNotFitMessage, 'Needs a phone with 8 GB of memory. This phone has 6 GB.');
      expect(data.languageModels.firstWhere((c) => c.spec.id == 'qwen3-1.7b').fits, isTrue);
      expect(data.noModelFitsMessage, isNull);
    });

    test('when nothing fits the message names the smallest requirement', () {
      expect(build(ram: 3600).noModelFitsMessage,
          'Synthesis needs a phone with at least 6 GB of memory. Capture and transcription work on this phone.');
    });

    test('unknown memory counts as not fitting and omits the phone figure', () {
      final data = build(ram: null);
      expect(data.languageModels.every((c) => !c.fits), isTrue);
      expect(data.languageModels.first.doesNotFitMessage, 'Needs a phone with 8 GB of memory.');
      expect(data.languageModels.last.doesNotFitMessage, 'Needs a phone with 6 GB of memory.');
      expect(data.noModelFitsMessage, isNotNull);
    });

    // User decision 2026-11-28 (v3 removed; v2 is the only speech model). Was: both v3 and v2 listed, either one flaggable.
    test('the only speech model is listed, flagged when it is the chosen one', () {
      expect(build().speechModels.map((c) => c.spec.id), ['parakeet-tdt-0.6b-v2-int8']);
      expect(build().speechModels.every((c) => c.fits && !c.selected), isTrue);
      expect(build(selectedSpeech: 'parakeet-tdt-0.6b-v2-int8').speechModels.map((c) => c.selected), [true]);
      expect(build(selectedSpeech: 'parakeet-tdt-0.6b-v3-int8').speechModels.map((c) => c.selected), [false],
          reason: 'a stored choice naming the removed model flags nothing');
    });

    test('the selected model is flagged', () {
      expect(build(selected: 'qwen3-4b').languageModels.map((c) => c.selected), [true, false]);
      expect(build(selected: 'qwen3-1.7b').languageModels.map((c) => c.selected), [false, true]);
      expect(build().languageModels.any((c) => c.selected), isFalse);
    });
  });

  test('describeSpeechModelState', () {
    ModelAvailability a(ModelAvailabilityKind k, {int done = 0, String? reason}) =>
        ModelAvailability(k, downloadedBytes: done, totalBytes: 100, reason: reason);
    expect(describeSpeechModelState(a(ModelAvailabilityKind.ready)), 'Ready');
    expect(describeSpeechModelState(a(ModelAvailabilityKind.downloading, done: 45)), 'Downloading 45%');
    expect(describeSpeechModelState(a(ModelAvailabilityKind.paused, reason: 'waiting_for_wifi')), 'Waiting for Wi-Fi');
    expect(describeSpeechModelState(a(ModelAvailabilityKind.verifying)), 'Checking file…');
    expect(describeSpeechModelState(a(ModelAvailabilityKind.failed)), 'Needs attention');
    expect(describeSpeechModelState(ModelAvailability.absent), 'Not downloaded');
  });

  group('describeSpeechModelSummary', () {
    ModelAvailability ready(ModelSpec m) =>
        ModelAvailability(ModelAvailabilityKind.ready, downloadedBytes: m.totalBytes, totalBytes: m.totalBytes);
    const downloading = ModelAvailability(ModelAvailabilityKind.downloading, downloadedBytes: 45, totalBytes: 100);

    test('the chosen model is named once it is ready', () {
      expect(
          describeSpeechModelSummary(
              selected: ModelCatalogue.parakeetV2, availability: ready(ModelCatalogue.parakeetV2), anyDownloaded: true),
          'Parakeet v2 (English)');
    });

    test('a chosen model that is not ready shows its state', () {
      expect(
          describeSpeechModelSummary(
              selected: ModelCatalogue.parakeetV2, availability: downloading, anyDownloaded: false),
          'Downloading 45%');
      expect(
          describeSpeechModelSummary(
              selected: ModelCatalogue.parakeetV2, availability: ModelAvailability.absent, anyDownloaded: false),
          'Not downloaded');
    });

    test('none chosen: Not downloaded when nothing is, Not chosen when a model is, else the transfer', () {
      expect(describeSpeechModelSummary(selected: null, availability: ModelAvailability.absent, anyDownloaded: false),
          'Not downloaded');
      expect(describeSpeechModelSummary(selected: null, availability: ModelAvailability.absent, anyDownloaded: true),
          'Not chosen');
      expect(describeSpeechModelSummary(selected: null, availability: downloading, anyDownloaded: true),
          'Downloading 45%');
    });
  });

  test('a transfer the system has not started reads as waiting, for Wi-Fi when Wi-Fi only is on', () {
    expect(describeModelReason('queued', failed: false), 'Waiting to start');
    expect(describeModelReason('queued_wifi_only', failed: false), 'Waiting for Wi-Fi');
    ModelSetupData data({required bool wifiOnly}) => ModelSetupData.build(
          loading: false,
          totalRamMb: 7600,
          availabilityOf: (_) => const ModelAvailability(ModelAvailabilityKind.paused, totalBytes: 10, reason: 'queued'),
          selectedSpeechModelId: null,
          selectedLanguageModelId: null,
          wifiOnly: wifiOnly,
        );
    for (final card in data(wifiOnly: true).speechModels) {
      expect(card.availability.reason, 'queued_wifi_only');
    }
    for (final card in data(wifiOnly: false).speechModels) {
      expect(card.availability.reason, 'queued');
    }
  });
}
