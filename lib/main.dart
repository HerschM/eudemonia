import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/ai_processing/audio_queue_service.dart';
import 'features/capture/capture_controller.dart';
import 'features/home/main_navigation_shell.dart';
import 'features/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/app_database.dart';
import 'core/logger/app_logger.dart';
import 'features/synthesis/data/synthesis_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One database instance backs every repository.
  final database = await openAppDatabase();
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );

  // Capture triggers must be handled even before any screen is mounted.
  container.read(captureControllerProvider);

  // Hydrate the audio queue and finish whatever the previous session left behind.
  unawaited(container.read(audioQueueServiceProvider).resumePendingWork());

  unawaited(_recoverOrphanedThoughtsOnce(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EudemoniaApp(),
    ),
  );
}

/// One-time repair: before synthesis sessions were persisted, a restart lost the
/// sessions but left their thoughts marked as synthesized. Hand those back for clustering.
Future<void> _recoverOrphanedThoughtsOnce(ProviderContainer container) async {
  const doneKey = 'synthesis_orphan_recovery_done';
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(doneKey) ?? false) return;
    final recovered = await container
        .read(synthesisRepositoryProvider.notifier)
        .recoverOrphanedSynthesizedNotes();
    await prefs.setBool(doneKey, true);
    if (recovered > 0) {
      container.read(appLoggerProvider).info(
          '[Synthesis] Returned $recovered orphaned thought(s) to the clustering buffer.');
    }
  } catch (e, stack) {
    container.read(appLoggerProvider).error(
        '[Synthesis] Orphaned thought recovery failed', error: e, stackTrace: stack);
  }
}

class EudemoniaApp extends StatelessWidget {
  const EudemoniaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eudemonia',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainNavigationShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
