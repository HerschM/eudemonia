import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Puts [text] on the clipboard, confirms with a short haptic and a `Copied` message.
Future<void> copyToClipboard(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.mediumImpact();
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        key: Key('copied_snackbar'),
        backgroundColor: AppColors.surfaceElevated,
        duration: Duration(milliseconds: 1500),
        content: Text('Copied', style: TextStyle(color: AppColors.textPrimary)),
      ),
    );
}
