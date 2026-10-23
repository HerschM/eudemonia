import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            child: Text(
              'Background Operation & Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
                        color: allGranted ? Colors.green.shade300 : Theme.of(context).colorScheme.primary,
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
                            ? 'Background Capture Fully Active'
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
                  ListTile(
                    leading: Icon(
                      status.isBatteryOptimizationIgnored ? Icons.check_circle : Icons.battery_alert,
                      color: status.isBatteryOptimizationIgnored ? Colors.green : Colors.orange,
                    ),
                    title: const Text('Background Execution (Battery Exemption)'),
                    subtitle: const Text('Keeps Flutter engine alive without being killed in idle'),
                    trailing: Chip(
                      label: Text(
                        status.isBatteryOptimizationIgnored ? 'Granted' : 'Disabled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status.isBatteryOptimizationIgnored ? Colors.white : Colors.black87,
                        ),
                      ),
                      backgroundColor:
                          status.isBatteryOptimizationIgnored ? Colors.green : Colors.orange.shade200,
                    ),
                    onTap: () async {
                      await permService.requestBatteryOptimizationExemption();
                      ref.invalidate(backgroundPermissionStatusProvider);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      status.isAccessibilityEnabled ? Icons.check_circle : Icons.accessibility,
                      color: status.isAccessibilityEnabled ? Colors.green : Colors.orange,
                    ),
                    title: const Text('Accessibility Service'),
                    subtitle: const Text('Intercepts dual volume buttons globally'),
                    trailing: Chip(
                      label: Text(
                        status.isAccessibilityEnabled ? 'Active' : 'Disabled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status.isAccessibilityEnabled ? Colors.white : Colors.black87,
                        ),
                      ),
                      backgroundColor:
                          status.isAccessibilityEnabled ? Colors.green : Colors.orange.shade200,
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
        ],
      ),
    );
  }
}

