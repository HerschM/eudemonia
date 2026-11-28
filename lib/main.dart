import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/ai_processing/audio_queue_service.dart';
import 'features/capture/capture_controller.dart';
import 'features/capture/capture_inbox_ingestor.dart';
import 'features/capture/capture_resume_scanner.dart';
import 'features/capture/recording_retention.dart';
import 'features/capture/recording_retention_settings.dart';
import 'features/home/main_navigation_shell.dart';
import 'features/models/application/model_library_controller.dart';
import 'features/notes/application/read_state_migration.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/settings/model_credits.dart';
import 'features/synthesis/application/synthesis_trigger_controller.dart';
import 'features/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/logger/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerModelCredits();

  // One database instance backs every repository.
  final database = await openAppDatabase();
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );

  // Native capture events must be handled even before any screen is mounted.
  container.read(captureControllerProvider);
  final captureSync = container.read(captureControllerProvider.notifier).startupSync;

  // Recordings saved while the app was in the background are ingested on return to the foreground.
  CaptureResumeScanner(
    onResumed: () => container.read(captureInboxIngestorProvider).ingestPending(),
  ).start();

  // Model downloads go on while the app is away; read their state again on return (FR16.1).
  container.read(modelLibraryControllerProvider);
  CaptureResumeScanner(
    onResumed: () => container.read(modelLibraryControllerProvider.notifier).refresh(),
  ).start();

  // Hydrate the audio queue and finish whatever the previous session left behind. Runs after the
  // inbox scan so a recording whose file is still being moved into place is never transcribed early.
  unawaited(captureSync.then((_) => container.read(audioQueueServiceProvider).resumePendingWork()));

  // "Keep original recordings": audio older than the chosen period is removed, once after the
  // queue is loaded (so a recording it still holds is known) and then at most once a day when the
  // app returns to the foreground. All file work is awaited off the first frame; it never throws.
  Future<void> sweepOldRecordings() async {
    try {
      await container.read(recordingRetentionProvider.notifier).ready;
      await container
          .read(recordingRetentionServiceProvider)
          .sweepIfDue(container.read(recordingRetentionProvider));
    } catch (e) {
      container.read(appLoggerProvider).warning('[Recordings] Sweep of old recordings failed: $e');
    }
  }

  unawaited(
    captureSync
        .then((_) => container.read(audioQueueServiceProvider).loadFromStorage())
        .then((_) => sweepOldRecordings()),
  );
  CaptureResumeScanner(onResumed: sweepOldRecordings).start();

  // Automatic synthesis (FR11.8): thoughts left from the previous session may already meet a trigger.
  // It starts after the one-time read-state migration, so a thought it synthesizes is never taken
  // for an old one; the migration never blocks startup and never throws.
  unawaited(
    migrateReadFollowsViewing(
      container.read(notesRepositoryProvider),
      logger: container.read(appLoggerProvider),
    ).then((_) => container.read(synthesisTriggerControllerProvider).start()),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EudemoniaApp(),
    ),
  );
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
