import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/style_reset_flag_store.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts how often the one-time style reset sets its flag.
class MemoryStyleFlag implements StyleResetFlagStore {
  bool done;
  int marks = 0;

  MemoryStyleFlag({this.done = false});

  @override
  Future<bool> isStylesApplied() async => done;

  @override
  Future<void> markStylesApplied() async {
    marks++;
    done = true;
  }
}

SynthesisCluster stored(String id, String style, {bool reprocessing = false, int hour = 9}) => SynthesisCluster(
      clusterId: id,
      sequenceNumber: '#S-0$hour',
      folder: 'Work',
      synthesizedContent: 'Note $id',
      sessionStart: DateTime(2026, 11, 25, hour),
      sessionEnd: DateTime(2026, 11, 25, hour),
      sessionDuration: Duration.zero,
      originNotes: [
        SynthesisOriginNote(id: hour, formattedSequence: '#01', cleanedText: 'T', timestamp: DateTime(2026, 11, 25, hour)),
      ],
      appliedStyleId: style,
      isReprocessing: reprocessing,
    );

void main() {
  late SynthesisSessionStore store;
  late MemoryStyleFlag flag;

  setUp(() {
    store = SynthesisSessionStore();
    flag = MemoryStyleFlag();
  });

  ProviderContainer launchApp() {
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(NotesRepository()),
      synthesisSessionStoreProvider.overrideWithValue(store),
      styleResetFlagStoreProvider.overrideWithValue(flag),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<List<SynthesisCluster>> hydrated(ProviderContainer c) async {
    c.read(synthesisRepositoryProvider);
    await c.read(synthesisRepositoryProvider.notifier).hydrated;
    return c.read(synthesisRepositoryProvider);
  }

  test('a new session defaults to the organised style', () {
    expect(stored('a', 'organised').copyWith().appliedStyleId, 'organised');
    final fresh = SynthesisCluster(
      clusterId: 'x',
      sequenceNumber: '#S-01',
      folder: 'Work',
      synthesizedContent: '',
      sessionStart: DateTime(2026),
      sessionEnd: DateTime(2026),
      sessionDuration: Duration.zero,
      originNotes: const [],
    );
    expect(fresh.appliedStyleId, 'organised');
  });

  test('once: every stored session is set to organised, persisted, and the flag is set; flags are left alone',
      () async {
    await store.put(stored('a', 'concise', hour: 1));
    await store.put(stored('b', 'bullets', reprocessing: true, hour: 2));
    await store.put(stored('c', 'organised', reprocessing: true, hour: 3));

    final sessions = await hydrated(launchApp());

    expect({for (final s in sessions) s.clusterId: s.appliedStyleId}, {'a': 'organised', 'b': 'organised', 'c': 'organised'});
    // A flag may come from a deleted or edited thought: it is never cleared here.
    expect({for (final s in sessions) s.clusterId: s.isReprocessing}, {'a': false, 'b': true, 'c': true});
    expect((await store.loadAll()).map((s) => s.appliedStyleId).toSet(), {'organised'}, reason: 'persisted');
    expect(flag.marks, 1);
  });

  test('runs once: with the flag set, a chosen style survives later launches', () async {
    await store.put(stored('a', 'concise'));
    await hydrated(launchApp());

    await store.put(stored('b', 'journal', hour: 4));
    final sessions = await hydrated(launchApp());

    expect(sessions.firstWhere((s) => s.clusterId == 'b').appliedStyleId, 'journal');
    expect(flag.marks, 1);
  });

  test('a fresh install sets the flag at once', () async {
    await hydrated(launchApp());
    expect(flag.done, isTrue);
  });

  test('without a database there is nothing from before styles were applied: the in-memory flag starts set', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(styleResetFlagStoreProvider).isStylesApplied(), isTrue);
    expect(await InMemoryStyleResetFlagStore().isStylesApplied(), isFalse);
  });

  test('the shared-preferences flag round-trips under synthesis.stylesApplied', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesStyleResetFlagStore();
    expect(await prefs.isStylesApplied(), isFalse);
    await prefs.markStylesApplied();
    expect(await prefs.isStylesApplied(), isTrue);
    expect((await SharedPreferences.getInstance()).getBool('synthesis.stylesApplied'), isTrue);
  });
}
