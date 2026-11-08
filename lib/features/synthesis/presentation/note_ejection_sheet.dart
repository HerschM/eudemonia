import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

class NoteEjectionModal extends StatefulWidget {
  final SynthesisOriginNote rawNote;
  final SynthesisCluster? currentCluster;
  final List<SynthesisCluster>? availableClusters;
  final ValueChanged<SynthesisCluster>? onMoveToTargetCluster;
  final VoidCallback? onMoveToCluster;
  final VoidCallback? onMakeIndependent;

  const NoteEjectionModal({
    super.key,
    required this.rawNote,
    this.currentCluster,
    this.availableClusters,
    this.onMoveToTargetCluster,
    this.onMoveToCluster,
    this.onMakeIndependent,
  });

  static Future<void> show(
    BuildContext context, {
    required SynthesisOriginNote rawNote,
    SynthesisCluster? currentCluster,
    List<SynthesisCluster>? availableClusters,
    ValueChanged<SynthesisCluster>? onMoveToTargetCluster,
    VoidCallback? onMoveToCluster,
    VoidCallback? onMakeIndependent,
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
      builder: (context) => NoteEjectionModal(
        rawNote: rawNote,
        currentCluster: currentCluster,
        availableClusters: availableClusters,
        onMoveToTargetCluster: onMoveToTargetCluster,
        onMoveToCluster: onMoveToCluster,
        onMakeIndependent: onMakeIndependent,
      ),
    );
  }

  @override
  State<NoteEjectionModal> createState() => _NoteEjectionModalState();
}

class _NoteEjectionModalState extends State<NoteEjectionModal> {
  bool _showingTargetPicker = false;

  @override
  Widget build(BuildContext context) {
    final otherClusters = (widget.availableClusters ?? [])
        .where((c) => c.clusterId != widget.currentCluster?.clusterId)
        .toList();

    return SafeArea(
      child: SingleChildScrollView(
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
              Text(
                'Reassign Raw Note [${widget.rawNote.formattedSequence}]',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"${widget.rawNote.cleanedText}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_showingTargetPicker) ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                      onPressed: () {
                        setState(() {
                          _showingTargetPicker = false;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Target Clubbed Note',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (otherClusters.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    ),
                    child: const Center(
                      child: Text(
                        'No other clubbed sessions available to merge into.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: otherClusters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final target = otherClusters[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('target_cluster_${target.sequenceNumber}'),
                          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onMoveToTargetCluster?.call(target);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentAI.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    target.sequenceNumber,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentAI,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        target.folder,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentAction,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        target.synthesizedContent,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
              ] else ...[
                // Option 1: Move to another clubbed note
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('ejection_move_to_another_clubbed_note_button'),
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    onTap: () {
                      if (otherClusters.length == 1 && widget.onMoveToCluster != null) {
                        Navigator.pop(context);
                        widget.onMoveToCluster?.call();
                      } else {
                        setState(() {
                          _showingTargetPicker = true;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.drive_file_move_outlined, color: AppColors.accentAction, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Move to another clubbed note',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Select an existing synthesis session to append this note.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Option 2: Make it an independent note
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('ejection_make_independent_note_button'),
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMakeIndependent?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.open_in_new, color: AppColors.accentCapture, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Make it an independent note',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Detach this note into its own standalone synthesized session.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

