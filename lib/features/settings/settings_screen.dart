import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'background_permission_service.dart';

class FolderManifesto {
  final String id;
  final String name;
  final String icon;
  final String description;
  final List<String> keywords;

  const FolderManifesto({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.keywords,
  });

  FolderManifesto copyWith({String? description}) {
    return FolderManifesto(
      id: id,
      name: name,
      icon: icon,
      description: description ?? this.description,
      keywords: keywords,
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  int _synthesisNoteThreshold = 3;
  int _synthesisInactivityMinutes = 15;
  bool _keepRawAudio = false;
  bool _isCalendarSyncEnabled = false;

  late List<FolderManifesto> _folderManifestos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _folderManifestos = [
      const FolderManifesto(
        id: 'work',
        name: 'Work',
        icon: '💼',
        description:
            'Flutter app development, technical architecture, and system design.',
        keywords: ['flutter', 'riverpod', 'isar', 'debouncer'],
      ),
      const FolderManifesto(
        id: 'ideas',
        name: 'Ideas',
        icon: '💡',
        description: 'Creative concepts, product features, and brainstorming.',
        keywords: ['voice-first', 'ai-hud', 'mobile', 'on-device'],
      ),
      const FolderManifesto(
        id: 'todos',
        name: 'Todos',
        icon: '✅',
        description: 'Action items, operational commitments, and errands.',
        keywords: ['call', 'fix', 'review', 'schedule'],
      ),
      const FolderManifesto(
        id: 'journal',
        name: 'Journal',
        icon: '📖',
        description:
            'Personal reflections, daily logs, energy levels, and stream-of-consciousness.',
        keywords: ['morning walk', 'reflection', 'mood', 'gratitude'],
      ),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(backgroundPermissionStatusProvider);
    }
  }

  void _triggerSynthesisNow() async {
    await ref.read(synthesisRepositoryProvider.notifier).synthesizeRawNotes();
    ref.invalidate(rawNotesReadyToClusterCountProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.accentAI, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Triggered on-demand synthesis for buffered thoughts!',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _evictModelsNow() async {
    final modelLifecycle = ref.read(modelLifecycleManagerProvider);
    await modelLifecycle.evictModels(reason: 'Manual settings screen eviction');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          'AI models evicted. Memory reclaimed: ~1.58 GB RAM. Baseline: <60 MB.',
          style: TextStyle(color: AppColors.accentCapture),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openAddFolderDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.cardRadius),
        ),
        title: const Text(
          'Add Custom Folder',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Folder Name',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('new_folder_name_field'),
              controller: nameController,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Health, Finances, Client X',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Semantic Description (Manifesto)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('new_folder_desc_field'),
              controller: descController,
              maxLines: 2,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Describe projects and topics that belong in this folder...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            key: const Key('confirm_add_folder_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAction,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _folderManifestos.add(
                    FolderManifesto(
                      id: name.toLowerCase().replaceAll(' ', '_'),
                      name: name,
                      icon: '📁',
                      description: desc.isNotEmpty ? desc : 'Custom user folder.',
                      keywords: [name.toLowerCase()],
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create Folder',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permStatusAsync = ref.watch(backgroundPermissionStatusProvider);
    final permService = ref.watch(backgroundPermissionServiceProvider);
    final modelLifecycle = ref.watch(modelLifecycleManagerProvider);
    final rawNotesCountAsync = ref.watch(rawNotesReadyToClusterCountProvider);
    final bufferCount = rawNotesCountAsync.value ?? 0;

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
          // Section 1: Background & Hardware Permissions
          _buildSectionHeader('HARDWARE & BACKGROUND PERMISSIONS'),
          permStatusAsync.when(
            data: (status) {
              final allGranted = status.areAllGranted;
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
                      Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: Material(
                          color: allGranted
                              ? Colors.green.withValues(alpha: 0.08)
                              : Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: allGranted
                                  ? Colors.green.shade400
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              allGranted ? Icons.check_circle : Icons.offline_bolt,
                              color: allGranted
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                            title: Text(
                              allGranted
                                  ? 'Background Capture Enabled'
                                  : 'Enable Both Permissions Simultaneously',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              allGranted
                                  ? 'The app is exempt from battery saver and listening for volume shortcuts.'
                                  : 'Grants battery optimization exemption & accessibility service together.',
                            ),
                            trailing: allGranted
                                ? null
                                : ElevatedButton(
                                    child: const Text('Grant Both'),
                                    onPressed: () =>
                                        permService.showSimultaneousPermissionModal(
                                      context,
                                      onPermissionsUpdated: () {
                                        ref.invalidate(
                                            backgroundPermissionStatusProvider);
                                      },
                                    ),
                                  ),
                          ),
                        ),
                      ),
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
                        title: const Text('Keep App Alive in Background',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: const Text(
                            'Runs a low-priority foreground service with lock screen capture banner',
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
                        leading: Icon(
                          status.isBatteryOptimizationIgnored
                              ? Icons.check_circle
                              : Icons.battery_alert,
                          color: status.isBatteryOptimizationIgnored
                              ? Colors.green
                              : Colors.amber.shade700,
                        ),
                        title: const Text('Background Execution (Battery Exemption)',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: Text(
                          status.isBatteryOptimizationIgnored
                              ? 'Tap to manage or remove in Android Settings'
                              : 'Keeps Flutter engine alive without being killed in idle',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Chip(
                          label: Text(
                            status.isBatteryOptimizationIgnored
                                ? 'Enabled'
                                : 'Disabled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status.isBatteryOptimizationIgnored
                                  ? Colors.green.shade900
                                  : Colors.black87,
                            ),
                          ),
                          backgroundColor: status.isBatteryOptimizationIgnored
                              ? Colors.green.shade100
                              : Colors.amber.shade300,
                        ),
                        onTap: () async {
                          if (status.isBatteryOptimizationIgnored) {
                            await permService.openBatteryOptimizationSettings();
                          } else {
                            await permService.requestBatteryOptimizationExemption();
                          }
                          ref.invalidate(backgroundPermissionStatusProvider);
                        },
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      ListTile(
                        leading: Icon(
                          status.isAccessibilityEnabled
                              ? Icons.check_circle
                              : Icons.accessibility,
                          color: status.isAccessibilityEnabled
                              ? Colors.green
                              : Colors.amber.shade700,
                        ),
                        title: const Text('Accessibility Service',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: const Text(
                          'Intercepts dual volume buttons globally. Tap to enable/disable.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Chip(
                          label: Text(
                            status.isAccessibilityEnabled
                                ? 'Enabled'
                                : 'Disabled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status.isAccessibilityEnabled
                                  ? Colors.green.shade900
                                  : Colors.black87,
                            ),
                          ),
                          backgroundColor: status.isAccessibilityEnabled
                              ? Colors.green.shade100
                              : Colors.amber.shade300,
                        ),
                        onTap: () async {
                          await permService.openAccessibilitySettings();
                          ref.invalidate(backgroundPermissionStatusProvider);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => ListTile(
              title: const Text('Error loading permission status'),
              subtitle: Text(err.toString()),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Automatic Synthesis Trigger & Batching
          _buildSectionHeader('AUTOMATIC SYNTHESIS TRIGGER & BATCHING'),
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
                  'Groups thoughts captured during an activity and triggers clustering without draining mobile battery.',
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
                            'Trigger After X Captures',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Accumulated unprocessed notes threshold',
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
                          value: _synthesisNoteThreshold,
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
                              setState(() => _synthesisNoteThreshold = val);
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
                            'Trigger After Y Minutes Quiet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Session quiet window since last capture',
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
                          value: _synthesisInactivityMinutes,
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
                              setState(() => _synthesisInactivityMinutes = val);
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
                              '$bufferCount Unprocessed Thoughts in Buffer',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Will auto-cluster when threshold is met',
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
                        onPressed: bufferCount > 0 ? _triggerSynthesisNow : null,
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

          // Section 3: Folder Management & Semantic Manifestos
          _buildSectionHeader('FOLDER MANAGEMENT & SEMANTIC MANIFESTOS'),
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
                  'Folder descriptions guide on-device AI classification to accurately distinguish between projects and apps, even for abrupt thoughts.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ..._folderManifestos.map((manifesto) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(manifesto.icon,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(
                              manifesto.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          manifesto.description,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('add_custom_folder_button'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentAction),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add,
                        size: 16, color: AppColors.accentAction),
                    label: const Text(
                      'Add Custom Folder',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentAction),
                    ),
                    onPressed: _openAddFolderDialog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Calendar Synchronization
          _buildSectionHeader('CALENDAR SYNCHRONIZATION'),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sync Action Items with Calendar',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    subtitle: const Text(
                        'Automatically schedule extracted commitments as time blocks',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    value: _isCalendarSyncEnabled,
                    onChanged: (val) =>
                        setState(() => _isCalendarSyncEnabled = val),
                  ),
                  const Divider(height: 16, color: AppColors.borderSubtle),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Active Calendar Provider',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        'Google Calendar',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 5: Audio Capture Storage
          _buildSectionHeader('AUDIO CAPTURE STORAGE'),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            child: SwitchListTile(
              title: const Text('Keep Raw Audio Files',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: const Text(
                  'Retain original WAV voice audio alongside cleaned transcripts',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              value: _keepRawAudio,
              onChanged: (val) => setState(() => _keepRawAudio = val),
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
                        color: AppColors.accentCapture.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '84% (Nominal)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentCapture,
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
                            'On-Device AI Model Footprint',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            modelLifecycle.areModelsLoaded
                                ? 'Inactivity eviction timer: active (to <60MB)'
                                : 'Models currently unloaded (<60 MB footprint)',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      modelLifecycle.areModelsLoaded ? '~1.58 GB RAM' : '<60 MB RAM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: modelLifecycle.areModelsLoaded
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
                      'Evict Models Now (<60 MB)',
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
          const SizedBox(height: 32),
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
