import 'package:eudemonia/core/formatting/thought_timestamp.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/session_numbering_flag_store.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts how often the one-time renumbering asks for and sets its flag.
class MemoryNumberingFlag implements SessionNumberingFlagStore {
  bool done;
  int marks = 0;

  MemoryNumberingFlag({this.done = false});

  @override
  Future<bool> isDailyNumbering() async => done;

  @override
  Future<void> markDailyNumbering() async {
    marks++;
    done = true;
  }
}

SynthesisOriginNote origin(int id, DateTime at) =>
    SynthesisOriginNote(id: id, formattedSequence: '#01', cleanedText: 'Thought $id', timestamp: at);

SynthesisCluster stored(String id, String label, DateTime start) => SynthesisCluster(
      clusterId: id,
      sequenceNumber: label,
      folder: 'Work',
      synthesizedContent: 'Note $id',
      sessionStart: start,
      sessionEnd: start,
      sessionDuration: Duration.zero,
      originNotes: [origin(id.hashCode, start)],
    );

void main() {
  late SynthesisSessionStore store;
  late MemoryNumberingFlag flag;

  setUp(() {
    store = SynthesisSessionStore();
    flag = MemoryNumberingFlag();
  });

  ProviderContainer launchApp() {
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(NotesRepository()),
      synthesisSessionStoreProvider.overrideWithValue(store),
      sessionNumberingFlagStoreProvider.overrideWithValue(flag),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<SynthesisRepository> hydratedRepo(ProviderContainer c) async {
    final repo = c.read(synthesisRepositoryProvider.notifier);
    await repo.hydrated;
    return repo;
  }

  SynthesisCluster create(SynthesisRepository repo, DateTime at, {int id = 1}) =>
      repo.createSession(folder: 'Work', note: 'Note', origins: [origin(id, at)]);

  group('Daily session numbers', () {
    test('the counter restarts on a new calendar day; the second session of a day is 02', () async {
      final repo = await hydratedRepo(launchApp());

      final a = create(repo, DateTime(2026, 11, 25, 9));
      final b = create(repo, DateTime(2026, 11, 25, 22, 30), id: 2);
      final c = create(repo, DateTime(2026, 11, 26, 0, 5), id: 3);
      final d = create(repo, DateTime(2026, 11, 26, 8), id: 4);

      expect([a, b, c, d].map((s) => s.sequenceNumber), ['#S-01', '#S-02', '#S-01', '#S-02']);
      expect(c.sessionDay, DateTime(2026, 11, 26));
      expect({a.clusterId, b.clusterId, c.clusterId, d.clusterId}.length, 4);
    });

    test('rule: highest number of that day + 1, so a deleted number comes back only when no higher one exists',
        () async {
      final c = launchApp();
      final repo = await hydratedRepo(c);
      final day = DateTime(2026, 11, 26, 9);
      create(repo, day);
      final second = create(repo, day.add(const Duration(hours: 1)), id: 2);
      final third = create(repo, day.add(const Duration(hours: 2)), id: 3);

      await repo.deleteCluster(second.clusterId);
      expect(create(repo, day.add(const Duration(hours: 3)), id: 4).sequenceNumber, '#S-04',
          reason: '03 still exists, so 02 is a gap');

      final s = c.read(synthesisRepositoryProvider);
      await repo.deleteCluster(s.firstWhere((x) => x.sequenceNumber == '#S-04').clusterId);
      await repo.deleteCluster(third.clusterId);
      expect(create(repo, day.add(const Duration(hours: 4)), id: 5).sequenceNumber, '#S-02',
          reason: 'only 01 is left, so 02 is the next number');
    });

    test('a number never changes when an earlier thought of the same day joins the session', () async {
      final c = launchApp();
      final repo = await hydratedRepo(c);
      final first = create(repo, DateTime(2026, 11, 26, 9));
      final second = create(repo, DateTime(2026, 11, 26, 11), id: 2);

      repo.updateSession(second.clusterId, note: 'Rewritten', addedOrigins: [origin(9, DateTime(2026, 11, 26, 8))]);

      final s = c.read(synthesisRepositoryProvider);
      expect(s.firstWhere((x) => x.clusterId == second.clusterId).sequenceNumber, '#S-02');
      expect(s.firstWhere((x) => x.clusterId == first.clusterId).sequenceNumber, '#S-01');
    });

    test('a session split off by ejection gets the next number of its own day', () async {
      final c = launchApp();
      final repo = await hydratedRepo(c);
      repo.createSession(folder: 'Work', note: 'N', origins: [
        origin(1, DateTime(2026, 11, 25, 23, 50)),
        origin(2, DateTime(2026, 11, 26, 0, 10)),
      ]);
      create(repo, DateTime(2026, 11, 26, 9), id: 3);
      final source = c.read(synthesisRepositoryProvider).firstWhere((x) => x.sessionDay == DateTime(2026, 11, 25));

      repo.ejectRawNoteToIndependent(source.clusterId, 2);

      final ejected = c.read(synthesisRepositoryProvider).first;
      expect(ejected.originNotes.single.id, 2);
      expect(ejected.sessionDay, DateTime(2026, 11, 26));
      expect(ejected.sequenceNumber, '#S-02');
    });

    test('stored sessions load newest day first, then highest number first', () async {
      await store.put(stored('a', '#S-01', DateTime(2026, 11, 25, 9)));
      await store.put(stored('b', '#S-01', DateTime(2026, 11, 26, 9)));
      await store.put(stored('c', '#S-02', DateTime(2026, 11, 25, 12)));
      await store.put(stored('d', '#S-02', DateTime(2026, 11, 26, 10)));

      expect((await store.loadAll()).map((s) => s.clusterId), ['d', 'b', 'c', 'a']);
    });
  });

  group('One-time renumbering of sessions numbered before daily numbers', () {
    test('renumbers every stored session per day in order of its start, persists, and sets the flag', () async {
      // Global numbers from before: three days, numbered in creation order, one created out of time order.
      await store.put(stored('a', '#S-01', DateTime(2026, 11, 24, 9)));
      await store.put(stored('b', '#S-02', DateTime(2026, 11, 24, 15)));
      await store.put(stored('c', '#S-04', DateTime(2026, 11, 25, 10)));
      await store.put(stored('d', '#S-03', DateTime(2026, 11, 25, 8)));
      await store.put(stored('e', '#S-05', DateTime(2026, 11, 26, 7)));

      final c = launchApp();
      c.read(synthesisRepositoryProvider);
      await c.read(synthesisRepositoryProvider.notifier).hydrated;

      Map<String, String> labels(List<SynthesisCluster> s) => {for (final x in s) x.clusterId: x.sequenceNumber};
      const expected = {'a': '#S-01', 'b': '#S-02', 'd': '#S-01', 'c': '#S-02', 'e': '#S-01'};
      expect(labels(c.read(synthesisRepositoryProvider)), expected);
      expect(labels(await store.loadAll()), expected, reason: 'persisted');
      expect(flag.done, isTrue);
      expect(flag.marks, 1);
    });

    test('runs once: with the flag set, later launches keep the numbers as they are', () async {
      await store.put(stored('a', '#S-01', DateTime(2026, 11, 24, 9)));
      await store.put(stored('b', '#S-02', DateTime(2026, 11, 25, 9)));

      final first = launchApp();
      first.read(synthesisRepositoryProvider);
      await first.read(synthesisRepositoryProvider.notifier).hydrated;
      expect((await store.loadAll()).map((s) => s.sequenceNumber), ['#S-01', '#S-01']);

      // A label the renumbering would change if it ran again.
      await store.put(stored('x', '#S-07', DateTime(2026, 11, 25, 6)));
      final second = launchApp();
      second.read(synthesisRepositoryProvider);
      await second.read(synthesisRepositoryProvider.notifier).hydrated;

      expect(second.read(synthesisRepositoryProvider).firstWhere((s) => s.clusterId == 'x').sequenceNumber, '#S-07');
      expect(flag.marks, 1);
    });

    test('renumbering is idempotent', () {
      final sessions = [
        stored('a', '#S-03', DateTime(2026, 11, 24, 9)),
        stored('b', '#S-09', DateTime(2026, 11, 24, 8)),
        stored('c', '#S-01', DateTime(2026, 11, 25, 9)),
      ];
      final once = renumberSessionsByDay(sessions);
      final twice = renumberSessionsByDay(once);

      expect(once.map((s) => s.sequenceNumber), ['#S-02', '#S-01', '#S-01']);
      expect(twice.map((s) => s.sequenceNumber), once.map((s) => s.sequenceNumber));
    });

    test('a fresh install sets the flag at once, so its first sessions are never renumbered', () async {
      final c = launchApp();
      await hydratedRepo(c);

      expect(flag.done, isTrue);
    });

    test('the shared-preferences flag round-trips under synthesis.dailyNumbering', () async {
      SharedPreferences.setMockInitialValues({});
      final prefsFlag = SharedPreferencesSessionNumberingFlagStore();
      expect(await prefsFlag.isDailyNumbering(), isFalse);
      await prefsFlag.markDailyNumbering();
      expect(await prefsFlag.isDailyNumbering(), isTrue);
      expect((await SharedPreferences.getInstance()).getBool('synthesis.dailyNumbering'), isTrue);
    });
  });

  group('Session reference label for a thought', () {
    final session = stored('a', '#S-02', DateTime(2026, 11, 23, 23, 50));

    test('the plain label when the session is from the day the thought was captured', () {
      expect(sessionReferenceLabel(session, relativeTo: DateTime(2026, 11, 23, 23, 55)), '#S-02');
    });

    test('the label with the session day when the thought is from another day', () {
      expect(sessionReferenceLabel(session, relativeTo: DateTime(2026, 11, 24, 0, 10)), '#S-02 · 23/11');
    });

    test('day and month use the thought timestamp convention', () {
      expect(formatDayMonth(DateTime(2026, 3, 4)), '04/03');
      expect(formatThoughtTimestamp(DateTime(2026, 3, 4, 14, 37)), startsWith(formatDayMonth(DateTime(2026, 3, 4))));
    });
  });

  group('Looking up the session of a thought', () {
    test('sessionOfThought returns the session holding the thought, or null', () async {
      final c = launchApp();
      final repo = await hydratedRepo(c);
      final s = create(repo, DateTime(2026, 11, 26, 9), id: 7);

      expect(repo.sessionOfThought(7)?.clusterId, s.clusterId);
      expect(repo.sessionOfThought(8), isNull);
    });
  });
}
