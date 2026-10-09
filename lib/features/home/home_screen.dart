import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../ai_processing/batch_pipeline_service.dart';
import '../settings/settings_screen.dart';

import '../notes/data/note_model.dart';
import '../notes/data/notes_repository.dart';

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

final recentNotesProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getAllNotes();
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
      
      // Extract contextual state from Android (used for dynamic pipeline routing)
      final bool isLocked = call.arguments?['isLocked'] ?? false;
      
      if (!isRecording) {
        // Start recording
        ref.read(isRecordingProvider.notifier).setRecording(true);
        // Haptic feedback (Native)
        _channel.invokeMethod('playHaptic', {'isStart': true});
        
        // TODO: FUTURE ENHANCEMENT (Flow A vs Flow B)
        // This is where we will route the AI pipeline dynamically.
        // If (isLocked == false) -> Initialize Flow A (Streaming Zipformer, Read Screen Context, Native Text Injection).
        // If (isLocked == true) -> Initialize Flow B (Batch STT like Parakeet, Qwen categorization, Database Save).
        print("Hardware Trigger Started. isLocked: $isLocked");
        
        await ref.read(batchPipelineProvider).startRecording();
        
      } else {
        // Stop recording
        ref.read(isRecordingProvider.notifier).setRecording(false);
        _channel.invokeMethod('playHaptic', {'isStart': false});
        
        // TODO: Finalize recording and execute the selected pipeline.
        // For our current milestone, we are executing Flow B (Batch Mode).
        print("Hardware Trigger Stopped. Executing Batch Pipeline (Flow B)...");
        await ref.read(batchPipelineProvider).stopRecordingAndProcess();
        
        // Refresh the UI list
        ref.invalidate(recentNotesProvider);
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
                child: Consumer(
                  builder: (context, ref, child) {
                    final notesAsync = ref.watch(recentNotesProvider);
                    
                    return notesAsync.when(
                      data: (notes) {
                        if (notes.isEmpty) {
                          return Center(
                            child: Text(
                              'No thoughts yet.\nPress both volume buttons to capture.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(Icons.notes, color: Theme.of(context).colorScheme.primary),
                                title: Text(note.correctedText),
                                subtitle: Text('${note.folder} • ${_formatDate(note.createdAt)}'),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    );
                  },
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
