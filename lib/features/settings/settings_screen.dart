import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'background_permission_service.dart';
import 'presentation/capture_section.dart';
import 'presentation/folders_section.dart';
import 'presentation/licences_link.dart';
import 'presentation/models_section.dart';
import 'presentation/notes_view_section.dart';
import 'presentation/permissions_section.dart';
import 'presentation/phone_memory_section.dart';
import 'presentation/synthesis_section.dart';

/// Settings, most-used first: folders, automatic synthesis, the notes view, models and capture, then the
/// collapsed phone-memory and permissions sections, and the licences link at the very end.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(backgroundPermissionStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('settings_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: const [
          FoldersSection(),
          SizedBox(height: 20),
          AutomaticSynthesisSection(),
          SizedBox(height: 20),
          NotesViewSection(),
          SizedBox(height: 20),
          OnDeviceModelsSection(),
          SizedBox(height: 20),
          CaptureSection(),
          SizedBox(height: 20),
          PhoneMemorySection(),
          SizedBox(height: 12),
          PermissionsSection(),
          SizedBox(height: 12),
          LicencesLink(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
