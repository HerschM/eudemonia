import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// What the user can do to one note in Edit mode: file it under a folder, choose its style,
/// edit its text, merge it into another note, delete it. Pure presentational widget; every
/// action is a callback. Keys, all from the session's `clusterId`: `cluster_folder_dropdown_<id>`,
/// `style_button_<id>`, `edit_text_button_<id>`, `merge_button_<id>` and `delete_cluster_<id>`.
class NoteActionRow extends StatelessWidget {
  final String clusterId;
  final String folder;

  /// The folders to choose from; the note's own [folder] is offered even when it is not among them.
  final List<String> folderNames;

  /// The label of the style the note is written in (or `Edited by hand`).
  final String styleLabel;

  /// Merge needs another note to merge into.
  final bool canMerge;
  final ValueChanged<String> onFolderChanged;
  final VoidCallback onStyle;
  final VoidCallback onEditText;
  final VoidCallback onMerge;
  final VoidCallback onDelete;

  const NoteActionRow({
    super.key,
    required this.clusterId,
    required this.folder,
    required this.folderNames,
    required this.styleLabel,
    required this.canMerge,
    required this.onFolderChanged,
    required this.onStyle,
    required this.onEditText,
    required this.onMerge,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          key: Key('cluster_folder_dropdown_$clusterId'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppColors.badgeRadius),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: folder,
              dropdownColor: AppColors.surfaceElevated,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.accentAction),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              // A session keeps its folder even when it is no longer in the list.
              items: [
                for (final f in {...folderNames, folder}) DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (newFolder) {
                if (newFolder != null && newFolder != folder) onFolderChanged(newFolder);
              },
            ),
          ),
        ),
        _ActionChip(
          key: Key('style_button_$clusterId'),
          icon: Icons.draw_outlined,
          prefix: 'Style',
          label: styleLabel,
          trailing: Icons.arrow_drop_down,
          color: AppColors.textSecondary,
          tooltip: 'AI Style Re-Writer',
          onTap: onStyle,
        ),
        _ActionChip(
          key: Key('edit_text_button_$clusterId'),
          icon: Icons.edit_outlined,
          label: 'Edit text',
          color: AppColors.textSecondary,
          onTap: onEditText,
        ),
        if (canMerge)
          _ActionChip(
            key: Key('merge_button_$clusterId'),
            icon: Icons.merge_type,
            label: 'Merge',
            color: AppColors.accentAction,
            tooltip: 'Merge Session',
            onTap: onMerge,
          ),
        _ActionChip(
          key: Key('delete_cluster_$clusterId'),
          icon: Icons.delete_outline,
          label: 'Delete',
          color: AppColors.textTertiary,
          tooltip: 'Delete Cluster',
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final IconData? trailing;

  /// A dimmer word before the [label], e.g. `Style` before the name of the style.
  final String? prefix;
  final String label;
  final Color color;
  final String? tooltip;
  final VoidCallback onTap;

  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
    this.prefix,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip = Material(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.badgeRadius),
        side: BorderSide(color: color.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                if (prefix != null) ...[
                  Text(prefix!, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
                if (trailing != null) Icon(trailing, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) chip = Tooltip(message: tooltip!, child: chip);
    return chip;
  }
}
