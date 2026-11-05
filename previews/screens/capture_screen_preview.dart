import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';
import 'style_rewriter_preview.dart';

class CaptureScreenPreview extends StatefulWidget {
  const CaptureScreenPreview({super.key});

  @override
  State<CaptureScreenPreview> createState() => _CaptureScreenPreviewState();
}

class _CaptureScreenPreviewState extends State<CaptureScreenPreview> {
  late List<MockCaptureNote> _notes;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _notes = List.from(MockData.captureNotes);
  }

  void _togglePlay(String id) {
    setState(() {
      if (_currentlyPlayingId == id) {
        _currentlyPlayingId = null;
      } else {
        _currentlyPlayingId = id;
      }
    });
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
    });
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1 && _notes[index].isUnread) {
        _notes[index] = _notes[index].copyWith(isUnread: false);
      }
    });
  }

  void _manualEdit(MockCaptureNote note) {
    final controller = TextEditingController(text: note.cleanedText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PreviewTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Note ${note.formattedSequence}',
          style: const TextStyle(color: PreviewTheme.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: PreviewTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PreviewTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PreviewTheme.accentAction),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: PreviewTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PreviewTheme.accentAction,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                final index = _notes.indexWhere((n) => n.id == note.id);
                if (index != -1) {
                  _notes[index] = _notes[index].copyWith(cleanedText: controller.text);
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openStyleRewriter(MockCaptureNote note) {
    StyleRewriterModal.show(
      context,
      note: note,
      onSelectPreset: (preset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PreviewTheme.surfaceElevated,
            content: Text(
              'Applying style "${preset.name}" to ${note.formattedSequence}...',
              style: const TextStyle(color: PreviewTheme.textPrimary),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PreviewTheme.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section Header: Grouping & Daily Counter Reset
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'TODAY — 05/11 (#01 - #04)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: PreviewTheme.textSecondary.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Thought Feed
          ..._notes.map((note) => _buildCaptureCard(note)),
          const SizedBox(height: 24),
          // Ambient Hardware Trigger Hint
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: PreviewTheme.surfaceElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                border: Border.all(color: PreviewTheme.borderSubtle),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_none, color: PreviewTheme.accentCapture, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Press Vol Up + Vol Down to Capture',
                    style: TextStyle(
                      fontSize: 12,
                      color: PreviewTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCaptureCard(MockCaptureNote note) {
    final isPlaying = _currentlyPlayingId == note.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: PreviewTheme.cardDecoration(
        bgColor: PreviewTheme.captureCardBg,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PreviewTheme.cardRadius),
          onTap: () => _markAsRead(note.id),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Ordering Contract:
                // [# Number] -> [▶ Play Button] -> [• Unread Dot] -> [🗑️ Delete]
                Row(
                  children: [
                    // 1. # Daily Sequence Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PreviewTheme.numberBadgeBg,
                        borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                      ),
                      child: Text(
                        note.formattedSequence,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PreviewTheme.numberBadgeText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 2. Play Button
                    Material(
                      color: isPlaying
                          ? PreviewTheme.accentCapture.withOpacity(0.2)
                          : PreviewTheme.surfaceElevated,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                        side: BorderSide(
                          color: isPlaying
                              ? PreviewTheme.accentCapture
                              : PreviewTheme.borderSubtle,
                        ),
                      ),
                      child: InkWell(
                        key: Key('play_button_${note.id}'),
                        borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                        onTap: () => _togglePlay(note.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 14,
                                color: isPlaying
                                    ? PreviewTheme.accentCapture
                                    : PreviewTheme.textPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                note.formattedAudioDuration,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isPlaying
                                      ? PreviewTheme.accentCapture
                                      : PreviewTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 3. Unread Indicator Dot
                    if (note.isUnread) ...[
                      Container(
                        key: Key('unread_dot_${note.id}'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: PreviewTheme.unreadDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // 4. Delete Action
                    IconButton(
                      key: Key('delete_button_${note.id}'),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: PreviewTheme.textTertiary,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _deleteNote(note.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Cleaned Text Body (STT + Grammar cleaned, NO color coding/categorization)
                Text(
                  note.cleanedText,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: PreviewTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: PreviewTheme.borderSubtle),
                const SizedBox(height: 10),
                // Bottom Footer: Date then Time: "DD/MM  HH:MM AM/PM" + Actions
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      note.formattedTimestamp,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PreviewTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Manual Edit Action
                        InkWell(
                          key: Key('edit_button_${note.id}'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _manualEdit(note),
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
                        const SizedBox(width: 8),
                        // AI Style Re-Writer Action
                        InkWell(
                          key: Key('style_button_${note.id}'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _openStyleRewriter(note),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: PreviewTheme.accentAI.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                              border: Border.all(color: PreviewTheme.accentAI.withOpacity(0.24)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 13, color: PreviewTheme.accentAI),
                                SizedBox(width: 4),
                                Text(
                                  'Style ▾',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: PreviewTheme.accentAI,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
