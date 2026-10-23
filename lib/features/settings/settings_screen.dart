import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'background_permission_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck permissions when returning from system settings
      ref.invalidate(backgroundPermissionStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permStatusAsync = ref.watch(backgroundPermissionStatusProvider);
    final permService = ref.watch(backgroundPermissionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Keep original audio'),
            subtitle: const Text('Save the raw WAV files on device.'),
            value: false,
            onChanged: (val) {},
          ),
          ListTile(
            title: const Text('Download AI Models'),
            subtitle: const Text('Parakeet v3 & Qwen-2.5 (1.5GB)'),
            trailing: const Icon(Icons.download),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Hardware Shortcut'),
            subtitle: const Text('Press both volume buttons to capture'),
            trailing: const Icon(Icons.hardware),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Background Operation & Permissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'Why two background settings?',
                  onPressed: () => _showBackgroundExplanationDialog(context),
                ),
              ],
            ),
          ),
          permStatusAsync.when(
            data: (status) {
              final allGranted = status.areAllGranted;
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: allGranted
                          ? Colors.green.withValues(alpha: 0.08)
                          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: allGranted ? Colors.green.shade400 : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        allGranted ? Icons.check_circle : Icons.offline_bolt,
                        color: allGranted ? Colors.green : Theme.of(context).colorScheme.primary,
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
                              onPressed: () => permService.showSimultaneousPermissionModal(
                                context,
                                onPermissionsUpdated: () {
                                  ref.invalidate(backgroundPermissionStatusProvider);
                                },
                              ),
                            ),
                    ),
                  ),
                  // Persistent Foreground Service Toggle
                  SwitchListTile(
                    secondary: Icon(
                      status.isForegroundServiceRunning ? Icons.cloud_done : Icons.cloud_off,
                      color: status.isForegroundServiceRunning ? Colors.green : Colors.amber.shade700,
                    ),
                    title: const Text('Keep App Alive in Background'),
                    subtitle: const Text('Runs a low-priority foreground service so the app is never killed'),
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
                  ListTile(
                    leading: Icon(
                      status.isBatteryOptimizationIgnored ? Icons.check_circle : Icons.battery_alert,
                      color: status.isBatteryOptimizationIgnored ? Colors.green : Colors.amber.shade700,
                    ),
                    title: const Text('Background Execution (Battery Exemption)'),
                    subtitle: Text(
                      status.isBatteryOptimizationIgnored
                          ? 'Tap to manage or remove in Android Settings'
                          : 'Keeps Flutter engine alive without being killed in idle',
                    ),
                    trailing: Chip(
                      label: Text(
                        status.isBatteryOptimizationIgnored ? 'Enabled' : 'Disabled',
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
                  ListTile(
                    leading: Icon(
                      status.isAccessibilityEnabled ? Icons.check_circle : Icons.accessibility,
                      color: status.isAccessibilityEnabled ? Colors.green : Colors.amber.shade700,
                    ),
                    title: const Text('Accessibility Service'),
                    subtitle: const Text('Intercepts dual volume buttons globally. Tap to enable/disable.'),
                    trailing: Chip(
                      label: Text(
                        status.isAccessibilityEnabled ? 'Enabled' : 'Disabled',
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Diagnostics & Device Logs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('View System Logs'),
            subtitle: const Text('Inspect recent trigger events, queue status, and errors'),
            onTap: () async {
              final logger = ref.read(appLoggerProvider);
              final lines = await logger.getRecentLines(count: 80);
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: lines.isEmpty
                              ? const Center(child: Text('No logs recorded yet.'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: lines.length,
                                  itemBuilder: (context, index) => Text(
                                    lines[index],
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
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
          ListTile(
            leading: const Icon(Icons.copy_all),
            title: const Text('Copy Diagnostic Log Dump'),
            subtitle: const Text('Copies all on-device logs to clipboard for debugging'),
            onTap: () async {
              final logger = ref.read(appLoggerProvider);
              final dump = await logger.getLogDump();
              await Clipboard.setData(ClipboardData(text: dump));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log dump copied to clipboard.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Clear Logs', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Truncates local log storage file'),
            onTap: () async {
              final logger = ref.read(appLoggerProvider);
              await logger.clearLogs();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local logs cleared.')),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showBackgroundExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Background Settings Explained'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Background Execution (Battery Exemption):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Exempts Eudemonia from Android Doze mode. Allows voice notes to process in the background and prevents CPU sleep when the device screen is locked.',
            ),
            SizedBox(height: 12),
            Text(
              '2. Keep App Alive in Background (Foreground Service):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Maintains continuous foreground process priority with a low-priority notification. This prevents Android OS from terminating or evicting the app from RAM.',
            ),
            SizedBox(height: 12),
            Text(
              '💡 Tip: Enabling both guarantees 100% reliable hardware shortcuts without the app ever being killed.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Got It'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}
