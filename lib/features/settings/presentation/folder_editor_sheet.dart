import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'folder_texts.dart';

/// Bottom sheet that adds a folder ([folder] null) or edits one: name, description, default style,
/// Save, and Delete. [uncategorizedFolderName] shows its name and description read-only; its
/// default style is saved as soon as it is picked. Why a change was refused shows inline.
class FolderEditorSheet extends ConsumerStatefulWidget {
  final FolderDefinition? folder;

  const FolderEditorSheet({super.key, this.folder});

  @override
  ConsumerState<FolderEditorSheet> createState() => _FolderEditorSheetState();
}

class _FolderEditorSheetState extends ConsumerState<FolderEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.folder?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.folder?.description ?? '');

  /// The folder's name as stored now; changes once a rename has succeeded.
  late String _currentName = widget.folder?.name ?? '';

  /// The default style picked, and the one stored now.
  late String _style = widget.folder?.defaultStyleId ?? defaultNoteStyleId;
  late String _savedStyle = widget.folder?.defaultStyleId ?? defaultNoteStyleId;
  String? _error;
  bool _busy = false;

  bool get _isNew => widget.folder == null;
  bool get _isProtected => widget.folder?.name == uncategorizedFolderName;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Same whitespace rule the folder store applies.
  static String _clean(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final folders = ref.read(foldersProvider.notifier);
    var change = FolderChange.done;
    if (_isNew) {
      change = await folders.add(_name.text, _description.text, defaultStyleId: _style);
    } else {
      if (_clean(_name.text) != _currentName) {
        change = await folders.rename(_currentName, _name.text);
        if (change == FolderChange.done) _currentName = _clean(_name.text);
      }
      if (change == FolderChange.done && _clean(_description.text) != _clean(widget.folder!.description)) {
        change = await folders.updateDescription(_currentName, _description.text);
      }
      if (change == FolderChange.done && _style != _savedStyle) {
        change = await folders.updateDefaultStyle(_currentName, _style);
        if (change == FolderChange.done) _savedStyle = _style;
      }
    }
    if (!mounted) return;
    if (change == FolderChange.done) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = folderChangeMessage(change);
      });
    }
  }

  /// Uncategorized has no Save: its style is stored when picked.
  Future<void> _saveProtectedStyle(String styleId) async {
    setState(() {
      _style = styleId;
      _error = null;
    });
    final change = await ref.read(foldersProvider.notifier).updateDefaultStyle(_currentName, styleId);
    if (!mounted) return;
    setState(() {
      if (change == FolderChange.done) {
        _savedStyle = styleId;
      } else {
        _error = folderChangeMessage(change);
      }
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete folder?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(deleteFolderMessage(_currentName),
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            key: const Key('folder_delete_cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('folder_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final change = await ref.read(foldersProvider.notifier).remove(_currentName);
    if (!mounted) return;
    if (change == FolderChange.done) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = folderChangeMessage(change);
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        counterStyle: const TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          borderSide: const BorderSide(color: AppColors.accentAction),
        ),
      );

  Widget _styleField() => DropdownButtonFormField<String>(
        key: const Key('folder_style_field'),
        initialValue: _style,
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        dropdownColor: AppColors.surfaceElevated,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _decoration('Default style'),
        // Every choice carries its description under the name, as the restyle sheet's rows do; the
        // closed field shows the chosen style the same way.
        items: [
          for (final s in noteStyles)
            DropdownMenuItem<String>(
              value: s.id,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(s.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
        onChanged: _busy
            ? null
            : (id) {
                if (id == null || id == _style) return;
                if (_isProtected) {
                  _saveProtectedStyle(id);
                } else {
                  setState(() => _style = id);
                }
              },
      );

  Widget _errorText() => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          _error!,
          key: const Key('folder_error_text'),
          style: const TextStyle(fontSize: 13, color: AppColors.accentError),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isNew ? 'New folder' : (_isProtected ? widget.folder!.name : 'Edit folder'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  key: const Key('folder_editor_close'),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isProtected) ...[
              Text(
                widget.folder!.description,
                key: const Key('folder_readonly_description'),
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                uncategorizedNote,
                key: Key('folder_protected_note'),
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _styleField(),
              if (_error != null) _errorText(),
            ] else ...[
              TextField(
                key: const Key('folder_name_field'),
                controller: _name,
                maxLength: maxFolderNameLength,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decoration('Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('folder_description_field'),
                controller: _description,
                maxLength: maxFolderDescriptionLength,
                minLines: 3,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decoration('Description'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Text(
                  folderDescriptionHelp,
                  key: Key('folder_description_help'),
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              _styleField(),
              if (_error != null) _errorText(),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('folder_save_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAction,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.buttonRadius)),
                ),
                onPressed: _busy ? null : _save,
                child: const Text('Save',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('folder_delete_button'),
                  onPressed: _busy ? null : _delete,
                  child: const Text('Delete folder', style: TextStyle(color: AppColors.accentError)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
