import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          ListTile(
            title: const Text('Enable Accessibility Service'),
            subtitle: const Text('Required for background button interception'),
            trailing: const Icon(Icons.settings_accessibility),
            onTap: () {
              const channel = MethodChannel('com.eudemonia/hardware_buttons');
              channel.invokeMethod('openAccessibilitySettings');
            },
          ),
        ],
      ),
    );
  }
}
