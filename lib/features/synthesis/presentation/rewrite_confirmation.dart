import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Asks whether a style rewrite may replace the user's own edits to a note. Resolves true on
/// `Rewrite`, false on `Cancel` or a tap outside. Keys: `rewrite_confirm_button`,
/// `rewrite_cancel_button`.
Future<bool> confirmRewriteOfHandEditedNote(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      content: const Text(
        rewriteReplacesEditsWarning,
        style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
      ),
      actions: [
        TextButton(
          key: const Key('rewrite_cancel_button'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          key: const Key('rewrite_confirm_button'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Rewrite', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
