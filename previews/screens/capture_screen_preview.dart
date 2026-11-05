import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';
import 'style_rewriter_preview.dart';

class CaptureScreenPreview extends StatefulWidget {
  final List<MockCaptureNote>? initialNotes;

  const CaptureScreenPreview({super.key, this.initialNotes});

  @override
  State<CaptureScreenPreview> createState() => _CaptureScreenPreviewState();
}

class _CaptureScreenPreviewState extends State<CaptureScreenPreview> with SingleTickerProviderStateMixin {
  late List<MockCaptureNote> _notes;
  String? _currentlyPlayingId;

  // Filter 1: Read / Unread
  String _readFilter = 'All'; // 'All', 'Unread', 'Read'

  // Filter 2: Processing Status
  String _statusFilter = 'All'; // 'All', 'Processing', 'Processed', 'Synthesized', 'Failed'

  // Floating Soft Capture Button state
  bool _isRecording = false;
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.initialNotes ?? MockData.captureNotes);
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _waveformController.dispose();
    super.dispose();
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

  void _retryNote(MockCaptureNote note) {
    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note.copyWith(
          status: MockNoteStatus.pending,
          cleanedText: 'Retrying speech transcription & language cleanup...',
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PreviewTheme.surfaceElevated,
        content: Text(
          'Retrying ${note.formattedSequence}... Reset to pending queue.',
          style: const TextStyle(color: PreviewTheme.textPrimary),
        ),
      ),
    );
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

  void _toggleRecording() {
    setState(() {
      if (!_isRecording) {
        _isRecording = true;
        _waveformController.repeat(reverse: true);
      } else {
        _isRecording = false;
        _waveformController.stop();
        _waveformController.reset();
        // Enqueue new Yellow pending note at top
        final newSeq = _notes.isEmpty ? 1 : (_notes.map((n) => n.dailySequenceNumber).reduce(math.max) + 1);
        final newNote = MockCaptureNote(
          id: 'note_${DateTime.now().millisecondsSinceEpoch}',
          dailySequenceNumber: newSeq,
          timestamp: DateTime.now(),
          audioFilePath: '/audio/new_capture.wav',
          audioDuration: const Duration(seconds: 4),
          cleanedText: 'Transcribing speech and cleaning language on-device...',
          isUnread: true,
          status: MockNoteStatus.pending,
        );
        _notes.insert(0, newNote);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PreviewTheme.surfaceElevated,
            content: Text(
              'Captured new note [#0$newSeq]. Enqueued as Yellow pending note.',
              style: const TextStyle(color: PreviewTheme.textPrimary),
            ),
          ),
        );
      }
    });
  }

  List<MockCaptureNote> get _filteredNotes {
    return _notes.where((note) {
      final matchesRead = _readFilter == 'All' ||
          (_readFilter == 'Unread' && note.isUnread) ||
          (_readFilter == 'Read' && !note.isUnread);

      final matchesStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Processing' && note.status == MockNoteStatus.pending) ||
          (_statusFilter == 'Processed' && note.status == MockNoteStatus.processed) ||
          (_statusFilter == 'Synthesized' && note.status == MockNoteStatus.synthesized) ||
          (_statusFilter == 'Failed' && note.status == MockNoteStatus.failed);

      return matchesRead && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Container(
      color: PreviewTheme.background,
      child: Stack(
        children: [
          // Scrolling Feed
          ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 96.0),
            children: [
              // Dual Filter Bar
              _buildFilterSection(),
              const SizedBox(height: 12),

              // Section Header: Grouping & Daily Counter Reset
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'TODAY — 05/11 (${_notes.length} captured)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      'Showing ${filtered.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: PreviewTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Thought Feed
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32.0),
                  alignment: Alignment.center,
                  child: const Text(
                    'No thoughts matching active filters',
                    style: TextStyle(color: PreviewTheme.textTertiary, fontSize: 13),
                  ),
                )
              else
                ...filtered.map((note) => _buildCaptureCard(note)),

              const SizedBox(height: 16),
            ],
          ),

          // Floating Clickable Capture Trigger (Sticky at bottom center)
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Center(
              child: _buildFloatingCaptureButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter 1: Read / Unread Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'TRIAGE:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: PreviewTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip('All', _readFilter == 'All', (val) {
                if (val) setState(() => _readFilter = 'All');
              }, const Key('filter_read_all')),
              const SizedBox(width: 6),
              _buildFilterChip('Unread', _readFilter == 'Unread', (val) {
                if (val) setState(() => _readFilter = 'Unread');
              }, const Key('filter_read_unread')),
              const SizedBox(width: 6),
              _buildFilterChip('Read', _readFilter == 'Read', (val) {
                if (val) setState(() => _readFilter = 'Read');
              }, const Key('filter_read_read')),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Filter 2: Processing Status Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'STATE:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: PreviewTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip('All', _statusFilter == 'All', (val) {
                if (val) setState(() => _statusFilter = 'All');
              }, const Key('filter_status_all')),
              const SizedBox(width: 6),
              _buildFilterChip('Processing', _statusFilter == 'Processing', (val) {
                if (val) setState(() => _statusFilter = 'Processing');
              }, const Key('filter_status_processing'), color: PreviewTheme.accentWarning),
              const SizedBox(width: 6),
              _buildFilterChip('Processed', _statusFilter == 'Processed', (val) {
                if (val) setState(() => _statusFilter = 'Processed');
              }, const Key('filter_status_processed'), color: PreviewTheme.accentAction),
              const SizedBox(width: 6),
              _buildFilterChip('Synthesized', _statusFilter == 'Synthesized', (val) {
                if (val) setState(() => _statusFilter = 'Synthesized');
              }, const Key('filter_status_synthesized'), color: PreviewTheme.accentCapture),
              const SizedBox(width: 6),
              _buildFilterChip('Failed', _statusFilter == 'Failed', (val) {
                if (val) setState(() => _statusFilter = 'Failed');
              }, const Key('filter_status_failed'), color: PreviewTheme.accentError),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, ValueChanged<bool> onSelected, Key key, {Color? color}) {
    final activeColor = color ?? PreviewTheme.accentAction;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: activeColor.withValues(alpha: 0.2),
      backgroundColor: PreviewTheme.surfaceElevated,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? activeColor : PreviewTheme.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
        side: BorderSide(
          color: isSelected ? activeColor.withValues(alpha: 0.4) : PreviewTheme.borderSubtle,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFloatingCaptureButton() {
    if (_isRecording) {
      // Recording State: listening loader & pulsating waveform widget inside button
      return Material(
        color: const Color(0xFF0F291E),
        elevation: 8,
        shadowColor: PreviewTheme.accentCapture.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
          side: const BorderSide(color: PreviewTheme.accentCapture, width: 1.5),
        ),
        child: InkWell(
          key: const Key('floating_capture_button_active'),
          borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
          onTap: _toggleRecording,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_circle, color: PreviewTheme.accentCapture, size: 22),
                  const SizedBox(width: 10),
                  // Live Waveform Visualizer inside the button
                  _buildLiveWaveformWidget(),
                  const SizedBox(width: 10),
                  const Text(
                    '00:04 • Tap to Stop',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: PreviewTheme.accentCapture,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Idle State: Larger mic, slash "/" separator, clickable trigger
    return Material(
      color: const Color(0xFF1F1F27),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
        side: BorderSide(color: PreviewTheme.accentCapture.withValues(alpha: 0.45), width: 1.2),
      ),
      child: InkWell(
        key: const Key('floating_capture_button'),
        borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
        onTap: _toggleRecording,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: PreviewTheme.accentCapture, size: 22),
                SizedBox(width: 8),
                Text(
                  '/',
                  style: TextStyle(
                    color: PreviewTheme.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Press Vol Up + Down to Capture',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PreviewTheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWaveformWidget() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, _) {
        final anim = _waveformController.value;
        const barCount = 7;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(barCount, (i) {
            final phase = (i / barCount) * math.pi;
            final height = 6.0 + 14.0 * math.sin(anim * math.pi + phase).abs();
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: PreviewTheme.accentCapture,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCaptureCard(MockCaptureNote note) {
    final isPlaying = _currentlyPlayingId == note.id;

    // Point 1: Color coding by status
    Color cardBg;
    Color cardBorder;
    switch (note.status) {
      case MockNoteStatus.pending:
        cardBg = PreviewTheme.stateEnqueuedBg; // Yellow / Amber
        cardBorder = PreviewTheme.stateEnqueuedBorder;
        break;
      case MockNoteStatus.processed:
        cardBg = PreviewTheme.stateProcessedBg; // Blue
        cardBorder = PreviewTheme.stateProcessedBorder;
        break;
      case MockNoteStatus.synthesized:
        cardBg = PreviewTheme.stateSynthesizedBg; // Green
        cardBorder = PreviewTheme.stateSynthesizedBorder;
        break;
      case MockNoteStatus.failed:
        cardBg = PreviewTheme.stateFailedBg; // Red
        cardBorder = PreviewTheme.stateFailedBorder;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: PreviewTheme.cardDecoration(
        bgColor: cardBg,
        borderColor: cardBorder,
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
                          ? PreviewTheme.accentCapture.withValues(alpha: 0.2)
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

                // Status Badge for Pending / Synthesized / Failed
                if (note.status == MockNoteStatus.pending) ...[
                  Container(
                    key: Key('status_badge_${note.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PreviewTheme.accentWarning.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                      border: Border.all(color: PreviewTheme.accentWarning.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top, size: 12, color: PreviewTheme.accentWarning),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Transcribing audio & cleaning speech...',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PreviewTheme.accentWarning),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (note.status == MockNoteStatus.synthesized) ...[
                  Container(
                    key: Key('status_badge_${note.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PreviewTheme.accentCapture.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                      border: Border.all(color: PreviewTheme.accentCapture.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 12, color: PreviewTheme.accentCapture),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Synthesized in ${note.clusterSequence ?? 'Session Note'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PreviewTheme.accentCapture),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (note.status == MockNoteStatus.failed) ...[
                  Container(
                    key: Key('status_badge_${note.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PreviewTheme.accentError.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                      border: Border.all(color: PreviewTheme.accentError.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 12, color: PreviewTheme.accentError),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            note.failureMessage ?? 'Speech transcription failed',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PreviewTheme.accentError),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Cleaned Text Body
                Text(
                  note.cleanedText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: note.status == MockNoteStatus.pending
                        ? PreviewTheme.textSecondary
                        : PreviewTheme.textPrimary,
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
                        if (note.status == MockNoteStatus.failed) ...[
                          InkWell(
                            key: Key('retry_button_${note.id}'),
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _retryNote(note),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: PreviewTheme.accentError.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                                border: Border.all(color: PreviewTheme.accentError.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 13, color: PreviewTheme.accentError),
                                  SizedBox(width: 4),
                                  Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: PreviewTheme.accentError,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
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
                                color: PreviewTheme.accentAI.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                                border: Border.all(color: PreviewTheme.accentAI.withValues(alpha: 0.24)),
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
