import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/sheet_search_field.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Modal bottom sheet that moves a note to another folder: a search field (`folder_search_field`,
/// hint `Search folders`) that matches the folder names only, and one row per folder
/// (`folder_option_<name>`), the note's own marked with a check. Choosing a row closes the sheet
/// and returns its name; nothing matching shows `No folder matches`.
class NoteFolderSheet extends StatefulWidget {
  /// The folder the note is in now.
  final String current;
  final List<String> folderNames;

  const NoteFolderSheet({super.key, required this.current, required this.folderNames});

  /// The chosen folder name, null when the sheet was dismissed.
  static Future<String?> show(BuildContext context, {required String current, required List<String> folderNames}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.modalRadius)),
      ),
      builder: (_) => NoteFolderSheet(current: current, folderNames: folderNames),
    );
  }

  /// The folders whose name contains [query], ignoring case; descriptions never count.
  static List<String> matching(List<String> names, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return names;
    return [for (final n in names) if (n.toLowerCase().contains(needle)) n];
  }

  @override
  State<NoteFolderSheet> createState() => _NoteFolderSheetState();
}

class _NoteFolderSheetState extends State<NoteFolderSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A note keeps its folder even when it is no longer in the list.
    final all = <String>{...widget.folderNames, widget.current}.toList();
    final shown = NoteFolderSheet.matching(all, _query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.folder_outlined, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Move to folder',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  key: const Key('close_folder_sheet_button'),
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SheetSearchField(
              fieldKey: const Key('folder_search_field'),
              hint: 'Search folders',
              controller: _search,
              onChanged: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No folder matches',
                    key: Key('folder_no_match'),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final name = shown[index];
                    final isCurrent = name == widget.current;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key('folder_option_$name'),
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        onTap: () => Navigator.pop(context, name),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrent ? AppColors.surfaceElevated : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                            border: Border.all(
                              color: isCurrent ? AppColors.borderFocus : AppColors.borderSubtle,
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isCurrent) const Icon(Icons.check, size: 20, color: AppColors.textPrimary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
