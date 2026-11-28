import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Asks before anything is deleted. [question] names what is deleted; [consequence], when given,
/// says what else changes because of it (a note that is rewritten or deleted too) and is shown
/// highlighted. Resolves true on `Delete`, false on `Cancel` or a tap outside.
/// Keys: `confirm_delete_button`, `confirm_delete_cancel`, `confirm_delete_consequence`.
Future<bool> confirmDelete(BuildContext context, {required String question, String? consequence}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary)),
          if (consequence != null) ...[
            const SizedBox(height: 12),
            Text(
              consequence,
              key: const Key('confirm_delete_consequence'),
              style: const TextStyle(
                  fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: AppColors.accentWarning),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('confirm_delete_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          key: const Key('confirm_delete_button'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: AppColors.accentError, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
