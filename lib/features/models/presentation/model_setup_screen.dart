import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view_data.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Opens the model setup screen on top of the current route.
Future<void> openModelSetup(NavigatorState navigator) =>
    navigator.push(MaterialPageRoute<void>(builder: (_) => const ModelSetupScreen()));

/// Download and choose the on-device models. Wires [ModelSetupView] to the controller.
class ModelSetupScreen extends ConsumerWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(modelLibraryControllerProvider);
    final settings = ref.watch(modelSettingsProvider);
    final controller = ref.read(modelLibraryControllerProvider.notifier);
    final data = ModelSetupData.build(
      loading: !library.loaded,
      totalRamMb: library.device.totalRamMb,
      availabilityOf: library.of,
      selectedLanguageModelId: settings.selectedLanguageModelId,
      wifiOnly: settings.wifiOnly,
      includeCandidates: ref.watch(includeCandidateModelsProvider),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('model_setup_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'On-device models',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ModelSetupView(
        data: data,
        onDownload: (id) => controller.download(id),
        onCancel: (id) => controller.cancel(id),
        onDelete: (id) => controller.delete(id),
        onSelect: controller.select,
        onWifiOnlyChanged: controller.setWifiOnly,
      ),
    );
  }
}
