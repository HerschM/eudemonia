import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/ai_processing/audio_queue_service.dart';
import 'features/capture/capture_controller.dart';
import 'features/home/main_navigation_shell.dart';
import 'features/synthesis/application/synthesis_trigger_controller.dart';
import 'features/theme/app_theme.dart';
import 'core/database/app_database.dart';

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

  // Automatic synthesis (FR11.8): thoughts left from the previous session may already meet a trigger.
  unawaited(container.read(synthesisTriggerControllerProvider).start());

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
