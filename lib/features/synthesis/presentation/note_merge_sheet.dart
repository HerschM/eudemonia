import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/synthesis/presentation/sheet_search_field.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';

/// Modal bottom sheet allowing users to explicitly merge one synthesis session into another.
/// A search field (`merge_search_field`, hint `Search notes`) narrows the candidates by a
/// case-insensitive text match over each note's title and text; nothing matching shows
/// `No note matches`.
class NoteMergeModal extends StatefulWidget {
  final SynthesisCluster sourceCluster;
  final List<SynthesisCluster> availableClusters;
  final ValueChanged<SynthesisCluster> onMergeToTargetCluster;

  const NoteMergeModal({
    super.key,
    required this.sourceCluster,
    required this.availableClusters,
    required this.onMergeToTargetCluster,
  });

  static Future<void> show(
    BuildContext context, {
    required SynthesisCluster sourceCluster,
    required List<SynthesisCluster> availableClusters,
    required ValueChanged<SynthesisCluster> onMergeToTargetCluster,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.modalRadius),
        ),
      ),
      builder: (context) => NoteMergeModal(
        sourceCluster: sourceCluster,
        availableClusters: availableClusters,
        onMergeToTargetCluster: onMergeToTargetCluster,
      ),
    );
  }

  /// The notes whose title or text contains [query], ignoring case.
  static List<SynthesisCluster> matching(List<SynthesisCluster> notes, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return notes;
    return [
      for (final n in notes)
        // The plain text carries the title and the body, without Markdown marks in the way.
        if (noteTextForClipboard(noteHeadingTitle(n.synthesizedContent) ?? '', n.synthesizedContent)
            .toLowerCase()
            .contains(needle))
          n,
    ];
  }

  @override
  State<NoteMergeModal> createState() => _NoteMergeModalState();
}

class _NoteMergeModalState extends State<NoteMergeModal> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  SynthesisCluster get sourceCluster => widget.sourceCluster;
  ValueChanged<SynthesisCluster> get onMergeToTargetCluster => widget.onMergeToTargetCluster;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.availableClusters
        .where((c) => c.clusterId != sourceCluster.clusterId)
        .toList();
    final targets = NoteMergeModal.matching(candidates, _query);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                const Icon(Icons.merge_type,
                    color: AppColors.accentAction, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Merge Session ${sourceCluster.sequenceNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('close_merge_modal_button'),
                  icon: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Consolidate all raw notes from ${sourceCluster.sequenceNumber} into another session. The target session will turn Yellow and re-synthesize a combined narrative.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 18),
            if (candidates.isNotEmpty) ...[
              SheetSearchField(
                fieldKey: const Key('merge_search_field'),
                hint: 'Search notes',
                controller: _search,
                onChanged: (q) => setState(() => _query = q),
              ),
              const SizedBox(height: 12),
            ],
            if (candidates.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
                child: const Center(
                  child: Text(
                    'No other synthesis sessions available to merge into.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else if (targets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No note matches',
                    key: Key('merge_no_match'),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              // Scrolls when the targets do not fit: there can be dozens of notes to merge into.
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final target = targets[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key('merge_target_${target.clusterId}'),
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        onTap: () {
                          Navigator.pop(context);
                          onMergeToTargetCluster(target);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppColors.buttonRadius),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAction
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  // Two sessions of different days can both be #S-01: name the day.
                                  sessionReferenceLabel(target, relativeTo: sourceCluster.sessionStart),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentAction,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Wraps rather than overflows when the label above takes more room (a day is named).
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        Text(
                                          target.folder,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.accentAction,
                                          ),
                                        ),
                                        Text(
                                          '• ${target.originNotes.length} notes',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      plainNotePreview(target.synthesizedContent),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: AppColors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
