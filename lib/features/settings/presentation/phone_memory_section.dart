import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/settings/system_telemetry_service.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'settings_card.dart';

/// How often live thermal and memory readings are refreshed while the section is open.
const Duration telemetryRefreshInterval = Duration(seconds: 5);

/// Thermal headroom and memory readings with a button to free the AI models now. Collapsed by
/// default; readings are only taken (and refreshed) while it is open.
class PhoneMemorySection extends StatelessWidget {
  const PhoneMemorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return CollapsibleSettingsSection(
      headerKey: const Key('settings_memory_header'),
      title: 'PHONE MEMORY AND TEMPERATURE',
      bodyBuilder: (_) => const _PhoneMemoryBody(),
    );
  }
}

/// Built only while the section is expanded, so its refresh timer lives exactly that long.
class _PhoneMemoryBody extends ConsumerStatefulWidget {
  const _PhoneMemoryBody();

  @override
  ConsumerState<_PhoneMemoryBody> createState() => _PhoneMemoryBodyState();
}

class _PhoneMemoryBodyState extends ConsumerState<_PhoneMemoryBody> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(telemetryRefreshInterval, (_) {
      ref.invalidate(systemTelemetryProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _freeModelMemoryNow() async {
    final modelLifecycle = ref.read(modelLifecycleManagerProvider);
    final freed = await modelLifecycle.evictModels(reason: 'Manual settings screen eviction');
    ref.invalidate(systemTelemetryProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          freed
              ? 'AI model memory freed.'
              : 'A thought is being processed. Model memory will be freed as soon as it finishes.',
          style: const TextStyle(color: AppColors.accentCapture),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areModelsLoaded = ref.watch(modelLifecycleStateProvider) == ModelLifecycleState.ready;
    final telemetry = ref.watch(systemTelemetryProvider).value;
    final thermalColor = telemetry == null || telemetry.thermalStatus == null
        ? AppColors.textSecondary
        : telemetry.isThermallyThrottled
            ? AppColors.accentError
            : (telemetry.thermalStatus! >= 1 ? AppColors.accentWarning : AppColors.accentCapture);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Thermal Headroom',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: thermalColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                telemetry?.thermalSummary ?? 'Unavailable',
                key: const Key('thermal_headroom_value'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: thermalColor),
              ),
            ),
          ],
        ),
        const Divider(height: 20, color: AppColors.borderSubtle),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Memory In Use',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    areModelsLoaded
                        ? 'AI models loaded • inactivity eviction timer active'
                        : 'AI models currently unloaded',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (telemetry?.deviceMemoryLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Device: ${telemetry!.deviceMemoryLabel}'
                      '${telemetry.isLowMemory ? ' • low memory' : ''}',
                      key: const Key('device_memory_value'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              telemetry?.appMemoryLabel ?? 'Unavailable',
              key: const Key('app_memory_value'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: areModelsLoaded ? AppColors.accentWarning : AppColors.accentCapture,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const Key('evict_models_button'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderSubtle),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _freeModelMemoryNow,
            child: const Text(
              'Free model memory now',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
