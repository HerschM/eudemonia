import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

/// Modal bottom sheet allowing users to explicitly merge one synthesis session into another.
class NoteMergeModal extends StatelessWidget {
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
            if (targets.isEmpty)
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
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: targets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('merge_target_${target.sequenceNumber}'),
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
                                target.sequenceNumber,
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
                                  Row(
                                    children: [
                                      Text(
                                        target.folder,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentAction,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
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
                                    target.synthesizedContent,
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

