import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryFolderStore implements FolderStore {
  List<FolderDefinition>? stored;
  int saves = 0;

  MemoryFolderStore([this.stored]);

  @override
  Future<List<FolderDefinition>?> load() async => stored;

  @override
  Future<void> save(List<FolderDefinition> folders) async {
    saves++;
    stored = List.of(folders);
  }
}

List<String> names(List<FolderDefinition> folders) => [for (final f in folders) f.name];

void main() {
  late MemoryFolderStore store;
  late SynthesisSessionStore sessionStore;

  setUp(() {
    store = MemoryFolderStore();
    sessionStore = SynthesisSessionStore();
  });

  ProviderContainer launch() {
    final c = ProviderContainer(overrides: [
      folderStoreProvider.overrideWithValue(store),
      notesRepositoryProvider.overrideWithValue(NotesRepository()),
      synthesisSessionStoreProvider.overrideWithValue(sessionStore),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<FolderSettingsNotifier> loaded(ProviderContainer c) async {
    final n = c.read(foldersProvider.notifier);
    await n.loaded;
    return n;
  }

  test('starts with the default folders, Uncategorized last', () async {
    final c = launch();
    expect(names(c.read(foldersProvider)), ['Work', 'Personal', 'Journal', 'Uncategorized']);
    await loaded(c);
    expect(c.read(foldersProvider).map((f) => f.description), defaultFolders.map((f) => f.description));
  });

  test('changes are saved and restored on the next launch', () async {
    final first = launch();
    final n = await loaded(first);
    expect(await n.add('Garden', 'plants, the allotment, seeds.'), FolderChange.done);
    expect(await n.updateDescription('Work', 'the day job.'), FolderChange.done);

    final second = launch();
    await loaded(second);
    final restored = second.read(foldersProvider);
    expect(names(restored), ['Work', 'Personal', 'Journal', 'Garden', 'Uncategorized']);
    expect(restored.firstWhere((f) => f.name == 'Garden').description, 'plants, the allotment, seeds.');
    expect(restored.firstWhere((f) => f.name == 'Work').description, 'the day job.');
  });

  test('the shared-preferences store round-trips names and descriptions under synthesis.folders', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPreferencesFolderStore();
    expect(await prefs.load(), isNull);
    const folders = [
      FolderDefinition(name: "Kid's \"Big\" Plans", description: 'school, sport: weekends.'),
      FolderDefinition(name: 'Uncategorized', description: 'none.'),
    ];
    await prefs.save(folders);
    final back = await prefs.load();
    expect(names(back!), names(folders));
    expect(back.first.description, 'school, sport: weekends.');
    expect((await SharedPreferences.getInstance()).getString('synthesis.folders'), isNotNull);
  });

  group('default style', () {
    test('every folder starts organised', () async {
      final c = launch();
      await loaded(c);
      expect(c.read(foldersProvider).map((f) => f.defaultStyleId).toSet(), {'organised'});
      expect(const FolderDefinition(name: 'X', description: 'x').defaultStyleId, 'organised');
    });

    test('the shared-preferences store round-trips the style; legacy JSON without it and unknown ids load organised',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = SharedPreferencesFolderStore();
      await prefs.save(const [
        FolderDefinition(name: 'Diary', description: 'd', defaultStyleId: 'journal'),
        FolderDefinition(name: 'Uncategorized', description: 'u', defaultStyleId: 'bullets'),
      ]);
      expect((await prefs.load())!.map((f) => f.defaultStyleId), ['journal', 'bullets']);

      SharedPreferences.setMockInitialValues({
        'synthesis.folders': '[{"name":"Old","description":"o"},'
            '{"name":"Odd","description":"x","defaultStyleId":"no-such-style"},'
            '{"name":"Hand","description":"h","defaultStyleId":"manual"},'
            '{"name":"Num","description":"n","defaultStyleId":3}]',
      });
      final legacy = await SharedPreferencesFolderStore().load();
      expect(names(legacy!), ['Old', 'Odd', 'Hand', 'Num']);
      expect(legacy.map((f) => f.defaultStyleId).toSet(), {'organised'});
    });

    test('updateDefaultStyle changes any folder, Uncategorized included, and is restored on the next launch',
        () async {
      final first = launch();
      final n = await loaded(first);
      expect(await n.updateDefaultStyle('Journal', 'journal'), FolderChange.done);
      expect(await n.updateDefaultStyle('Uncategorized', 'bullets'), FolderChange.done);
      expect(first.read(foldersProvider).last.name, 'Uncategorized');
      expect(first.read(foldersProvider).last.description, defaultFolders.last.description);

      final second = launch();
      await loaded(second);
      expect({for (final f in second.read(foldersProvider)) f.name: f.defaultStyleId},
          {'Work': 'organised', 'Personal': 'organised', 'Journal': 'journal', 'Uncategorized': 'bullets'});
    });

    test('updateDefaultStyle refuses an id that is not a selectable style, and an unknown folder', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.updateDefaultStyle('Work', 'no-such-style'), FolderChange.styleUnknown);
      expect(await n.updateDefaultStyle('Work', 'manual'), FolderChange.styleUnknown);
      expect(await n.updateDefaultStyle('Nope', 'journal'), FolderChange.notFound);
      expect(c.read(foldersProvider).first.defaultStyleId, 'organised');
    });

    test('add takes a default style; an unknown one is refused', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('Garden', 'plants.', defaultStyleId: 'casual'), FolderChange.done);
      expect(await n.add('Ideas', 'ideas.', defaultStyleId: 'manual'), FolderChange.styleUnknown);
      expect(c.read(foldersProvider).firstWhere((f) => f.name == 'Garden').defaultStyleId, 'casual');
      expect(names(c.read(foldersProvider)), isNot(contains('Ideas')));
    });

    test('rename and a new description keep the default style', () async {
      final c = launch();
      final n = await loaded(c);
      await n.updateDefaultStyle('Journal', 'journal');
      expect(await n.rename('Journal', 'Diary'), FolderChange.done);
      expect(await n.updateDescription('Diary', 'moods.'), FolderChange.done);
      expect(c.read(foldersProvider).firstWhere((f) => f.name == 'Diary').defaultStyleId, 'journal');
    });

    test('a stored list keeps each style, Uncategorized\'s too, and reads unknown ones as organised', () async {
      store.stored = const [
        FolderDefinition(name: 'Garden', description: 'plants.', defaultStyleId: 'actionable'),
        FolderDefinition(name: 'Odd', description: 'x', defaultStyleId: 'no-such-style'),
        FolderDefinition(name: 'Uncategorized', description: 'edited elsewhere.', defaultStyleId: 'concise'),
      ];
      final c = launch();
      await loaded(c);
      expect({for (final f in c.read(foldersProvider)) f.name: f.defaultStyleId},
          {'Garden': 'actionable', 'Odd': 'organised', 'Uncategorized': 'concise'});
      expect(c.read(foldersProvider).last.description, defaultFolders.last.description);
    });

    test('removing or renaming a folder does not restyle its sessions', () async {
      SynthesisCluster s(String id, String folder, String style) => SynthesisCluster(
            clusterId: id,
            sequenceNumber: '#S-01',
            folder: folder,
            synthesizedContent: 'Note',
            sessionStart: DateTime(2026, 11, 26, 9),
            sessionEnd: DateTime(2026, 11, 26, 9),
            sessionDuration: Duration.zero,
            originNotes: [
              SynthesisOriginNote(id: id.hashCode, formattedSequence: '#01', cleanedText: 't', timestamp: DateTime(2026, 11, 26, 9)),
            ],
            appliedStyleId: style,
          );
      await sessionStore.put(s('w', 'Work', 'journal'));
      await sessionStore.put(s('p', 'Personal', 'organised'));
      final c = launch();
      final n = await loaded(c);
      await n.updateDefaultStyle('Uncategorized', 'bullets');
      await n.updateDefaultStyle('Journal', 'casual');

      expect(await n.remove('Work'), FolderChange.done);
      expect(await n.rename('Personal', 'Journal 2'), FolderChange.done);

      final sessions = {for (final x in c.read(synthesisRepositoryProvider)) x.clusterId: x};
      expect(sessions['w']!.folder, 'Uncategorized');
      expect(sessions['w']!.appliedStyleId, 'journal');
      expect(sessions['w']!.isReprocessing, isFalse);
      expect(sessions['p']!.folder, 'Journal 2');
      expect(sessions['p']!.appliedStyleId, 'organised');
      expect(sessions['p']!.isReprocessing, isFalse);
    });
  });

  group('add', () {
    test('trims the name and description and inserts before Uncategorized', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('  Side   project ', '  evenings.  '), FolderChange.done);
      expect(names(c.read(foldersProvider)), ['Work', 'Personal', 'Journal', 'Side project', 'Uncategorized']);
      expect(c.read(foldersProvider)[3].description, 'evenings.');
      expect(store.stored, isNotNull);
    });

    test('an empty description becomes a neutral default', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('Garden', '   '), FolderChange.done);
      expect(c.read(foldersProvider).firstWhere((f) => f.name == 'Garden').description, 'Thoughts about Garden.');
    });

    test('a name must be 1 to 24 characters', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('   ', 'x'), FolderChange.nameEmpty);
      expect(await n.add('A' * 25, 'x'), FolderChange.nameTooLong);
      expect(await n.add('A' * 24, 'x'), FolderChange.done);
      expect(await n.add('B', 'x'), FolderChange.done);
    });

    test('a name must be unique ignoring case, Uncategorized included', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('work', 'x'), FolderChange.nameTaken);
      expect(await n.add('UNCATEGORIZED', 'x'), FolderChange.nameTaken);
      expect(names(c.read(foldersProvider)), names(defaultFolders));
    });

    test('a name cannot hold control characters', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('Bad\u0007name', 'x'), FolderChange.nameInvalid);
    });

    test('a description may be at most 200 characters', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.add('Long', 'd' * 201), FolderChange.descriptionTooLong);
      expect(await n.add('Long', 'd' * 200), FolderChange.done);
    });

    test('at most 12 folders in total', () async {
      final c = launch();
      final n = await loaded(c);
      for (var i = 0; i < 8; i++) {
        expect(await n.add('Extra $i', ''), FolderChange.done);
      }
      expect(c.read(foldersProvider).length, 12);
      expect(await n.add('One too many', ''), FolderChange.tooManyFolders);
      expect(c.read(foldersProvider).last.name, 'Uncategorized');
    });
  });

  group('updateDescription', () {
    test('changes any folder except Uncategorized and validates the description', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.updateDescription('Journal', ' moods. '), FolderChange.done);
      expect(c.read(foldersProvider).firstWhere((f) => f.name == 'Journal').description, 'moods.');
      expect(await n.updateDescription('Journal', 'd' * 201), FolderChange.descriptionTooLong);
      expect(await n.updateDescription('Uncategorized', 'anything'), FolderChange.protectedFolder);
      expect(await n.updateDescription('Nope', 'x'), FolderChange.notFound);
    });
  });

  group('rename and remove move the stored sessions', () {
    SynthesisCluster session(String id, String folder) => SynthesisCluster(
          clusterId: id,
          sequenceNumber: '#S-01',
          folder: folder,
          synthesizedContent: 'Note',
          sessionStart: DateTime(2026, 11, 26, 9),
          sessionEnd: DateTime(2026, 11, 26, 9),
          sessionDuration: Duration.zero,
          originNotes: [
            SynthesisOriginNote(id: id.hashCode, formattedSequence: '#01', cleanedText: 't', timestamp: DateTime(2026, 11, 26, 9)),
          ],
        );

    Map<String, String> foldersOf(ProviderContainer c) =>
        {for (final s in c.read(synthesisRepositoryProvider)) s.clusterId: s.folder};

    test('rename changes the folder and every session filed under it, keeping its place', () async {
      await sessionStore.put(session('w', 'Work'));
      await sessionStore.put(session('p', 'Personal'));
      final c = launch();
      final n = await loaded(c);

      expect(await n.rename('Work', 'Job'), FolderChange.done);

      expect(names(c.read(foldersProvider)), ['Job', 'Personal', 'Journal', 'Uncategorized']);
      expect(foldersOf(c), {'w': 'Job', 'p': 'Personal'});
      await c.read(synthesisRepositoryProvider.notifier).pendingWrites;
      expect({for (final s in await sessionStore.loadAll()) s.clusterId: s.folder}, {'w': 'Job', 'p': 'Personal'});
    });

    test('rename validates the new name', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.rename('Work', 'personal'), FolderChange.nameTaken);
      expect(await n.rename('Work', ''), FolderChange.nameEmpty);
      expect(await n.rename('Work', 'W' * 25), FolderChange.nameTooLong);
      expect(await n.rename('Nope', 'X'), FolderChange.notFound);
      expect(await n.rename('Work', 'WORK'), FolderChange.done, reason: 'its own name in another case');
      expect(names(c.read(foldersProvider)).first, 'WORK');
    });

    test('remove deletes the folder and moves its sessions to Uncategorized', () async {
      await sessionStore.put(session('w', 'Work'));
      await sessionStore.put(session('j', 'Journal'));
      final c = launch();
      final n = await loaded(c);

      expect(await n.remove('Work'), FolderChange.done);

      expect(names(c.read(foldersProvider)), ['Personal', 'Journal', 'Uncategorized']);
      expect(foldersOf(c), {'w': 'Uncategorized', 'j': 'Journal'});
      expect(await n.remove('Work'), FolderChange.notFound);
    });

    test('Uncategorized cannot be renamed or removed and stays last', () async {
      final c = launch();
      final n = await loaded(c);
      expect(await n.rename('Uncategorized', 'Misc'), FolderChange.protectedFolder);
      expect(await n.remove('Uncategorized'), FolderChange.protectedFolder);
      await n.add('Garden', '');
      expect(c.read(foldersProvider).last.name, 'Uncategorized');
    });
  });

  test('a stored list without Uncategorized, or with it in the middle, loads with it last', () async {
    store.stored = const [
      FolderDefinition(name: 'Uncategorized', description: 'edited elsewhere.'),
      FolderDefinition(name: 'Garden', description: 'plants.'),
    ];
    final c = launch();
    await loaded(c);
    expect(names(c.read(foldersProvider)), ['Garden', 'Uncategorized']);
    expect(c.read(foldersProvider).last.description, defaultFolders.last.description);

    store.stored = const [FolderDefinition(name: 'Garden', description: 'plants.')];
    final d = launch();
    await loaded(d);
    expect(names(d.read(foldersProvider)), ['Garden', 'Uncategorized']);
  });
}
