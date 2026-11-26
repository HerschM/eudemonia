import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/database/app_database.dart';

/// Whether the stored sessions already carry daily `#S-NN` numbers, so the one-time
/// renumbering of sessions numbered globally (before daily numbers) runs only once.
abstract class SessionNumberingFlagStore {
  Future<bool> isDailyNumbering();
  Future<void> markDailyNumbering();
}

class SharedPreferencesSessionNumberingFlagStore implements SessionNumberingFlagStore {
  static const _key = 'synthesis.dailyNumbering';

  @override
  Future<bool> isDailyNumbering() async => (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> markDailyNumbering() async => (await SharedPreferences.getInstance()).setBool(_key, true);
}

class InMemorySessionNumberingFlagStore implements SessionNumberingFlagStore {
  bool _done = false;

  @override
  Future<bool> isDailyNumbering() async => _done;

  @override
  Future<void> markDailyNumbering() async => _done = true;
}

/// The flag describes the session database, so it lives where the sessions live: in memory
/// when there is no database (isolated tests), like [SynthesisSessionStore]'s fallback.
final sessionNumberingFlagStoreProvider = Provider<SessionNumberingFlagStore>((ref) {
  return ref.watch(appDatabaseProvider) == null
      ? InMemorySessionNumberingFlagStore()
      : SharedPreferencesSessionNumberingFlagStore();
});
