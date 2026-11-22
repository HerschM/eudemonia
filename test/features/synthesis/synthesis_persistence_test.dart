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

  Future<Note> savedNote(String text, DateTime at) async {
    final note = Note(correctedText: text, createdAt: at);
    await notesRepo.saveNote(note);
    return note;
  }

  /// What the synthesis runner commits once a session's write turn succeeded.
  Future<SynthesisCluster> commitSession(ProviderContainer container, List<Note> thoughts,
      {String folder = 'Work', String? note}) async {
    final repo = container.read(synthesisRepositoryProvider.notifier);
    await repo.hydrated;
    for (final t in thoughts) {
      t.state = ThoughtState.synthesized;
      await notesRepo.saveNote(t);
    }
    return repo.createSession(
      folder: folder,
      note: note ?? thoughts.map((t) => t.correctedText).join(' '),
      origins: [for (final t in thoughts) SynthesisOriginNote.fromNote(t)],
    );
  }

  setUp(() {
    notesRepo = NotesRepository();
    store = SynthesisSessionStore();
  });

  group('Synthesis sessions survive an app restart', () {
    test('sessions created in one launch are restored in the next, with their origin thoughts', () async {
      final a = await savedNote('Refactor the queue.', DateTime(2026, 11, 5, 9, 0));
      final b = await savedNote('Ship the capsule.', DateTime(2026, 11, 5, 9, 10));
      final c = await savedNote('Feeling good today.', DateTime(2026, 11, 5, 18, 0));

      final first = launchApp();
      final repo = first.read(synthesisRepositoryProvider.notifier);
      await commitSession(first, [a, b], note: 'Refactor the queue and ship the capsule.');
      await commitSession(first, [c], folder: 'Journal');
      await repo.pendingWrites;
      expect(first.read(synthesisRepositoryProvider).length, 2);

      final second = launchApp();
      second.read(synthesisRepositoryProvider);
      await second.read(synthesisRepositoryProvider.notifier).hydrated;
      final restored = second.read(synthesisRepositoryProvider);

      expect(restored.map((c) => c.sequenceNumber), ['#S-02', '#S-01']);
      final work = restored.firstWhere((c) => c.originNotes.length == 2);
      expect(work.originNotes.map((n) => n.cleanedText).toSet(), {'Refactor the queue.', 'Ship the capsule.'});
      expect(work.isUnread, isTrue);
      expect(work.synthesizedContent, 'Refactor the queue and ship the capsule.');
      expect(work.folder, 'Work');
    });

    test('edits made to a session (read, folder, style, merge, delete) are durable', () async {
      final a = await savedNote('A', DateTime(2026, 11, 5, 6, 0));
      final b = await savedNote('B', DateTime(2026, 11, 5, 9, 30));
      final c = await savedNote('C', DateTime(2026, 11, 5, 13, 0));

      final first = launchApp();
      final repo = first.read(synthesisRepositoryProvider.notifier);
      for (final n in [a, b, c]) {
        await commitSession(first, [n]);
      }
      String idOf(String text) => first
          .read(synthesisRepositoryProvider)
          .firstWhere((c) => c.originNotes.any((n) => n.cleanedText == text))
          .clusterId;

      repo.markClusterAsRead(idOf('A'));
      repo.reassignFolder(idOf('A'), 'Journal');
      repo.applyStyle(idOf('A'), 'bullets');
      repo.mergeClusters(idOf('B'), idOf('A'));
      await repo.deleteCluster(idOf('C'));
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
      final a = await savedNote('A', DateTime(2026, 11, 5, 9, 0));
      final first = launchApp();
      await commitSession(first, [a]);
      await first.read(synthesisRepositoryProvider.notifier).pendingWrites;

      final b = await savedNote('B', DateTime(2026, 11, 5, 15, 0));
      final second = launchApp();
      // Committing right at launch (after hydration) must still see the stored session.
      await commitSession(second, [b]);

      expect(second.read(synthesisRepositoryProvider).map((c) => c.sequenceNumber), ['#S-02', '#S-01']);
    });

    test('transient view state is not persisted', () async {
      final a = await savedNote('A', DateTime(2026, 11, 5, 9, 0));
      final first = launchApp();
      final repo = first.read(synthesisRepositoryProvider.notifier);
      await commitSession(first, [a]);
      repo.toggleExpand(first.read(synthesisRepositoryProvider).single.clusterId);
      await repo.pendingWrites;

      final second = launchApp();
      second.read(synthesisRepositoryProvider);
      await second.read(synthesisRepositoryProvider.notifier).hydrated;

      expect(second.read(synthesisRepositoryProvider).single.isExpanded, isFalse);
    });
  });

  group('Deleting a session', () {
    test('returns its thoughts to processed so the next synthesis picks them up', () async {
      final a = await savedNote('A', DateTime(2026, 11, 5, 9, 0));
      final b = await savedNote('B', DateTime(2026, 11, 5, 9, 10));
      final container = launchApp();
      final repo = container.read(synthesisRepositoryProvider.notifier);
      await commitSession(container, [a, b]);
      expect((await notesRepo.getNoteById(a.id))!.state, ThoughtState.synthesized);

      await repo.deleteCluster(container.read(synthesisRepositoryProvider).single.clusterId);

      expect(container.read(synthesisRepositoryProvider), isEmpty);
      expect((await notesRepo.getNoteById(a.id))!.state, ThoughtState.processed);
      expect((await notesRepo.getNoteById(b.id))!.state, ThoughtState.processed);
    });
  });

  group('Session operations used by the synthesis runner', () {
    test('createSession spans its thoughts in time order, at the front, unread', () async {
      final container = launchApp();
      final a = await savedNote('A', DateTime(2026, 11, 5, 9, 0));
      final b = await savedNote('B', DateTime(2026, 11, 5, 9, 25));
      final first = await commitSession(container, [a]);
      final repo = container.read(synthesisRepositoryProvider.notifier);
      final created = repo.createSession(
        folder: 'Personal',
        note: 'Note.',
        origins: [SynthesisOriginNote.fromNote(b), SynthesisOriginNote.fromNote(a)],
      );

      expect(container.read(synthesisRepositoryProvider).map((c) => c.clusterId), [created.clusterId, first.clusterId]);
      expect(created.sequenceNumber, '#S-02');
      expect(created.folder, 'Personal');
      expect(created.synthesizedContent, 'Note.');
      expect(created.originNotes.map((o) => o.id), [a.id, b.id]);
      expect(created.sessionStart, a.createdAt);
      expect(created.sessionEnd, b.createdAt);
      expect(created.sessionDuration, const Duration(minutes: 25));
      expect(created.isUnread, isTrue);
      expect(created.isReprocessing, isFalse);
    });

    test('updateSession replaces the note, adds thoughts in time order and clears the flag', () async {
      final container = launchApp();
      final a = await savedNote('A', DateTime(2026, 11, 5, 9, 0));
      final b = await savedNote('B', DateTime(2026, 11, 5, 9, 40));
      final c = await savedNote('C', DateTime(2026, 11, 5, 9, 20));
      final session = await commitSession(container, [a, b]);
      final repo = container.read(synthesisRepositoryProvider.notifier);
      repo.markClusterAsRead(session.clusterId);
      repo.applyStyle(session.clusterId, 'bullets');

      repo.updateSession(session.clusterId, note: 'Rewritten.', addedOrigins: [SynthesisOriginNote.fromNote(c)]);
      await repo.pendingWrites;

      final updated = container.read(synthesisRepositoryProvider).single;
      expect(updated.synthesizedContent, 'Rewritten.');
      expect(updated.originNotes.map((o) => o.id), [a.id, c.id, b.id]);
      expect(updated.sessionDuration, const Duration(minutes: 40));
      expect(updated.isUnread, isTrue);
      expect(updated.isReprocessing, isFalse);
      expect(updated.appliedStyleId, 'bullets');
      expect((await store.loadAll()).single.synthesizedContent, 'Rewritten.');
    });

    test('removeEmptySession removes only a session without thoughts', () async {
      final container = launchApp();
      final a = await savedNote('A', DateTime(2026, 11, 5, 9, 0));
      final b = await savedNote('B', DateTime(2026, 11, 5, 12, 0));
      final kept = await commitSession(container, [a]);
      final emptied = await commitSession(container, [b]);
      final repo = container.read(synthesisRepositoryProvider.notifier);
      repo.ejectRawNoteToTarget(emptied.clusterId, kept.clusterId, b.id);

      repo.removeEmptySession(kept.clusterId);
      repo.removeEmptySession(emptied.clusterId);

      expect(container.read(synthesisRepositoryProvider).map((c) => c.clusterId), [kept.clusterId]);
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
