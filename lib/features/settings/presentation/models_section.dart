import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/models/presentation/model_setup_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'settings_card.dart';

/// The speech and writing models on the phone (FR16); each row opens the model setup screen.
class OnDeviceModelsSection extends ConsumerWidget {
  const OnDeviceModelsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(speechModelAvailabilityProvider);
    final selectedSpeech = ref.watch(selectedSpeechModelProvider);
    final anySpeechDownloaded = ref.watch(modelLibraryControllerProvider
        .select((s) => ModelCatalogue.speechModels.any((m) => s.of(m.id).isReady)));
    final profile = ref.watch(activeSynthesisProfileProvider);
    final writing = ModelCatalogue.languageModels.where((m) => m.profile == profile).firstOrNull;
    Widget row(Key key, String label, String value) => Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(AppColors.cardRadius),
            onTap: () => openModelSetup(Navigator.of(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label · $value',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('ON-DEVICE MODELS'),
        SettingsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              row(
                const Key('settings_speech_model_row'),
                'Speech model',
                describeSpeechModelSummary(
                  selected: selectedSpeech,
                  availability: speech,
                  anyDownloaded: anySpeechDownloaded,
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              row(const Key('settings_writing_model_row'), 'Writing model', writing?.displayName ?? 'Not chosen'),
            ],
          ),
        ),
      ],
    );
  }
}
