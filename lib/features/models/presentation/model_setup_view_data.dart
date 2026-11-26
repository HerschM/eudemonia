/// What the model setup screen shows, derived from plain values. Pure Dart.
library;

import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_texts.dart';

class ModelCardData {
  final ModelSpec spec;
  final ModelAvailability availability;

  /// The phone has enough memory for this model.
  final bool fits;

  /// Why the model is greyed out; `null` when it fits.
  final String? doesNotFitMessage;

  /// The model Synthesis uses.
  final bool selected;

  const ModelCardData({
    required this.spec,
    required this.availability,
    this.fits = true,
    this.doesNotFitMessage,
    this.selected = false,
  });
}

class ModelSetupData {
  /// The phone has not been read yet; the writing models are not shown until it has.
  final bool loading;
  final ModelCardData speech;
  final List<ModelCardData> languageModels;

  /// Set instead of the list when no language model fits this phone.
  final String? noModelFitsMessage;
  final bool wifiOnly;

  const ModelSetupData({
    required this.loading,
    required this.speech,
    required this.languageModels,
    required this.noModelFitsMessage,
    required this.wifiOnly,
  });

  factory ModelSetupData.build({
    required bool loading,
    required int? totalRamMb,
    required ModelAvailability Function(String modelId) availabilityOf,
    required String? selectedLanguageModelId,
    required bool wifiOnly,
    required bool includeCandidates,
  }) {
    // A transfer the system has not started yet is, with Wi-Fi only, waiting for Wi-Fi.
    ModelAvailability shown(String modelId) {
      final a = availabilityOf(modelId);
      if (wifiOnly && a.kind == ModelAvailabilityKind.paused && a.reason == 'queued') {
        return ModelAvailability(a.kind,
            downloadedBytes: a.downloadedBytes, totalBytes: a.totalBytes, reason: 'queued_wifi_only');
      }
      return a;
    }

    final visible = ModelCatalogue.visibleLanguageModels(includeCandidates: includeCandidates);
    final cards = [
      for (final spec in visible)
        ModelCardData(
          spec: spec,
          availability: shown(spec.id),
          fits: ModelCatalogue.fitsDevice(spec, totalRamMb),
          doesNotFitMessage:
              ModelCatalogue.fitsDevice(spec, totalRamMb) ? null : describeModelDoesNotFit(spec, totalRamMb),
          selected: spec.id == selectedLanguageModelId,
        ),
    ];
    final anyFits = cards.any((c) => c.fits);
    final smallest = ModelCatalogue.smallestRequirementGb(visible);
    return ModelSetupData(
      loading: loading,
      speech: ModelCardData(spec: ModelCatalogue.speech, availability: shown(ModelCatalogue.speech.id)),
      languageModels: cards,
      noModelFitsMessage: !anyFits && smallest != null ? describeNoModelFits(smallest) : null,
      wifiOnly: wifiOnly,
    );
  }
}
