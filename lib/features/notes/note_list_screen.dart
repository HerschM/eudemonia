import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/note_model.dart';
import 'data/notes_repository.dart';
import 'presentation/thought_card.dart';
import 'audio_playback_controller.dart';

final notesByFolderProvider = FutureProvider.family<List<Note>, String>((ref, folder) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getNotesByFolder(folder);
});

class NoteListScreen extends ConsumerWidget {
  final String folder;

  const NoteListScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesByFolderProvider(folder));
    final playbackState = ref.watch(audioPlaybackControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(folder),
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Text(
                'No notes in $folder yet.',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final isPlaying = playbackState.isPlaying &&
                  playbackState.currentlyPlayingPath == note.originalAudioPath;

              return ThoughtCard(
                key: ValueKey(note.id),
                note: note,
                sequenceNumber: note.dailySequenceNumber,
                isPlaying: isPlaying,
                onPlayAudio: note.originalAudioPath != null && note.originalAudioPath!.isNotEmpty
                    ? () {
                        ref.read(audioPlaybackControllerProvider.notifier).togglePlayback(note.originalAudioPath!);
                      }
                    : null,
                onEdit: (newText) async {
                  if (note.id > 0) {
                    await ref.read(notesRepositoryProvider).updateNoteText(note.id, newText);
                    ref.invalidate(notesByFolderProvider(folder));
                    ref.invalidate(recentNotesProvider);
                  }
                },
                onCategoryChanged: (newCategory) async {
                  if (note.id > 0) {
                    await ref.read(notesRepositoryProvider).updateNoteFolder(note.id, newCategory);
                    ref.invalidate(notesByFolderProvider(folder));
                    ref.invalidate(recentNotesProvider);
                  }
                },
                onDelete: note.id > 0
                    ? () async {
                        await ref.read(notesRepositoryProvider).deleteNote(note.id);
                        ref.invalidate(notesByFolderProvider(folder));
                        ref.invalidate(recentNotesProvider);
                      }
                    : null,
                onTap: () async {
                  if (!note.isRead && note.id > 0) {
                    await ref.read(notesRepositoryProvider).markAsRead(note.id);
                    ref.invalidate(notesByFolderProvider(folder));
                    ref.invalidate(recentNotesProvider);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
