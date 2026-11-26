import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'folder_editor_sheet.dart';
import 'folder_texts.dart';
import 'settings_card.dart';

/// The folders Synthesis files notes under: each one with its description and its default style
/// when it is not organised, tap to edit, and a row to add another.
class FoldersSection extends ConsumerWidget {
  const FoldersSection({super.key});

  Future<void> _openEditor(BuildContext context, FolderDefinition? folder) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.modalRadius)),
      ),
      builder: (_) => FolderEditorSheet(folder: folder),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    final atLimit = folders.length >= maxFolderCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('FOLDERS'),
        SettingsCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Text(
                  foldersIntro,
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
              Column(
                key: const Key('settings_folder_list'),
                children: [
                  for (final folder in folders)
                    _FolderRow(folder: folder, onTap: () => _openEditor(context, folder)),
                ],
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              InkWell(
                key: const Key('settings_add_folder_row'),
                onTap: atLimit ? null : () => _openEditor(context, null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 20, color: atLimit ? AppColors.textTertiary : AppColors.accentAction),
                      const SizedBox(width: 10),
                      Text(
                        'Add folder',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: atLimit ? AppColors.textTertiary : AppColors.accentAction,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (atLimit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    folderLimitHint(),
                    key: const Key('settings_folder_limit_hint'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FolderRow extends StatelessWidget {
  final FolderDefinition folder;
  final VoidCallback onTap;

  const _FolderRow({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final protected = folder.name == uncategorizedFolderName;
    final styleLine = folderStyleLine(folder.defaultStyleId);
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.borderSubtle),
        InkWell(
          key: Key('settings_folder_row_${folder.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        folder.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                      ),
                      if (styleLine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          styleLine,
                          key: Key('settings_folder_style_${folder.name}'),
                          style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    protected ? Icons.lock_outline : Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
