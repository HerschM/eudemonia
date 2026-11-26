import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/database/app_database.dart';

/// Whether the stored sessions' styles were already reset to organised. Before styles were
/// really applied, a chosen style was only stored, never written, and every session carried
/// `concise` as its default; the one-time reset makes the stored style match the note again.
abstract class StyleResetFlagStore {
  Future<bool> isStylesApplied();
  Future<void> markStylesApplied();
}

class SharedPreferencesStyleResetFlagStore implements StyleResetFlagStore {
  static const _key = 'synthesis.stylesApplied';

  @override
  Future<bool> isStylesApplied() async => (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> markStylesApplied() async => (await SharedPreferences.getInstance()).setBool(_key, true);
}

class InMemoryStyleResetFlagStore implements StyleResetFlagStore {
  bool _done;

  InMemoryStyleResetFlagStore({this._done = false});

  @override
  Future<bool> isStylesApplied() async => _done;

  @override
  Future<void> markStylesApplied() async => _done = true;
}

/// The flag describes the session database. Without one (isolated tests) the sessions live in
/// memory and none can date from before styles were applied, so the flag starts set.
final styleResetFlagStoreProvider = Provider<StyleResetFlagStore>((ref) {
  return ref.watch(appDatabaseProvider) == null
      ? InMemoryStyleResetFlagStore(done: true)
      : SharedPreferencesStyleResetFlagStore();
});
