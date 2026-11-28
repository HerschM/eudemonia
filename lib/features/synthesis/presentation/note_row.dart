import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';
import 'package:eudemonia/features/theme/widgets/unread_dot.dart';

/// Keys of a note's row and card, all built from the session's `clusterId` (never its `#S-NN`
/// number, which repeats on every day): `synthesis_cluster_card_<id>` (row and body together),
/// `note_row_<id>` (the tappable row), `unread_dot_<id>`; the body's controls have their own
/// (see `NoteActionRow`, `NoteBody`, `RawThoughtsList`).
Key sessionCardKey(String clusterId) => Key('synthesis_cluster_card_$clusterId');

Key noteRowKey(String clusterId) => Key('note_row_$clusterId');

/// The colour a note's card has: waiting for a rewrite, finished, or finished without actions.
enum NoteRowTone { processed, synthesized, rewriting }

/// One note of the list: `#S-02` badge, title, time, unread dot and chevron, and under it the
/// note itself ([body]) while [open]. Pure presentational widget.
class NoteRow extends StatelessWidget {
  final String clusterId;
  final String number;
  final String title;
  final String timeLabel;
  final bool unread;

  /// Shown small under the title (when the list mixes folders); null shows nothing.
  final String? folderLabel;

  /// The note waits for, or is in, a rewrite: the time is replaced by the thinking indicator.
  final bool rewriting;

  /// Whether the thinking indicator moves (a run is on) or stands still (the rewrite waits).
  final bool animateRewriting;
  final NoteRowTone tone;
  final bool open;

  /// A note that was asked for glows for a moment.
  final bool highlighted;
  final VoidCallback onTap;

  /// Long press on the row (copies the note); null does nothing.
  final VoidCallback? onLongPress;

  /// What is shown under the row while [open]; built only then.
  final Widget? body;

  const NoteRow({
    super.key,
    required this.clusterId,
    required this.number,
    required this.title,
    required this.timeLabel,
    required this.unread,
    required this.open,
    required this.onTap,
    this.onLongPress,
    this.folderLabel,
    this.rewriting = false,
    this.animateRewriting = false,
    this.tone = NoteRowTone.synthesized,
    this.highlighted = false,
    this.body,
  });

  static const Duration openDuration = Duration(milliseconds: 200);
  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final (cardBg, cardBorder) = switch (tone) {
      NoteRowTone.rewriting => (AppColors.stateEnqueuedBg, AppColors.stateEnqueuedBorder),
      NoteRowTone.synthesized => (AppColors.stateSynthesizedBg, AppColors.stateSynthesizedBorder),
      NoteRowTone.processed => (AppColors.stateProcessedBg, AppColors.stateProcessedBorder),
    };
    final label = folderLabel;
    return AnimatedContainer(
      key: sessionCardKey(clusterId),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: highlighted ? AppColors.accentAction : cardBorder, width: highlighted ? 1.5 : 1.0),
        boxShadow: [
          if (highlighted)
            BoxShadow(color: AppColors.accentAction.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: noteRowKey(clusterId),
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Semantics(
                expanded: open,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: minHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.numberBadgeBg,
                            borderRadius: BorderRadius.circular(AppColors.badgeRadius),
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.numberBadgeText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                // An open note shows its whole title: its body does not repeat it.
                                maxLines: open ? null : 1,
                                overflow: open ? TextOverflow.visible : TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (label != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (rewriting)
                          ThinkingIndicator(label: 'Rewriting…', animate: animateRewriting)
                        else
                          Text(
                            timeLabel,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        // A fixed slot, so the time does not move when the dot is shown or dissolves.
                        SizedBox(
                          width: 17,
                          child: Center(
                            child: UnreadDot(unread: unread, size: 7, dotKey: Key('unread_dot_$clusterId')),
                          ),
                        ),
                        AnimatedRotation(
                          turns: open ? 0.25 : 0,
                          duration: openDuration,
                          child: const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: openDuration,
            alignment: Alignment.topCenter,
            child: open && body != null
                ? Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: body)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
