import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/style_rewriter_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/note_ejection_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/note_merge_sheet.dart';

class SynthesisScreen extends ConsumerStatefulWidget {
  const SynthesisScreen({super.key});

  @override
  ConsumerState<SynthesisScreen> createState() => _SynthesisScreenState();
}

class _SynthesisScreenState extends ConsumerState<SynthesisScreen> {
  String _activeFolderFilter = 'All Folders';
  final List<String> _folders = const [
    'All Folders',
    'Work',
    'Ideas',
    'Todos',
    'Journal',
    'Uncategorized'
  ];
  String _readFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final clusters = ref.watch(synthesisRepositoryProvider);
    final repoNotifier = ref.read(synthesisRepositoryProvider.notifier);
    final rawNotesCountAsync = ref.watch(rawNotesReadyToClusterCountProvider);
    final pendingRawNotes = rawNotesCountAsync.value ?? 0;

    final folderFiltered = _activeFolderFilter == 'All Folders'
        ? clusters
        : clusters
            .where((c) =>
                c.folder.toLowerCase() == _activeFolderFilter.toLowerCase())
            .toList();

    final filteredClusters = folderFiltered.where((c) {
      if (_readFilter == 'Unread') return c.isUnread;
      if (_readFilter == 'Read') return !c.isUnread;
      return true;
    }).toList();

    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Sub-Header Row: Section Title + Compact Triage & Folder Filter Dropdowns
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  'SYNTHESIS SESSIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Compact Triage Filter Dropdown (All, Unread, Read)
                    Container(
                      key: const Key('synthesis_triage_filter_dropdown'),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _readFilter,
                          dropdownColor: AppColors.surfaceElevated,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.accentAction, size: 20),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          items: const ['All', 'Unread', 'Read'].map((triage) {
                            return DropdownMenuItem<String>(
                              value: triage,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    triage == 'Unread'
                                        ? Icons.mark_email_unread_outlined
                                        : (triage == 'Read'
                                            ? Icons.mark_email_read_outlined
                                            : Icons.remove_red_eye_outlined),
                                    size: 14,
                                    color: triage == _readFilter
                                        ? AppColors.accentAction
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(triage == 'All' ? 'All Triage' : triage),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() {
                                _readFilter = newVal;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    // Compact Folder Filter Dropdown
                    Container(
                      key: const Key('synthesis_folder_filter_dropdown'),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activeFolderFilter,
                          dropdownColor: AppColors.surfaceElevated,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.accentAction, size: 20),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          items: _folders.map((folder) {
                            return DropdownMenuItem<String>(
                              value: folder,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 14,
                                    color: folder == _activeFolderFilter
                                        ? AppColors.accentAction
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(folder),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() {
                                _activeFolderFilter = newVal;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Pending Batch Synthesis Banner
          if (pendingRawNotes > 0) ...[
            Container(
              key: const Key('pending_synthesis_batch_banner'),
              margin: const EdgeInsets.only(top: 4, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentAI.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppColors.cardRadius),
                border: Border.all(
                    color: AppColors.accentAI.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.extension_outlined,
                      size: 16, color: AppColors.accentAI),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🧩 $pendingRawNotes raw thoughts ready to cluster',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    key: const Key('synthesize_now_banner_button'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      await repoNotifier.synthesizeRawNotes();
                      ref.invalidate(rawNotesReadyToClusterCountProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.surfaceElevated,
                            content: Text(
                              'Triggered on-demand synthesis clustering.',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentAction,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Synthesize Now',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Clusters List or Empty State
          if (filteredClusters.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 36.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.hub_outlined,
                        size: 32,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No synthesis sessions yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Thoughts captured in close proximity or sharing similar context will be automatically clustered here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    if (pendingRawNotes > 0) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentAction,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text(
                          'Synthesize Thoughts Now',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          await repoNotifier.synthesizeRawNotes();
                          ref.invalidate(rawNotesReadyToClusterCountProvider);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredClusters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cluster = filteredClusters[index];
                return _buildClusterCard(context, cluster, clusters, repoNotifier);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClusterCard(
    BuildContext context,
    SynthesisCluster cluster,
    List<SynthesisCluster> allClusters,
    SynthesisRepository repoNotifier,
  ) {
    Color cardBg;
    Color cardBorder;

    if (cluster.isReprocessing) {
      cardBg = AppColors.stateEnqueuedBg;
      cardBorder = AppColors.stateEnqueuedBorder;
    } else if (cluster.isActionExtracted) {
      cardBg = AppColors.stateSynthesizedBg;
      cardBorder = AppColors.stateSynthesizedBorder;
    } else {
      cardBg = AppColors.stateProcessedBg;
      cardBorder = AppColors.stateProcessedBorder;
    }

    return Container(
      key: Key('synthesis_cluster_card_${cluster.sequenceNumber}'),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: [#S-01] -> [Folder Dropdown] -> [• Unread Dot] -> Spacer -> [Style] -> [Merge] -> [Delete]
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 6,
            runSpacing: 4,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.numberBadgeBg,
                      borderRadius:
                          BorderRadius.circular(AppColors.badgeRadius),
                    ),
                    child: Text(
                      cluster.sequenceNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.numberBadgeText,
                      ),
                    ),
                  ),
                  // Folder Reassignment Dropdown
                  Container(
                    key: Key('cluster_folder_dropdown_${cluster.sequenceNumber}'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: cluster.folder,
                        dropdownColor: AppColors.surfaceElevated,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            size: 16, color: AppColors.accentAction),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        items: ['Work', 'Ideas', 'Todos', 'Journal', 'Uncategorized']
                            .map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f),
                                ))
                            .toList(),
                        onChanged: (newFolder) {
                          if (newFolder != null) {
                            repoNotifier.reassignFolder(
                                cluster.clusterId, newFolder);
                          }
                        },
                      ),
                    ),
                  ),
                  if (cluster.isUnread) ...[
                    Container(
                      key: Key('unread_dot_${cluster.sequenceNumber}'),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.unreadDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 4,
                children: [
                  // Style Rewriter Button
                  IconButton(
                    key: Key('style_button_${cluster.sequenceNumber}'),
                    icon: const Icon(Icons.auto_awesome,
                        size: 16, color: AppColors.accentAI),
                    tooltip: 'AI Style Re-Writer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      StyleRewriterModal.show(
                        context,
                        sequenceLabel: cluster.sequenceNumber,
                        selectedPresetId: cluster.appliedStyleId,
                        onSelectPreset: (preset) {
                          repoNotifier.applyStyle(
                              cluster.clusterId, preset.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surfaceElevated,
                              content: Text(
                                'Applying style "${preset.name}" to ${cluster.sequenceNumber}...',
                                style: const TextStyle(
                                    color: AppColors.textPrimary),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // Merge Button
                  if (allClusters.length > 1) ...[
                    IconButton(
                      key: Key('merge_button_${cluster.sequenceNumber}'),
                      icon: const Icon(Icons.merge_type,
                          size: 16, color: AppColors.accentAction),
                      tooltip: 'Merge Session',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        NoteMergeModal.show(
                          context,
                          sourceCluster: cluster,
                          availableClusters: allClusters,
                          onMergeToTargetCluster: (target) {
                            repoNotifier.mergeClusters(
                                cluster.clusterId, target.clusterId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.surfaceElevated,
                                content: Text(
                                  'Merged [${cluster.sequenceNumber}] into ${target.sequenceNumber}',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  // Delete Button
                  IconButton(
                    key: Key('delete_cluster_${cluster.sequenceNumber}'),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.textTertiary),
                    tooltip: 'Delete Cluster',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      repoNotifier.deleteCluster(cluster.clusterId);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Synthesized Text Narrative
          Text(
            cluster.synthesizedContent,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Footer: Timestamp + Duration + Expandable Raw Notes Pill
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                '${_formatDate(cluster.sessionStart)} • ⏱️ ${_formatDuration(cluster.sessionDuration)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              InkWell(
                key: Key('expand_raw_notes_${cluster.sequenceNumber}'),
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  repoNotifier.toggleExpand(cluster.clusterId);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.extension_outlined,
                          size: 12, color: AppColors.accentAction),
                      const SizedBox(width: 4),
                      Text(
                        '${cluster.originNotes.length} Raw Notes',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentAction,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        cluster.isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: AppColors.accentAction,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Expanded Origin Notes List
          if (cluster.isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 10),
            Text(
              'ORIGIN RAW NOTES (${cluster.originNotes.length})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cluster.originNotes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, noteIdx) {
                final rawNote = cluster.originNotes[noteIdx];
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.numberBadgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rawNote.formattedSequence,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.numberBadgeText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rawNote.cleanedText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Single Note Guard: Hide [Move Out] if originNotes.length <= 1
                      if (cluster.originNotes.length > 1) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          key: Key('move_out_note_${rawNote.id}'),
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            NoteEjectionModal.show(
                              context,
                              rawNote: rawNote,
                              currentCluster: cluster,
                              availableClusters: allClusters,
                              onMoveToTargetCluster: (targetCluster) {
                                repoNotifier.ejectRawNoteToTarget(
                                  cluster.clusterId,
                                  targetCluster.clusterId,
                                  rawNote.id,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surfaceElevated,
                                    content: Text(
                                      'Moved [${rawNote.formattedSequence}] to ${targetCluster.sequenceNumber}',
                                      style: const TextStyle(
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                );
                              },
                              onMakeIndependent: () {
                                repoNotifier.ejectRawNoteToIndependent(
                                  cluster.clusterId,
                                  rawNote.id,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surfaceElevated,
                                    content: Text(
                                      'Promoted [${rawNote.formattedSequence}] to independent synthesized note.',
                                      style: const TextStyle(
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentAction
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.drive_file_move_outlined,
                                    size: 11, color: AppColors.accentAction),
                                SizedBox(width: 3),
                                Text(
                                  'Move Out',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentAction,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}  ${_formatTime(dt)}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) {
      return '${d.inMinutes}m session';
    }
    return '${d.inHours}h ${d.inMinutes % 60}m session';
  }
}

