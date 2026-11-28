import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The search field at the top of a chooser sheet (folders, notes to merge into): a quiet,
/// filled box with a search icon and a clear button once something is typed. Pure presentational
/// widget; the sheet filters its own list from [onChanged].
class SheetSearchField extends StatelessWidget {
  final Key fieldKey;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const SheetSearchField({
    super.key,
    required this.fieldKey,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    );
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          borderSide: const BorderSide(color: AppColors.borderFocus),
        ),
      ),
    );
  }
}
