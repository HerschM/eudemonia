import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../ai_processing/batch_pipeline_service.dart';
import '../ai_processing/audio_queue_service.dart';
import '../../core/logger/app_logger.dart';
import '../settings/settings_screen.dart';
import '../settings/background_permission_service.dart';

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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.eudemonia/hardware_buttons');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleMethodCall);
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

  DateTime? _lastTriggerTime;
  bool _isToggling = false;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onHardwareTrigger') {
      final now = DateTime.now();
      if (_lastTriggerTime != null && now.difference(_lastTriggerTime!) < const Duration(milliseconds: 500)) {
        ref.read(appLoggerProvider).warning('[HomeScreen] Trigger dropped by debounce (<500ms)');
        return;
      }
      if (_isToggling) {
        ref.read(appLoggerProvider).warning('[HomeScreen] Trigger dropped: already toggling');
        return;
      }

      _lastTriggerTime = now;
      _isToggling = true;

      try {
        final isRecording = ref.read(isRecordingProvider);
        final bool isLocked = call.arguments?['isLocked'] ?? false;
        ref.read(appLoggerProvider).trigger('Hardware Trigger Received. isLocked: $isLocked, current isRecording: $isRecording');

        if (!isRecording) {
          // Start recording
          ref.read(isRecordingProvider.notifier).setRecording(true);
          await ref.read(batchPipelineProvider).startRecording();
        } else {
          // Stop recording
          ref.read(isRecordingProvider.notifier).setRecording(false);
          await ref.read(batchPipelineProvider).stopRecordingAndProcess();
          // Invalidate notes list once enqueued
          ref.invalidate(recentNotesProvider);
        }
      } catch (e, stack) {
        ref.read(appLoggerProvider).error('[HomeScreen] Error during hardware trigger handling', error: e, stackTrace: stack);
      } finally {
        _isToggling = false;
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
          Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(pendingQueueCountProvider);
              if (count <= 0) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ambient permission banner if background capture is not fully enabled
              Consumer(
                builder: (context, ref, _) {
                  final permAsync = ref.watch(backgroundPermissionStatusProvider);
                  final permService = ref.watch(backgroundPermissionServiceProvider);
                  return permAsync.maybeWhen(
                    data: (status) {
                      if (status.areAllGranted) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Background capture permissions needed (Accessibility & Battery exemption).',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                backgroundColor: Colors.amber.shade300,
                              ),
                              child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => permService.showSimultaneousPermissionModal(
                                context,
                                onPermissionsUpdated: () {
                                  ref.invalidate(backgroundPermissionStatusProvider);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
              // In-body pending queue processing banner
              Consumer(
                builder: (context, ref, _) {
                  final pendingCount = ref.watch(pendingQueueCountProvider);
                  if (pendingCount <= 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pendingCount == 1
                                ? 'Processing voice thought...'
                                : 'Processing voice thought ($pendingCount pending)...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // In-body failed queue banner with Retry button
              Consumer(
                builder: (context, ref, _) {
                  final failedCount = ref.watch(failedQueueCountProvider);
                  if (failedCount <= 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$failedCount thought(s) failed to process',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: Colors.red.shade200,
                          ),
                          child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            ref.read(audioQueueServiceProvider).retryFailed();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
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
