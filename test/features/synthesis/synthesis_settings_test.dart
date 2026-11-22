import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySettingsStore implements SynthesisSettingsStore {
  SynthesisSettings? stored;
  MemorySettingsStore([this.stored]);

  @override
  Future<SynthesisSettings?> load() async => stored;

  @override
  Future<void> save(SynthesisSettings settings) async => stored = settings;
}

void main() {
  ProviderContainer launch(SynthesisSettingsStore store) {
    final c = ProviderContainer(overrides: [synthesisSettingsStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    return c;
  }

  test('defaults are 3 thoughts and 15 minutes', () {
    final c = launch(MemorySettingsStore());
    expect(c.read(synthesisSettingsProvider).noteThreshold, 3);
    expect(c.read(synthesisSettingsProvider).inactivityMinutes, 15);
  });

  test('changes are saved and restored on the next launch', () async {
    final store = MemorySettingsStore();
    final first = launch(store);
    first.read(synthesisSettingsProvider.notifier).setNoteThreshold(5);
    first.read(synthesisSettingsProvider.notifier).setInactivityMinutes(30);
    await pumpEventQueue();

    final second = launch(store);
    second.read(synthesisSettingsProvider);
    await pumpEventQueue();
    expect(second.read(synthesisSettingsProvider).noteThreshold, 5);
    expect(second.read(synthesisSettingsProvider).inactivityMinutes, 30);
  });

  test('values are kept within the allowed ranges', () {
    final c = launch(MemorySettingsStore());
    c.read(synthesisSettingsProvider.notifier).setNoteThreshold(40);
    c.read(synthesisSettingsProvider.notifier).setInactivityMinutes(1);
    expect(c.read(synthesisSettingsProvider).noteThreshold, 10);
    expect(c.read(synthesisSettingsProvider).inactivityMinutes, 5);
  });

  test('the shared-preferences store round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesSynthesisSettingsStore();
    expect(await store.load(), isNull);
    await store.save(const SynthesisSettings(noteThreshold: 8, inactivityMinutes: 45));
    final loaded = await store.load();
    expect(loaded!.noteThreshold, 8);
    expect(loaded.inactivityMinutes, 45);
  });
}
