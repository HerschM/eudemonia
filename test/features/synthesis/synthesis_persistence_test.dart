import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_record.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

void main() {
  late NotesRepository notesRepo;
  late SynthesisSessionStore store;

  /// A fresh container models an app launch: new in-memory state over the same durable storage.
  ProviderContainer launchApp() {
    final container = ProviderContainer(
      overrides: [
        notesRepositoryProvider.overrideWithValue(notesRepo),
        synthesisSessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Note> savedNote(String text, String folder) async {
    final note = Note(correctedText: text, folder: folder);
    await notesRepo.saveNote(note);
    return note;
  }

  setUp(() {
    notesRepo = NotesRepository();
    store = SynthesisSessionStore();
  });

  group('Synthesis sessions survive an app restart', () {
    test('sessions created in one launch are restored in the next, with their origin thoughts', () async {
      await savedNote('Refactor the queue.', 'Work');
      await savedNote('Ship the capsule.', 'Work');
      await savedNote('Feeling good today.', 'Journal');

      final first = launchApp();
      final repo = first.read(synthesisRepositoryProvider.notifier);
      await repo.synthesizeRawNotes();
      await repo.pendingWrites;
      expect(first.read(synthesisRepositoryProvider).length, 2);

      final second = launchApp();
      second.read(synthesisRepositoryProvider);
      await second.read(synthesisRepositoryProvider.notifier).hydrated;
      final restored = second.read(synthesisRepositoryProvider);

      expect(restored.map((c) => c.sequenceNumber), ['#S-02', '#S-01']);
      final work = restored.firstWhere((c) => c.folder == 'Work');
      expect(work.originNotes.map((n) => n.cleanedText).toSet(), {'Refactor the queue.', 'Ship the capsule.'});
      expect(work.isUnread, isTrue);
      expect(work.synthesizedContent, contains('Consolidated 2 thoughts'));
    });

    test('edits made to a session (read, folder, style, merge, delete) are durable', () async {
      await savedNote('A', 'Work');
      await savedNote('B', 'Ideas');
      await savedNote('C', 'Todos');

      final first = launchApp();
      final repo = first.read(synthesisRepositoryProvider.notifier);
      await repo.synthesizeRawNotes();
      String idOf(String folder) =>
          first.read(synthesisRepositoryProvider).firstWhere((c) => c.folder == folder).clusterId;

      repo.markClusterAsRead(idOf('Work'));
      repo.reassignFolder(idOf('Work'), 'Journal');
      repo.applyStyle(idOf('Journal'), 'bullets');
      repo.mergeClusters(idOf('Ideas'), idOf('Journal'));
      repo.deleteCluster(idOf('Todos'));
      await repo.pendingWrites;

      final second = launchApp();
      second.read(synthesisRepositoryProvider);
      await second.read(synthesisRepositoryProvider.notifier).hydrated;
      final restored = second.read(synthesisRepositoryProvider);

      expect(restored.length, 1);
      final session = restored.single;
      expect(session.folder, 'Journal');
      expect(session.isUnread, isFalse);
      expect(session.appliedStyleId, 'bullets');
      expect(session.isReprocessing, isTrue);
      expect(session.originNotes.map((n) => n.cleanedText).toSet(), {'A', 'B'});
    });

    test('a session created after a restart continues the identifier sequence', () async {
      await savedNote('A', 'Work');
      final first = launchApp();
      await first.read(synthesisRepositoryProvider.notifier).synthesizeRawNotes();
      await first.read(synthesisRepositoryProvider.notifier).pendingWrites;

      await savedNote('B', 'Ideas');
      final second = launchApp();
      // Synthesizing right at launch must still see the stored session.
      await second.read(synthesisRepositoryProvider.notifier).synthesizeRawNotes();

      expect(second.read(synthesisRepositoryProvider).map((c) => c.sequenceNumber), ['#S-02', '#S-01']);
    });

    test('transient view state is not persisted', () async {
      await savedNote('A', 'Work');
      final first = launchApp();
      final repo = first.read(synthesisRepositoryProvider.notifier);
      await repo.synthesizeRawNotes();
      repo.toggleExpand(first.read(synthesisRepositoryProvider).single.clusterId);
      await repo.pendingWrites;

      final second = launchApp();
      second.read(synthesisRepositoryProvider);
      await second.read(synthesisRepositoryProvider.notifier).hydrated;

      expect(second.read(synthesisRepositoryProvider).single.isExpanded, isFalse);
    });
  });

  group('Orphaned synthesized thoughts', () {
    test('thoughts whose session was lost return to the clustering buffer; claimed thoughts stay put',
        () async {
      final claimed = await savedNote('Kept in a session', 'Work');
      final container = launchApp();
      final repo = container.read(synthesisRepositoryProvider.notifier);
      await repo.synthesizeRawNotes();
      await repo.pendingWrites;

      // Left behind by a session that was never persisted.
      final orphan = Note(correctedText: 'Lost session thought', state: ThoughtState.synthesized);
      await notesRepo.saveNote(orphan);

      final relaunched = launchApp();
      relaunched.read(synthesisRepositoryProvider);
      final recovered =
          await relaunched.read(synthesisRepositoryProvider.notifier).recoverOrphanedSynthesizedNotes();

      expect(recovered, 1);
      expect((await notesRepo.getNoteById(orphan.id))!.state, ThoughtState.processed);
      expect((await notesRepo.getNoteById(claimed.id))!.state, ThoughtState.synthesized);
      expect(await relaunched.read(rawNotesReadyToClusterCountProvider.future), 1);
    });
  });

  group('SynthesisSessionRecord mapping', () {
    test('round-trips every durable field of a cluster', () {
      final start = DateTime(2026, 11, 5, 7, 10);
      final cluster = SynthesisCluster(
        clusterId: 'cluster_x',
        sequenceNumber: '#S-07',
        folder: 'Ideas',
        synthesizedContent: 'Narrative',
        sessionStart: start,
        sessionEnd: start.add(const Duration(minutes: 35)),
        sessionDuration: const Duration(minutes: 35),
        originNotes: [
          SynthesisOriginNote(
            id: 42,
            formattedSequence: '#03',
            cleanedText: 'Origin text',
            folder: 'Ideas',
            timestamp: start,
            audioPath: '/a.wav',
          ),
        ],
        isExpanded: true,
        isReprocessing: true,
        appliedStyleId: 'professional',
        isUnread: true,
        isActionExtracted: false,
      );

      final restored = SynthesisSessionRecord.fromCluster(cluster).toCluster();

      expect(restored.clusterId, 'cluster_x');
      expect(restored.sequenceNumber, '#S-07');
      expect(restored.folder, 'Ideas');
      expect(restored.synthesizedContent, 'Narrative');
      expect(restored.sessionStart, start);
      expect(restored.sessionDuration, const Duration(minutes: 35));
      expect(restored.isReprocessing, isTrue);
      expect(restored.appliedStyleId, 'professional');
      expect(restored.isUnread, isTrue);
      expect(restored.isActionExtracted, isFalse);
      expect(restored.isExpanded, isFalse);
      final origin = restored.originNotes.single;
      expect(origin.id, 42);
      expect(origin.formattedSequence, '#03');
      expect(origin.cleanedText, 'Origin text');
      expect(origin.timestamp, start);
      expect(origin.audioPath, '/a.wav');
    });
  });
}
