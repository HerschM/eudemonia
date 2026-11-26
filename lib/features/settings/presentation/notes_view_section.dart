import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'settings_card.dart';

/// How the Synthesis list shows notes: one switch, whether every note is shown opened.
class NotesViewSection extends ConsumerWidget {
  const NotesViewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openByDefault = ref.watch(notesViewPrefsProvider.select((p) => p.notesOpenByDefault));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('NOTES'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SwitchListTile(
            key: const Key('notes_open_by_default_switch'),
            title: const Text(
              'Show notes opened',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'Off: a list of titles that open when tapped. On: every note is shown in full.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: openByDefault,
            onChanged: ref.read(notesViewPrefsProvider.notifier).setNotesOpenByDefault,
          ),
        ),
      ],
    );
  }
}
