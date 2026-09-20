import 'package:flutter/material.dart';

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
            title: const Text('Hardware Button Config'),
            subtitle: const Text('Currently: Volume UP Long Press'),
            trailing: const Icon(Icons.hardware),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
