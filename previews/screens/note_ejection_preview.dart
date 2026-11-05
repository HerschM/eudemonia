import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

class NoteEjectionModal extends StatefulWidget {
  final MockCaptureNote rawNote;
  final MockSynthesisCluster? currentCluster;
  final List<MockSynthesisCluster>? availableClusters;
  final ValueChanged<MockSynthesisCluster>? onMoveToTargetCluster;
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
    required MockCaptureNote rawNote,
    MockSynthesisCluster? currentCluster,
    List<MockSynthesisCluster>? availableClusters,
    ValueChanged<MockSynthesisCluster>? onMoveToTargetCluster,
    VoidCallback? onMoveToCluster,
    VoidCallback? onMakeIndependent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PreviewTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PreviewTheme.modalRadius),
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
    final otherClusters = (widget.availableClusters ?? MockData.synthesisClusters)
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
                    color: PreviewTheme.textTertiary.withValues(alpha: 0.4),
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
                  color: PreviewTheme.textPrimary,
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
                  color: PreviewTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Move to another clubbed note
              if (!_showingTargetPicker) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('move_to_another_clubbed_note_btn'),
                    borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                    onTap: () {
                      setState(() {
                        _showingTargetPicker = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PreviewTheme.surface,
                        borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                        border: Border.all(color: PreviewTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: PreviewTheme.accentAction.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_open, color: PreviewTheme.accentAction, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Move to Another Clubbed Note',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: PreviewTheme.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Choose an existing session',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PreviewTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: PreviewTheme.textTertiary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Expanded Target Clubbed Note Picker
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PreviewTheme.surface,
                    borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                    border: Border.all(color: PreviewTheme.accentWarning.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SELECT TARGET CLUBBED NOTE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: PreviewTheme.accentWarning,
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _showingTargetPicker = false),
                            child: const Text('Back', style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...otherClusters.map((cluster) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            key: Key('select_target_cluster_${cluster.clusterId}'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              if (widget.onMoveToTargetCluster != null) {
                                widget.onMoveToTargetCluster!(cluster);
                              } else {
                                widget.onMoveToCluster?.call();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: PreviewTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PreviewTheme.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: PreviewTheme.accentAction.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cluster.sequenceNumber,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: PreviewTheme.accentAction,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '[${cluster.folder}] ${cluster.synthesizedContent}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: PreviewTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${cluster.originNotes.length} notes included',
                                          style: const TextStyle(fontSize: 10, color: PreviewTheme.textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: PreviewTheme.accentWarning),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Option 2: Make it an independent note
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('make_it_an_independent_note_btn'),
                  borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onMakeIndependent?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PreviewTheme.surface,
                      borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                      border: Border.all(color: PreviewTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PreviewTheme.accentCapture.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_outlined, color: PreviewTheme.accentCapture, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Make It An Independent Note',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: PreviewTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Detach and generate a separate synthesized note',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PreviewTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: PreviewTheme.textTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
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
      ),
    );
  }
}
