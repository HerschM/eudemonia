// Development tool, not a test of behaviour: writes every synthesis session, with the raw
// thoughts it was written from, to a Markdown file in the app's external files folder. With
// SYN_RESET_DELETE it then deletes sessions so their thoughts return to Capture and the next
// synthesis run writes them again (used when the language model or a prompt changes).
//
//   --dart-define=SYN_RESET_DELETE=all      deletes every session
//   --dart-define=SYN_RESET_DELETE=#S-01    deletes only that session
//
// Run with `flutter drive --keep-app-running` as described in test_driver/integration_test.dart,
// then reinstall the normal build. The export contains the user's notes: keep it out of git.
import 'dart:io';

import 'package:eudemonia/core/database/app_database.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _delete = String.fromEnvironment('SYN_RESET_DELETE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export all synthesis sessions, optionally delete them', (tester) async {
    final database = await openAppDatabase();
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(database)]);
    addTearDown(container.dispose);

    final repository = container.read(synthesisRepositoryProvider.notifier);
    await repository.hydrated;
    final sessions = [...container.read(synthesisRepositoryProvider)];

    final out = StringBuffer('# Synthesis sessions\n');
    for (final s in sessions) {
      out.write('\n---\n\n## ${s.sequenceNumber} [${s.folder}] ${s.sessionStart} '
          '(${s.originNotes.length} thoughts)\n\n${s.synthesizedContent}\n\n### Raw thoughts\n');
      for (final o in s.originNotes) {
        out.write('\n[${o.id}] ${o.timestamp}\n${o.cleanedText}\n');
      }
    }
    final dir = (await getExternalStorageDirectory())!;
    await File('${dir.path}/synthesis_export.md').writeAsString(out.toString(), flush: true);

    final doomed = [
      for (final s in sessions)
        if (_delete == 'all' || s.sequenceNumber == _delete) s,
    ];
    for (final s in doomed) {
      await repository.deleteCluster(s.clusterId);
    }
    await repository.pendingWrites;

    expect(container.read(synthesisRepositoryProvider).length, sessions.length - doomed.length);
    // ignore: avoid_print
    print('SYN_RESET|exported ${sessions.length} session(s), deleted ${doomed.length}');
  });
}
