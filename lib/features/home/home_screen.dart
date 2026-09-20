import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../settings/settings_screen.dart';

// A simple provider to hold the recording state for UI reactivity
class IsRecordingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRecording(bool value) {
    state = value;
  }
}

final isRecordingProvider = NotifierProvider<IsRecordingNotifier, bool>(() {
  return IsRecordingNotifier();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _channel = MethodChannel('com.eudemonia/hardware_buttons');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onHardwareTrigger') {
      final isRecording = ref.read(isRecordingProvider);
      
      if (!isRecording) {
        // Start recording
        ref.read(isRecordingProvider.notifier).setRecording(true);
        // Haptic feedback
        HapticFeedback.heavyImpact();
      } else {
        // Stop recording
        ref.read(isRecordingProvider.notifier).setRecording(false);
        HapticFeedback.vibrate();
        // Here we would call the STT -> LLM -> Save pipeline
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(isRecordingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eudemonia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Folders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Horizontal list of folders
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFolderCard(context, 'Ideas', Icons.lightbulb_outline),
                    _buildFolderCard(context, 'Work', Icons.work_outline),
                    _buildFolderCard(context, 'Journal', Icons.book_outlined),
                    _buildFolderCard(context, 'Todos', Icons.check_circle_outline),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Recent Thoughts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text(
                    'No thoughts yet.\nPress both volume buttons to capture.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ),
              // Recording Indicator
              if (isRecording)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Listening...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, String title, IconData icon) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to note list filtered by folder
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
