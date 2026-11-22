// Development tool, not a test of behaviour: writes every synthesis session to a Markdown file in
// the app's external files folder, then deletes the sessions so their thoughts return to Capture
// and the next synthesis run writes them again (used when the language model changes).
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export all synthesis sessions, then delete them', (tester) async {
    final database = await openAppDatabase();
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(database)]);
    addTearDown(container.dispose);

    final repository = container.read(synthesisRepositoryProvider.notifier);
    await repository.hydrated;
    final sessions = [...container.read(synthesisRepositoryProvider)];

    final out = StringBuffer('# Synthesis sessions before reset\n');
    for (final s in sessions) {
      out.write('\n---\n\n## ${s.sequenceNumber} [${s.folder}] ${s.sessionStart} '
          '(${s.originNotes.length} thoughts)\n\n${s.synthesizedContent}\n');
    }
    final dir = (await getExternalStorageDirectory())!;
    await File('${dir.path}/synthesis_export_before_reset.md').writeAsString(out.toString(), flush: true);

    for (final s in sessions) {
      await repository.deleteCluster(s.clusterId);
    }
    await repository.pendingWrites;

    expect(container.read(synthesisRepositoryProvider), isEmpty);
    // ignore: avoid_print
    print('SYN_RESET|exported and deleted ${sessions.length} session(s)');
  });
}
