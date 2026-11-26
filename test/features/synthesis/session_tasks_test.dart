import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _note = '**Next steps**\n\n- [ ] Email Daniel.\n- [ ] Decide by the 10th.';

SynthesisCluster session({bool unread = false, bool reprocessing = false, String style = 'actionable'}) =>
    SynthesisCluster(
      clusterId: 's1',
      sequenceNumber: '#S-01',
      folder: 'Work',
      synthesizedContent: _note,
      sessionStart: DateTime(2026, 11, 26, 9),
      sessionEnd: DateTime(2026, 11, 26, 9),
      sessionDuration: Duration.zero,
      originNotes: [
        SynthesisOriginNote(id: 1, formattedSequence: '#01', cleanedText: 'T', timestamp: DateTime(2026, 11, 26, 9)),
      ],
      appliedStyleId: style,
      isUnread: unread,
      isReprocessing: reprocessing,
    );

void main() {
  late SynthesisSessionStore store;

  setUp(() => store = SynthesisSessionStore());

  Future<SynthesisRepository> launch() async {
    final c = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(NotesRepository()),
      synthesisSessionStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(c.dispose);
    c.read(synthesisRepositoryProvider);
    final repo = c.read(synthesisRepositoryProvider.notifier);
    await repo.hydrated;
    return repo;
  }

  test('ticking a task rewrites only its marker and persists it, without marking the note unread or flagging it',
      () async {
    await store.put(session());
    final repo = await launch();

    repo.setTaskChecked('s1', 1, true);
    await repo.pendingWrites;

    final s = repo.sessionById('s1')!;
    expect(s.synthesizedContent, '**Next steps**\n\n- [ ] Email Daniel.\n- [x] Decide by the 10th.');
    expect(s.isUnread, isFalse);
    expect(s.isReprocessing, isFalse);
    expect(s.appliedStyleId, 'actionable');
    expect((await store.loadAll()).single.synthesizedContent, s.synthesizedContent);

    repo.setTaskChecked('s1', 1, false);
    expect(repo.sessionById('s1')!.synthesizedContent, _note);
  });

  test('keeps an unread note unread and a flagged note flagged', () async {
    await store.put(session(unread: true, reprocessing: true));
    final repo = await launch();

    repo.setTaskChecked('s1', 0, true);

    final s = repo.sessionById('s1')!;
    expect(s.synthesizedContent, contains('- [x] Email Daniel.'));
    expect(s.isUnread, isTrue);
    expect(s.isReprocessing, isTrue);
  });

  test('ticking a task is not a hand edit: the style stays, also on a note already edited by hand', () async {
    await store.put(session(style: 'organised'));
    final repo = await launch();

    repo.setTaskChecked('s1', 0, true);
    expect(repo.sessionById('s1')!.appliedStyleId, 'organised');
    expect(repo.sessionById('s1')!.isHandEdited, isFalse);
    await repo.pendingWrites;

    await store.put(session(style: manualStyleId));
    final again = await launch();
    again.setTaskChecked('s1', 0, true);
    expect(again.sessionById('s1')!.appliedStyleId, manualStyleId);
    expect(again.sessionById('s1')!.isHandEdited, isTrue);
  });

  test('an out-of-range task or an unknown session changes nothing', () async {
    await store.put(session());
    final repo = await launch();
    final before = repo.sessionById('s1');

    repo.setTaskChecked('s1', 5, true);
    repo.setTaskChecked('nope', 0, true);

    expect(identical(repo.sessionById('s1'), before), isTrue);
  });
}
