import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The thoughts a note was written from: number, time and text of each. With [onMoveOut] (Edit
/// mode) every thought of a note with more than one also has a Move Out button; a note of a
/// single thought has none, so no session is left without thoughts. Pure presentational widget.
class RawThoughtsList extends StatelessWidget {
  final List<SynthesisOriginNote> thoughts;
  final ValueChanged<SynthesisOriginNote>? onMoveOut;

  const RawThoughtsList({super.key, required this.thoughts, this.onMoveOut});

  @override
  Widget build(BuildContext context) {
    final move = onMoveOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Divider(color: AppColors.borderSubtle, height: 1),
        const SizedBox(height: 10),
        Text(
          'ORIGIN RAW NOTES (${thoughts.length})',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < thoughts.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ThoughtTile(
            thought: thoughts[i],
            onMoveOut: move != null && thoughts.length > 1 ? () => move(thoughts[i]) : null,
          ),
        ],
      ],
    );
  }
}

class _ThoughtTile extends StatelessWidget {
  final SynthesisOriginNote thought;
  final VoidCallback? onMoveOut;

  const _ThoughtTile({required this.thought, required this.onMoveOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.numberBadgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              thought.formattedSequence,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.numberBadgeText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatNoteTime(thought.timestamp),
                  style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 2),
                Text(
                  thought.cleanedText,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (onMoveOut != null) ...[
            const SizedBox(width: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('move_out_note_${thought.id}'),
                borderRadius: BorderRadius.circular(4),
                onTap: onMoveOut,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentAction.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drive_file_move_outlined, size: 11, color: AppColors.accentAction),
                      SizedBox(width: 3),
                      Text(
                        'Move Out',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentAction),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
