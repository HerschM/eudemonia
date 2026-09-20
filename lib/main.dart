import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/home_screen.dart';
import 'features/theme/app_theme.dart';
import 'features/notes/data/notes_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create a provider container to initialize async dependencies
  final container = ProviderContainer();
  await container.read(notesRepositoryProvider).init();

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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
