import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/models/presentation/model_setup_texts.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'background_permission_service.dart';
import 'system_telemetry_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  /// How often live thermal and memory readings are refreshed while this screen is open.
  static const Duration telemetryRefreshInterval = Duration(seconds: 5);
  Timer? _telemetryRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _telemetryRefreshTimer = Timer.periodic(telemetryRefreshInterval, (_) {
      ref.invalidate(systemTelemetryProvider);
    });
  }

  @override
  void dispose() {
    _telemetryRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(backgroundPermissionStatusProvider);
    }
  }

  Future<void> _addCaptureWidget() async {
    final pinned = await ref.read(nativeCaptureChannelProvider).requestPinWidget();
    if (pinned || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Long-press your home screen, choose Widgets, then Eudemonia.'),
      ),
    );
  }

  Widget _buildPermissionRow({
    required Key key,
    required bool granted,
    required IconData grantedIcon,
    required IconData missingIcon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      leading: Icon(
        granted ? grantedIcon : missingIcon,
        color: granted ? Colors.green : Colors.amber.shade700,
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Chip(
        label: Text(
          granted ? 'Enabled' : 'Disabled',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: granted ? Colors.green.shade900 : Colors.black87,
          ),
        ),
        backgroundColor: granted ? Colors.green.shade100 : Colors.amber.shade300,
      ),
      onTap: onTap,
    );
  }

  void _evictModelsNow() async {
    final modelLifecycle = ref.read(modelLifecycleManagerProvider);
    final evicted =
        await modelLifecycle.evictModels(reason: 'Manual settings screen eviction');
    ref.invalidate(systemTelemetryProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          evicted
              ? 'AI models evicted from memory.'
              : 'A thought is being processed. Models will be evicted as soon as it finishes.',
          style: const TextStyle(color: AppColors.accentCapture),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permStatusAsync = ref.watch(backgroundPermissionStatusProvider);
    final permService = ref.watch(backgroundPermissionServiceProvider);
    final areModelsLoaded =
        ref.watch(modelLifecycleStateProvider) == ModelLifecycleState.ready;
    final rawNotesCountAsync = ref.watch(rawNotesReadyToClusterCountProvider);
    final bufferCount = rawNotesCountAsync.value ?? 0;
    final synthesisSettings = ref.watch(synthesisSettingsProvider);
    final synthesisRunning = ref.watch(synthesisRunningProvider);
    final telemetry = ref.watch(systemTelemetryProvider).value;
    final thermalColor = telemetry == null || telemetry.thermalStatus == null
        ? AppColors.textSecondary
        : telemetry.isThermallyThrottled
            ? AppColors.accentError
            : (telemetry.thermalStatus! >= 1 ? AppColors.accentWarning : AppColors.accentCapture);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('settings_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings & Diagnostics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          // Section 1: Capture permissions
          _buildSectionHeader('CAPTURE PERMISSIONS'),
          permStatusAsync.when(
            data: (status) {
                            return Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardRadius),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildPermissionRow(
                        key: const Key('settings_microphone_row'),
                        granted: status.isMicrophoneGranted,
                        grantedIcon: Icons.check_circle,
                        missingIcon: Icons.mic_off,
                        title: 'Microphone',
                        subtitle: status.isMicrophoneGranted
                            ? 'Thoughts are recorded on this device.'
                            : 'Needed to capture thoughts. Tap to allow.',
                        onTap: () async {
                          await permService.requestMicrophone();
                          ref.invalidate(backgroundPermissionStatusProvider);
                        },
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _buildPermissionRow(
                        key: const Key('settings_notifications_row'),
                        granted: status.areNotificationsEnabled,
                        grantedIcon: Icons.check_circle,
                        missingIcon: Icons.notifications_off,
                        title: 'Notifications (lock-screen Record button)',
                        subtitle: status.areNotificationsEnabled
                            ? 'Start a capture from the lock screen.'
                            : 'Turn on to show the Record button on your lock screen.',
                        onTap: () async {
                          await permService.requestNotifications();
                          ref.invalidate(backgroundPermissionStatusProvider);
                        },
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      // Persistent Foreground Service Toggle
                      SwitchListTile(
                        secondary: Icon(
                          status.isForegroundServiceRunning
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: status.isForegroundServiceRunning
                              ? Colors.green
                              : Colors.amber.shade700,
                        ),
                        title: const Text('Keep capture ready in the background',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: const Text(
                            'Keeps the Record button on your lock screen and finishes transcription and notes while the app is closed.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        value: status.isForegroundServiceRunning,
                        onChanged: (enable) async {
                          if (enable) {
                            await permService.startForegroundService();
                          } else {
                            await permService.stopForegroundService();
                          }
                          ref.invalidate(backgroundPermissionStatusProvider);
                        },
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      ListTile(
                        key: const Key('settings_add_widget_row'),
                        leading: const Icon(Icons.widgets_outlined,
                            color: AppColors.accentCapture),
                        title: const Text('Add capture widget to home screen',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: const Text(
                          'One tap on the home screen starts a capture.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        onTap: _addCaptureWidget,
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: PulseDotsLoader(),
              ),
            ),
            error: (err, _) => ListTile(
              title: const Text('Error loading permission status'),
              subtitle: Text(err.toString()),
            ),
          ),
          const SizedBox(height: 20),

          // On-device models: the files the app downloads (FR16)
          _buildSectionHeader('ON-DEVICE MODELS'),
          _buildModelRows(),
          const SizedBox(height: 20),

          // Section 2: Automatic Synthesis Trigger & Batching
          _buildSectionHeader('AUTOMATIC SYNTHESIS'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Synthesis turns waiting thoughts into notes by itself. Choose when it starts.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                // Threshold 1: Trigger after X capture thoughts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start after this many thoughts',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Synthesis starts once this many thoughts are waiting.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: const Key('synthesis_note_threshold_dropdown'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: synthesisSettings.noteThreshold,
                          dropdownColor: AppColors.surfaceElevated,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.accentAction, size: 20),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          items: const [1, 2, 3, 5, 8, 10].map((count) {
                            return DropdownMenuItem<int>(
                              value: count,
                              child: Text(
                                  '$count ${count == 1 ? 'note' : 'notes'}'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(synthesisSettingsProvider.notifier)
                                  .setNoteThreshold(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.borderSubtle),
                // Threshold 2: Trigger after Y minutes of session quiet
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Or after a quiet period',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Synthesis also starts when no new thought has arrived for this long.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: const Key('synthesis_inactivity_minutes_dropdown'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: synthesisSettings.inactivityMinutes,
                          dropdownColor: AppColors.surfaceElevated,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.accentAction, size: 20),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          items: const [5, 10, 15, 30, 45, 60].map((mins) {
                            return DropdownMenuItem<int>(
                              value: mins,
                              child: Text('$mins mins'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(synthesisSettingsProvider.notifier)
                                  .setInactivityMinutes(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.borderSubtle),
                // Buffer Status & Instant Override Trigger
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 20, color: AppColors.accentAction),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bufferCount == 0 ? 'No thoughts waiting' : describeThoughtsReadyForSynthesis(bufferCount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Starts by itself when the settings above are met',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        key: const Key('synthesize_buffer_now_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentAction,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppColors.badgeRadius)),
                        ),
                        onPressed: bufferCount > 0 && !synthesisRunning
                            ? () => startManualSynthesis(context)
                            : null,
                        child: const Text(
                          'Synthesize Now',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Folders synthesis files notes under (read-only: the set is fixed in this release)
          _buildSectionHeader('FOLDERS'),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Synthesis files each note in one of these folders.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  key: const Key('settings_folder_list'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final folder in defaultFolders)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(AppColors.badgeRadius),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          folder.name,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 6: On-Device AI Memory Telemetry
          _buildSectionHeader('ON-DEVICE AI MEMORY & THERMAL GATING'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Thermal Headroom',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: thermalColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        telemetry?.thermalSummary ?? 'Unavailable',
                        key: const Key('thermal_headroom_value'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: thermalColor,
                        ),
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
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            areModelsLoaded
                                ? 'AI models loaded • inactivity eviction timer active'
                                : 'AI models currently unloaded',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (telemetry?.deviceMemoryLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Device: ${telemetry!.deviceMemoryLabel}'
                              '${telemetry.isLowMemory ? ' • low memory' : ''}',
                              key: const Key('device_memory_value'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
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
                        color: areModelsLoaded
                            ? AppColors.accentWarning
                            : AppColors.accentCapture,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('evict_models_button'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _evictModelsNow,
                  child: const Center(
                    child: Text(
                      'Evict Models Now',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 7: Diagnostic Logging
          _buildSectionHeader('DIAGNOSTIC LOGGING (2MB ROTATING)'),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                ListTile(
                  key: const Key('view_system_logs_button'),
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.accentAction),
                  title: const Text('View System Logs',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Inspect recent trigger events, queue status, and errors',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () async {
                    final logger = ref.read(appLoggerProvider);
                    final lines = await logger.getRecentLines(count: 80);
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.surfaceElevated,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppColors.modalRadius),
                        ),
                      ),
                      builder: (ctx) => DraggableScrollableSheet(
                        initialChildSize: 0.7,
                        maxChildSize: 0.95,
                        minChildSize: 0.4,
                        expand: false,
                        builder: (_, scrollController) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'On-Device Diagnostic Logs',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: AppColors.textSecondary),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ),
                              const Divider(color: AppColors.borderSubtle),
                              Expanded(
                                child: lines.isEmpty
                                    ? const Center(
                                        child: Text('No logs recorded yet.',
                                            style: TextStyle(
                                                color: AppColors.textSecondary)))
                                    : ListView.builder(
                                        controller: scrollController,
                                        itemCount: lines.length,
                                        itemBuilder: (context, index) => Text(
                                          lines[index],
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  key: const Key('copy_log_dump_button'),
                  leading: const Icon(Icons.copy_all,
                      color: AppColors.accentAction),
                  title: const Text('Copy Diagnostic Log Dump',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Copies all on-device logs to clipboard for debugging',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () async {
                    final logger = ref.read(appLoggerProvider);
                    final dump = await logger.getLogDump();
                    await Clipboard.setData(ClipboardData(text: dump));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Log dump copied to clipboard.')),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  key: const Key('clear_logs_button'),
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.accentError),
                  title: const Text('Clear Logs',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentError)),
                  subtitle: const Text('Truncates local log storage file',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () async {
                    final logger = ref.read(appLoggerProvider);
                    await logger.clearLogs();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Local logs cleared.')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About: licences and credits for the bundled models and libraries
          _buildSectionHeader('ABOUT'),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            child: ListTile(
              key: const Key('settings_licences_row'),
              leading: const Icon(Icons.info_outline,
                  color: AppColors.accentAction),
              title: const Text('Licences and credits',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: const Text(
                  'The models and open-source software Eudemonia runs on',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Eudemonia',
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModelRows() {
    final speech = ref.watch(speechModelAvailabilityProvider);
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          row(const Key('settings_speech_model_row'), 'Speech model', describeSpeechModelState(speech)),
          const Divider(height: 1, color: AppColors.borderSubtle),
          row(const Key('settings_writing_model_row'), 'Writing model', writing?.displayName ?? 'Not chosen'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
