import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';

/// The heavy model in memory right now, for the status sheet. Never both at once: the
/// [ModelResidencyArbiter] hands over only after one is fully unloaded.
enum ResidentModel { none, speechLoading, speech, languageLoading, language }

/// The heavy model really in memory, in words.
String describeResidentModel(ResidentModel model) => switch (model) {
      ResidentModel.none => 'AI models unloaded',
      ResidentModel.speechLoading => 'Speech model loading',
      ResidentModel.speech => 'Speech model loaded',
      ResidentModel.languageLoading => 'Writing model loading',
      ResidentModel.language => 'Writing model loaded',
    };

/// The writing (language) model's memory state, reported by `LLMService`: loading, loaded, and
/// unloaded once its weights are freed.
class LanguageModelStateNotifier extends Notifier<ModelLifecycleState> {
  @override
  ModelLifecycleState build() => ModelLifecycleState.unloaded;

  void setState(ModelLifecycleState value) => state = value;
}

final languageModelStateProvider =
    NotifierProvider<LanguageModelStateNotifier, ModelLifecycleState>(LanguageModelStateNotifier.new);

/// Which model is resident given both states. A loaded model wins over one loading: while a
/// recording waits for the writing model to finish its note, the speech model already reads as
/// loading but the writing model is still the one in memory.
ResidentModel residentModelOf({required ModelLifecycleState speech, required ModelLifecycleState language}) {
  if (language == ModelLifecycleState.ready) return ResidentModel.language;
  if (speech == ModelLifecycleState.ready) return ResidentModel.speech;
  if (language == ModelLifecycleState.loading) return ResidentModel.languageLoading;
  if (speech == ModelLifecycleState.loading) return ResidentModel.speechLoading;
  return ResidentModel.none;
}

final residentModelProvider = Provider<ResidentModel>((ref) => residentModelOf(
      speech: ref.watch(modelLifecycleStateProvider),
      language: ref.watch(languageModelStateProvider),
    ));
