import 'dart:async';

import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_ejection_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/synthesis/presentation/note_merge_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/note_text_editor_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/rewrite_confirmation.dart';
import 'package:eudemonia/features/synthesis/presentation/style_rewriter_sheet.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_filtering.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_view.dart';
import '../preview_theme.dart';
import '../synthesis_preview_data.dart';

/// The Synthesis tab driven by mock scenarios. It renders the production [SynthesisView] with
/// its production sheets; the callbacks only change the mock notes held here.
class SynthesisScreenPreview extends StatefulWidget {
  final int initialScenario;

  const SynthesisScreenPreview({super.key, this.initialScenario = 0});

  @override
  State<SynthesisScreenPreview> createState() => _SynthesisScreenPreviewState();
}

class _SynthesisScreenPreviewState extends State<SynthesisScreenPreview> with AutomaticKeepAliveClientMixin {
  late final List<SynthesisPreviewScenario> _scenarios = SynthesisPreviewData.scenarios;
  late int _index = widget.initialScenario;

  late List<SynthesisCluster> _notes;
  final Map<String, bool> _open = {};
  late bool _readMode;
  late bool _panelOpen;
  late int _pendingThoughts;
  String? _folder;
  SynthesisTriage _triage = SynthesisTriage.all;

  /// A synthesis run is going: Synthesize Now shows the AI thinking, unclickable (FR11.16).
  bool _synthesizing = false;
  Timer? _runTimer;

  /// The shell swipes between tabs; this one keeps its state while away.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(_index);
  }

  @override
  void dispose() {
    _runTimer?.cancel();
    super.dispose();
  }

  void _load(int index) {
    _index = index;
    final scenario = _scenarios[index];
    _notes = List.of(scenario.notes);
    _open
      ..clear()
      ..addEntries([for (final id in scenario.openIds) MapEntry(id, true)]);
    _readMode = scenario.readMode;
    _panelOpen = scenario.panelOpen;
    _pendingThoughts = scenario.pendingThoughts;
    _folder = null;
    _triage = SynthesisTriage.all;
  }

  /// Plays a short fake run: busy at once, done after a moment.
  void _startFakeRun() {
    setState(() => _synthesizing = true);
    _runTimer?.cancel();
    _runTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _synthesizing = false;
        _pendingThoughts = 0;
      });
    });
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PreviewTheme.surfaceElevated,
        content: Text(message, style: const TextStyle(color: PreviewTheme.textPrimary)),
      ),
    );
  }

  void _change(String id, SynthesisCluster Function(SynthesisCluster) change) {
    setState(() => _notes = [for (final n in _notes) n.clusterId == id ? change(n) : n]);
  }

  Future<void> _chooseStyle(SynthesisCluster note) async {
    if (note.isHandEdited && !await confirmRewriteOfHandEditedNote(context)) return;
    if (!mounted) return;
    StyleRewriterModal.show(
      context,
      sequenceLabel: note.sequenceNumber,
      selectedPresetId: note.appliedStyleId,
      onSelectPreset: (preset) {
        _change(note.clusterId, (n) => n.copyWith(appliedStyleId: preset.id, isReprocessing: true));
        _say('Applying style "${preset.name}" to ${note.sequenceNumber}...');
      },
    );
  }

  void _editText(SynthesisCluster note) {
    NoteTextEditorSheet.show(
      context,
      sequenceLabel: note.sequenceNumber,
      initialText: note.synthesizedContent,
      onSave: (text) async {
        if (text.trim().isEmpty) return false;
        _change(note.clusterId, (n) => n.copyWith(synthesizedContent: text, appliedStyleId: manualStyleId));
        return true;
      },
    );
  }

  void _merge(SynthesisCluster note) {
    NoteMergeModal.show(
      context,
      sourceCluster: note,
      availableClusters: _notes,
      onMergeToTargetCluster: (target) {
        setState(() {
          _notes = [
            for (final n in _notes)
              if (n.clusterId == target.clusterId)
                n.copyWith(originNotes: [...n.originNotes, ...note.originNotes], isReprocessing: true)
              else if (n.clusterId != note.clusterId)
                n,
          ];
        });
        _say('Merged [${note.sequenceNumber}] into ${sessionReferenceLabel(target, relativeTo: note.sessionStart)}');
      },
    );
  }

  List<SynthesisOriginNote> _without(SynthesisCluster note, SynthesisOriginNote thought) =>
      [for (final o in note.originNotes) if (o.id != thought.id) o];

  void _moveOut(SynthesisCluster note, SynthesisOriginNote thought) {
    NoteEjectionModal.show(
      context,
      rawNote: thought,
      currentCluster: note,
      availableClusters: _notes,
      onMoveToTargetCluster: (target) {
        setState(() {
          _notes = [
            for (final n in _notes)
              if (n.clusterId == note.clusterId)
                n.copyWith(originNotes: _without(n, thought), isReprocessing: true)
              else if (n.clusterId == target.clusterId)
                n.copyWith(originNotes: [...n.originNotes, thought], isReprocessing: true)
              else
                n,
          ];
        });
        _say('Moved [${thought.formattedSequence}] to ${sessionReferenceLabel(target, relativeTo: note.sessionStart)}');
      },
      onMakeIndependent: () {
        setState(() {
          final independent = SynthesisCluster(
            clusterId: 'independent_${thought.id}',
            sequenceNumber: formatSessionLabel(nextSessionNumber(_notes, thought.timestamp)),
            folder: note.folder,
            synthesizedContent: thought.cleanedText,
            sessionStart: thought.timestamp,
            sessionEnd: thought.timestamp.add(const Duration(minutes: 5)),
            sessionDuration: const Duration(minutes: 5),
            originNotes: [thought],
            isUnread: true,
          );
          _notes = [
            independent,
            for (final n in _notes)
              if (n.clusterId == note.clusterId) n.copyWith(originNotes: _without(n, thought), isReprocessing: true) else n,
          ];
        });
        _say('Promoted [${thought.formattedSequence}] to independent synthesized note.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < _scenarios.length; i++)
                ChoiceChip(
                  key: Key('synthesis_scenario_$i'),
                  label: Text(_scenarios[i].label, style: const TextStyle(fontSize: 11)),
                  selected: i == _index,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _load(i)),
                ),
            ],
          ),
        ),
        Expanded(
          child: SynthesisView(
            notes: _notes,
            folderNames: SynthesisPreviewData.folderNames,
            folder: _folder,
            triage: _triage,
            readMode: _readMode,
            panelOpen: _panelOpen,
            isOpen: (id) => _open[id] ?? false,
            hasWritingModel: true,
            pendingThoughts: _pendingThoughts,
            synthesisBusy: _synthesizing,
            onFolderButton: () => setState(() => _panelOpen = !_panelOpen),
            onDismissPanel: () => setState(() => _panelOpen = false),
            onToggleAll: (ids, open) => setState(() {
              for (final id in ids) {
                _open[id] = open;
              }
            }),
            onReadModeChanged: (readMode) => setState(() => _readMode = readMode),
            onSelectAllNotes: () => setState(() {
              _folder = null;
              _panelOpen = false;
            }),
            onSelectFolder: (name) => setState(() {
              _folder = name;
              _panelOpen = false;
            }),
            onTriageChanged: (triage) => setState(() => _triage = triage),
            onManageFolders: () {
              setState(() => _panelOpen = false);
              _say('Settings would open here.');
            },
            onChooseModel: () => _say('The model setup would open here.'),
            onSynthesizeNow: () {
              _startFakeRun();
              _say('Triggered on-demand synthesis clustering.');
            },
            onToggleNote: (note) {
              final wasOpen = _open[note.clusterId] ?? false;
              setState(() => _open[note.clusterId] = !wasOpen);
              if (!wasOpen) _change(note.clusterId, (n) => n.copyWith(isUnread: false));
            },
            onNoteRead: (id) => _change(id, (n) => n.copyWith(isUnread: false)),
            onTaskToggled: (id, index, checked) =>
                _change(id, (n) => n.copyWith(synthesizedContent: setTaskChecked(n.synthesizedContent, index, checked))),
            onToggleThoughts: (id) => _change(id, (n) => n.copyWith(isExpanded: !n.isExpanded)),
            onFolderChanged: (id, name) => _change(id, (n) => n.copyWith(folder: name)),
            onStyle: _chooseStyle,
            onEditText: _editText,
            onMerge: _merge,
            onDelete: (note) => setState(() => _notes = [for (final n in _notes) if (n.clusterId != note.clusterId) n]),
            onMoveOut: _moveOut,
          ),
        ),
      ],
    );
  }
}
