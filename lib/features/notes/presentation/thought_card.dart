import 'package:flutter/material.dart';
import '../data/note_model.dart';

class ThoughtCard extends StatefulWidget {
  final Note note;
  final bool isPlaying;
  final VoidCallback? onPlayAudio;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onCategoryChanged;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const ThoughtCard({
    super.key,
    required this.note,
    this.isPlaying = false,
    this.onPlayAudio,
    this.onEdit,
    this.onCategoryChanged,
    this.onRetry,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  State<ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<ThoughtCard> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  bool _isEditing = false;
  late TextEditingController _textController;
  String? _selectedFolder;
  String? _editedText;

  String get _currentFolder => _selectedFolder ?? widget.note.folder;
  String get _currentText => _editedText ?? widget.note.correctedText;

  static const List<String> availableFolders = ['Work', 'Ideas', 'Journal', 'Todos', 'Uncategorized'];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.note.state == ThoughtState.enqueued) {
      _shimmerController.repeat(reverse: true);
    }
    _shimmerAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_shimmerController);

    _textController = TextEditingController(text: widget.note.correctedText);
  }

  @override
  void didUpdateWidget(covariant ThoughtCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note.state == ThoughtState.enqueued && !_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    } else if (widget.note.state != ThoughtState.enqueued && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }

    if (oldWidget.note.correctedText != widget.note.correctedText && !_isEditing) {
      _editedText = null;
      _textController.text = widget.note.correctedText;
    }
    if (oldWidget.note.folder != widget.note.folder) {
      _selectedFolder = null;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.note.state) {
      case ThoughtState.enqueued:
        return isDark ? const Color(0xFF26200A) : const Color(0xFFFEF3C7);
      case ThoughtState.processed:
        return isDark ? const Color(0xFF111827) : const Color(0xFFDBEAFE);
      case ThoughtState.failed:
        return isDark ? const Color(0xFF271111) : const Color(0xFFFEE2E2);
      case ThoughtState.synthesized:
        return isDark ? const Color(0xFF0D2319) : const Color(0xFFDCFCE7);
    }
  }

  Color _getBorderColor(BuildContext context) {
    switch (widget.note.state) {
      case ThoughtState.enqueued:
        return const Color(0xFFF59E0B).withValues(alpha: 0.4);
      case ThoughtState.processed:
        return const Color(0xFF3B82F6).withValues(alpha: 0.3);
      case ThoughtState.failed:
        return const Color(0xFFEF4444).withValues(alpha: 0.4);
      case ThoughtState.synthesized:
        return const Color(0xFF10B981).withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(context);
    final borderColor = _getBorderColor(context);
    final note = widget.note;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isSelected ? Theme.of(context).colorScheme.primary : borderColor,
          width: widget.isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (widget.isSelectionMode) {
              widget.onTap?.call();
            } else {
              widget.onTap?.call();
            }
          },
          onLongPress: widget.onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Play Audio Button
                    if (note.originalAudioPath != null && note.originalAudioPath!.isNotEmpty)
                      IconButton(
                        key: const Key('play_audio_button'),
                        icon: Icon(
                          widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: _getActionColor(),
                          size: 32,
                        ),
                        onPressed: widget.onPlayAudio,
                        tooltip: widget.isPlaying ? 'Pause original audio' : 'Play original audio',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      Icon(
                        Icons.mic_none,
                        color: _getActionColor(),
                        size: 24,
                      ),
                    const SizedBox(width: 10),

                    // Timestamp
                    Text(
                      _formatDate(note.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Spacer(),

                    // Unread Indicator Dot
                    if (!note.isRead && note.state == ThoughtState.processed)
                      Container(
                        key: const Key('unread_dot'),
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),

                    // Category Pill or State Badge
                    _buildStateOrCategoryBadge(context),

                    // Edit button for processed thoughts
                    if (note.state == ThoughtState.processed && !_isEditing)
                      IconButton(
                        key: const Key('edit_text_button'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        padding: const EdgeInsets.only(left: 6),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Body Section based on ThoughtState
                _buildBodyContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getActionColor() {
    switch (widget.note.state) {
      case ThoughtState.enqueued:
        return const Color(0xFFD97706);
      case ThoughtState.processed:
        return const Color(0xFF2563EB);
      case ThoughtState.failed:
        return const Color(0xFFDC2626);
      case ThoughtState.synthesized:
        return const Color(0xFF059669);
    }
  }

  Widget _buildStateOrCategoryBadge(BuildContext context) {
    final note = widget.note;
    switch (note.state) {
      case ThoughtState.enqueued:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '⏳ Enqueued',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
          ),
        );
      case ThoughtState.failed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '⚠️ Failed',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
          ),
        );
      case ThoughtState.synthesized:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '🧩 Clubbed Note',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
          ),
        );
      case ThoughtState.processed:
        return PopupMenuButton<String>(
          key: const Key('category_dropdown_button'),
          tooltip: 'Change Category',
          initialValue: _currentFolder,
          onSelected: (newFolder) {
            setState(() {
              _selectedFolder = newFolder;
            });
            widget.onCategoryChanged?.call(newFolder);
          },
          itemBuilder: (context) {
            return availableFolders.map((folder) {
              return PopupMenuItem<String>(
                value: folder,
                child: Row(
                  children: [
                    Icon(_getFolderIcon(folder), size: 18),
                    const SizedBox(width: 8),
                    Text(folder),
                  ],
                ),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentFolder,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildBodyContent(BuildContext context) {
    final note = widget.note;

    if (note.state == ThoughtState.enqueued) {
      return FadeTransition(
        opacity: _shimmerAnimation,
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Transcribing & organizing speech...',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (note.state == ThoughtState.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.failureReason ?? 'Error processing voice recording.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              key: const Key('retry_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: widget.onRetry,
            ),
          ),
        ],
      );
    }

    // Processed or Synthesized Thought
    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            key: const Key('inline_edit_textfield'),
            controller: _textController,
            maxLines: null,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _textController.text = note.correctedText;
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('save_edit_button'),
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _editedText = _textController.text;
                  });
                  widget.onEdit?.call(_textController.text);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      );
    }

    return Text(
      _currentText,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.4,
          ),
    );
  }

  IconData _getFolderIcon(String folder) {
    switch (folder.toLowerCase()) {
      case 'ideas':
        return Icons.lightbulb_outline;
      case 'work':
        return Icons.work_outline;
      case 'journal':
        return Icons.book_outlined;
      case 'todos':
        return Icons.check_circle_outline;
      default:
        return Icons.folder_outlined;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
