import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';
import 'note_ejection_preview.dart';

class SynthesisScreenPreview extends StatefulWidget {
  const SynthesisScreenPreview({super.key});

  @override
  State<SynthesisScreenPreview> createState() => _SynthesisScreenPreviewState();
}

class _SynthesisScreenPreviewState extends State<SynthesisScreenPreview> {
  late List<MockSynthesisCluster> _clusters;
  String _activeFolderFilter = 'All Folders';
  final List<String> _folders = const ['All Folders', 'Work', 'Ideas', 'Todos', 'Journal', 'Uncategorized'];

  @override
  void initState() {
    super.initState();
    _clusters = List.from(MockData.synthesisClusters);
  }

  void _toggleExpand(String clusterId) {
    setState(() {
      final index = _clusters.indexWhere((c) => c.clusterId == clusterId);
      if (index != -1) {
        _clusters[index] = _clusters[index].copyWith(
          isExpanded: !_clusters[index].isExpanded,
        );
      }
    });
  }

  void _reassignFolder(MockSynthesisCluster cluster, String newFolder) {
    setState(() {
      final index = _clusters.indexWhere((c) => c.clusterId == cluster.clusterId);
      if (index != -1) {
        _clusters[index] = _clusters[index].copyWith(folder: newFolder);
      }
    });
  }

  void _openEjectionModal(MockSynthesisCluster cluster, MockCaptureNote rawNote) {
    NoteEjectionModal.show(
      context,
      rawNote: rawNote,
      onMoveToCluster: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PreviewTheme.surfaceElevated,
            content: Text(
              'Moving [${rawNote.formattedSequence}] to target session...',
              style: const TextStyle(color: PreviewTheme.textPrimary),
            ),
          ),
        );
      },
      onMakeIndependent: () {
        setState(() {
          // Remove from origin cluster
          final updatedOriginNotes = List<MockCaptureNote>.from(cluster.originNotes)
            ..removeWhere((n) => n.id == rawNote.id);

          final clusterIndex = _clusters.indexWhere((c) => c.clusterId == cluster.clusterId);
          if (clusterIndex != -1) {
            _clusters[clusterIndex] = _clusters[clusterIndex].copyWith(originNotes: updatedOriginNotes);
          }

          // Create new independent cluster
          final newCluster = MockSynthesisCluster(
            clusterId: 'cluster_independent_${rawNote.id}',
            sequenceNumber: '#S-0${_clusters.length + 1}',
            folder: cluster.folder,
            synthesizedContent: rawNote.cleanedText,
            sessionStart: rawNote.timestamp,
            sessionEnd: rawNote.timestamp.add(const Duration(minutes: 5)),
            sessionDuration: const Duration(minutes: 5),
            originNotes: [rawNote],
          );
          _clusters.insert(0, newCluster);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PreviewTheme.surfaceElevated,
            content: Text(
              'Promoted [${rawNote.formattedSequence}] to independent synthesized note.',
              style: const TextStyle(color: PreviewTheme.textPrimary),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClusters = _activeFolderFilter == 'All Folders'
        ? _clusters
        : _clusters.where((c) => c.folder.toLowerCase() == _activeFolderFilter.toLowerCase()).toList();

    return Container(
      color: PreviewTheme.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Sub-Header Row: Section Title + Compact Folder Filter Dropdown
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
                    color: PreviewTheme.textSecondary.withOpacity(0.7),
                  ),
                ),
                // Compact Folder Filter Dropdown
                Container(
                  key: const Key('synthesis_folder_filter_dropdown'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: PreviewTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                    border: Border.all(color: PreviewTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _activeFolderFilter,
                      dropdownColor: PreviewTheme.surfaceElevated,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: PreviewTheme.accentAction, size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PreviewTheme.textPrimary,
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
                                    ? PreviewTheme.accentAction
                                    : PreviewTheme.textSecondary,
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
          ),
          const SizedBox(height: 6),
          // Clusters Feed
          if (filteredClusters.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text(
                'No sessions in this folder.',
                style: TextStyle(color: PreviewTheme.textSecondary),
              ),
            ),
          ] else ...[
            ...filteredClusters.map((cluster) => _buildClusterCard(cluster)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClusterCard(MockSynthesisCluster cluster) {
    final cleanSeq = cluster.sequenceNumber.replaceAll('#', '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: PreviewTheme.cardDecoration(
        bgColor: PreviewTheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Cluster Sequence # + Predefined Folder Badge Dropdown + Edit
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cluster Sequence # (e.g. #S-02)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PreviewTheme.accentAction.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                      ),
                      child: Text(
                        cluster.sequenceNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PreviewTheme.accentAction,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Predefined Folder Badge with 1-Tap Reassignment Dropdown
                    Container(
                      key: Key('folder_badge_$cleanSeq'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: PreviewTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                        border: Border.all(color: PreviewTheme.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: cluster.folder,
                          dropdownColor: PreviewTheme.surfaceElevated,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, color: PreviewTheme.textSecondary, size: 16),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PreviewTheme.textPrimary,
                          ),
                          items: const ['Work', 'Ideas', 'Todos', 'Journal', 'Uncategorized'].map((folder) {
                            return DropdownMenuItem<String>(
                              value: folder,
                              child: Text(folder),
                            );
                          }).toList(),
                          onChanged: (newFolder) {
                            if (newFolder != null) {
                              _reassignFolder(cluster, newFolder);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: PreviewTheme.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            color: PreviewTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Consolidated Synthesis Narrative
            Text(
              cluster.synthesizedContent,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: PreviewTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: PreviewTheme.borderSubtle),
            const SizedBox(height: 10),
            // Session Time Span & Duration Metadata
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: PreviewTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${cluster.formattedTimeSpan} • ⏱️ ${cluster.sessionDuration.inMinutes}m session',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: PreviewTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Expandable Origin Raw Notes Pill
            Material(
              color: PreviewTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PreviewTheme.borderSubtle),
              ),
              child: InkWell(
                key: Key('expand_origin_pill_$cleanSeq'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _toggleExpand(cluster.clusterId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.extension_outlined, size: 14, color: PreviewTheme.accentAction),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '[ 🧩 ${cluster.originNotes.length} Raw Notes Included (Tap to ${cluster.isExpanded ? 'Collapse' : 'Expand'}) ]',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PreviewTheme.accentAction,
                          ),
                        ),
                      ),
                      Icon(
                        cluster.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: PreviewTheme.accentAction,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Origin Notes Expanded Drawer
            if (cluster.isExpanded) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PreviewTheme.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PreviewTheme.borderSubtle),
                ),
                child: Column(
                  children: cluster.originNotes.map((rawNote) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PreviewTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PreviewTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '• [${rawNote.formattedSequence}]',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: PreviewTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rawNote.cleanedText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: PreviewTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.play_circle_outline, size: 16, color: PreviewTheme.accentCapture),
                                  const SizedBox(width: 4),
                                  Text(
                                    rawNote.formattedAudioDuration,
                                    style: const TextStyle(fontSize: 11, color: PreviewTheme.textSecondary),
                                  ),
                                ],
                              ),
                              InkWell(
                                key: Key('move_out_button_${rawNote.id}'),
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _openEjectionModal(cluster, rawNote),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: PreviewTheme.accentWarning.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: PreviewTheme.accentWarning.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.open_in_new, size: 12, color: PreviewTheme.accentWarning),
                                      SizedBox(width: 4),
                                      Text(
                                        'Move Out',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: PreviewTheme.accentWarning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
