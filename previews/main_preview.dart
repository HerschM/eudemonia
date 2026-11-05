import 'package:flutter/material.dart';
import 'gallery_shell.dart';
import 'preview_theme.dart';

/// Standalone launcher for isolated UI/UX component sandbox.
/// Run via:
/// flutter run -t previews/main_preview.dart -d macos (or chrome/emulator)
void main() {
  runApp(const EudemoniaPreviewApp());
}

class EudemoniaPreviewApp extends StatelessWidget {
  const EudemoniaPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eudemonia — 4-Stage Architecture Preview',
      debugShowCheckedModeBanner: false,
      theme: PreviewTheme.darkTheme,
      home: const GalleryShell(),
    );
  }
}

