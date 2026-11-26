import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The bar at the top of the Synthesis tab, one row that fits 360 dp: on the left the folder
/// button (the current selection, `All notes ▾` or a folder's name, with a small badge while a
/// triage filter is on), on the right the open-all / collapse-all toggle and the Read | Edit
/// switch. Pure presentational widget.
class SynthesisBar extends StatelessWidget {
  /// `All notes` or the name of the selected folder.
  final String folderLabel;

  /// A triage filter other than All is on; the folder button shows a badge.
  final bool filterActive;
  final bool readMode;

  /// Every listed note is open: the toggle then collapses them, otherwise it opens them.
  final bool allOpen;
  final VoidCallback onFolderTap;
  final VoidCallback onToggleAll;
  final ValueChanged<bool> onReadModeChanged;

  const SynthesisBar({
    super.key,
    required this.folderLabel,
    required this.filterActive,
    required this.readMode,
    required this.allOpen,
    required this.onFolderTap,
    required this.onToggleAll,
    required this.onReadModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FolderButton(label: folderLabel, filterActive: filterActive, onTap: onFolderTap),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('synthesis_expand_all_toggle'),
            tooltip: allOpen ? 'Collapse all' : 'Open all',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            icon: Icon(allOpen ? Icons.unfold_less : Icons.unfold_more, size: 22, color: AppColors.textSecondary),
            onPressed: onToggleAll,
          ),
          const SizedBox(width: 4),
          _ModeSwitch(readMode: readMode, onChanged: onReadModeChanged),
        ],
      ),
    );
  }
}

class _FolderButton extends StatelessWidget {
  final String label;
  final bool filterActive;
  final VoidCallback onTap;

  const _FolderButton({required this.label, required this.filterActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('synthesis_folder_button'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_outlined, size: 16, color: AppColors.accentAction),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.accentAction),
                if (filterActive)
                  Container(
                    key: const Key('synthesis_filter_badge'),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: const BoxDecoration(color: AppColors.accentAction, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two segments, book `Read` and pencil `Edit`; the chosen one is filled.
class _ModeSwitch extends StatelessWidget {
  final bool readMode;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.readMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('synthesis_mode_toggle'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            key: const Key('synthesis_mode_read'),
            semanticLabel: 'Read mode',
            icon: Icons.menu_book_outlined,
            label: 'Read',
            selected: readMode,
            onTap: () => onChanged(true),
          ),
          _Segment(
            key: const Key('synthesis_mode_edit'),
            semanticLabel: 'Edit mode',
            icon: Icons.edit_outlined,
            label: 'Edit',
            selected: !readMode,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String semanticLabel;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textSecondary;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.accentAction : Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.buttonRadius - 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
