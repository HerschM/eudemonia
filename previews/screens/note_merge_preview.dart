import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

/// Modal bottom sheet allowing users to explicitly merge one synthesis session into another.
class NoteMergeModal extends StatelessWidget {
  final MockSynthesisCluster sourceCluster;
  final List<MockSynthesisCluster> availableClusters;
  final ValueChanged<MockSynthesisCluster> onMergeToTargetCluster;

  const NoteMergeModal({
    super.key,
    required this.sourceCluster,
    required this.availableClusters,
    required this.onMergeToTargetCluster,
  });

  static void show(
    BuildContext context, {
    required MockSynthesisCluster sourceCluster,
    required List<MockSynthesisCluster> availableClusters,
    required ValueChanged<MockSynthesisCluster> onMergeToTargetCluster,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PreviewTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PreviewTheme.modalRadius),
        ),
      ),
      builder: (context) => NoteMergeModal(
        sourceCluster: sourceCluster,
        availableClusters: availableClusters,
        onMergeToTargetCluster: onMergeToTargetCluster,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = availableClusters
        .where((c) => c.clusterId != sourceCluster.clusterId)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PreviewTheme.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                const Icon(Icons.merge_type,
                    color: PreviewTheme.accentAction, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Merge Session ${sourceCluster.sequenceNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PreviewTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('close_merge_modal_button'),
                  icon: const Icon(Icons.close,
                      size: 20, color: PreviewTheme.textSecondary),
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
                color: PreviewTheme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'SELECT TARGET SESSION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),

            if (targets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PreviewTheme.surface,
                  borderRadius:
                      BorderRadius.circular(PreviewTheme.buttonRadius),
                  border: Border.all(color: PreviewTheme.borderSubtle),
                ),
                child: const Text(
                  'No other active sessions available to merge into.',
                  style: TextStyle(
                      color: PreviewTheme.textSecondary, fontSize: 13),
                ),
              )
            else
              ...targets.map((target) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PreviewTheme.surface,
                    borderRadius:
                        BorderRadius.circular(PreviewTheme.buttonRadius),
                    border: Border.all(color: PreviewTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: PreviewTheme.accentAction
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                      PreviewTheme.badgeRadius),
                                ),
                                child: Text(
                                  target.sequenceNumber,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: PreviewTheme.accentAction,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: PreviewTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                      PreviewTheme.pillRadius),
                                  border: Border.all(
                                      color: PreviewTheme.borderSubtle),
                                ),
                                child: Text(
                                  target.folder,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: PreviewTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${target.originNotes.length} notes • ${target.sessionDuration.inMinutes}m',
                            style: const TextStyle(
                              fontSize: 11,
                              color: PreviewTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        target.synthesizedContent,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PreviewTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          key: Key('select_target_merge_${target.clusterId}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PreviewTheme.accentAction,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: const Icon(Icons.merge_type,
                              size: 14, color: Colors.white),
                          label: Text(
                            'Merge into ${target.sequenceNumber}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            onMergeToTargetCluster(target);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('cancel_merge_button'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: PreviewTheme.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(PreviewTheme.buttonRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: PreviewTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

