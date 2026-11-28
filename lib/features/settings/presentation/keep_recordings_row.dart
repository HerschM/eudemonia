import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/capture/recording_retention.dart';
import 'package:eudemonia/features/capture/recording_retention_settings.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/confirm_delete_dialog.dart';

/// How long original recordings are kept, with what that costs: the chosen period (`keep_recordings_row`,
/// opens the chooser `keep_recordings_option_<always|90|30|7>`), what a minute of recording takes
/// (`keep_recordings_help`) and what is on the phone now (`recordings_size_line`).
///
/// A period that would remove recordings right now asks first, saying how many and how much; Cancel
/// changes nothing. A confirmed choice is stored at once and the sweep starts right after.
class KeepRecordingsRow extends ConsumerWidget {
  const KeepRecordingsRow({super.key});

  static const helpText =
      'A recording takes about 1.9 MB per minute. Only the audio is removed; the text and your notes always stay.';

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final current = ref.read(recordingRetentionProvider);
    final notifier = ref.read(recordingRetentionProvider.notifier);
    final service = ref.read(recordingRetentionServiceProvider);

    final picked = await showModalBottomSheet<RecordingRetention>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.modalRadius)),
      ),
      builder: (_) => _RetentionChooser(selected: current),
    );
    if (picked == null || picked == current) return;

    final removal = await service.preview(picked);
    if (removal.count > 0) {
      if (!context.mounted) return;
      final confirmed = await confirmDelete(
        context,
        question: 'Keep recordings for ${picked.label}? That removes '
            '${removal.count} ${removal.count == 1 ? 'recording' : 'recordings'} '
            '(${formatRecordingSize(removal.bytes)}) older than ${picked.label} from this phone now.',
        consequence: 'This cannot be undone. The text and your notes stay.',
      );
      if (!confirmed) return;
    }
    notifier.set(picked);
    unawaited(service.sweep(picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(recordingRetentionProvider);
    final size = ref.watch(recordingsOnPhoneProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const Key('keep_recordings_row'),
          leading: const Icon(Icons.auto_delete_outlined, color: AppColors.accentCapture),
          title: const Text('Keep original recordings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          subtitle: Text(current.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          onTap: () => _choose(context, ref),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            helpText,
            key: Key('keep_recordings_help'),
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
        if (size != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              recordingsOnPhoneLine(size),
              key: const Key('recordings_size_line'),
              style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// The four choices, the current one marked with a check. Choosing one closes the sheet and returns it.
class _RetentionChooser extends StatelessWidget {
  final RecordingRetention selected;

  const _RetentionChooser({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Keep original recordings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          for (final option in RecordingRetention.values)
            ListTile(
              key: Key('keep_recordings_option_${option.keySuffix}'),
              minTileHeight: 48,
              title: Text(option.label, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              trailing: option == selected ? const Icon(Icons.check, color: AppColors.accentCapture) : null,
              onTap: () => Navigator.pop(context, option),
            ),
        ],
      ),
    );
  }
}
