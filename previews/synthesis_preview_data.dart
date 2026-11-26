import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

/// One state of the Synthesis preview: which notes exist, which are open, the mode and the panel.
class SynthesisPreviewScenario {
  final String label;
  final List<SynthesisCluster> notes;
  final Set<String> openIds;
  final bool readMode;
  final bool panelOpen;
  final int pendingThoughts;

  const SynthesisPreviewScenario({
    required this.label,
    required this.notes,
    this.openIds = const {},
    this.readMode = true,
    this.panelOpen = false,
    this.pendingThoughts = 2,
  });
}

/// Mock Synthesis data for the preview: production [SynthesisCluster]s, dated relative to today
/// so the day headers read `TODAY`, `YESTERDAY` and a date.
class SynthesisPreviewData {
  static const List<String> folderNames = ['Work', 'Personal', 'Journal', 'Uncategorized'];

  static DateTime _at(int daysAgo, int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
  }

  static SynthesisCluster _note(
    String id,
    int number,
    int daysAgo,
    int hour,
    String folder,
    String content, {
    bool unread = false,
    int thoughts = 2,
    String style = defaultNoteStyleId,
    bool reprocessing = false,
  }) {
    final start = _at(daysAgo, hour, 5);
    return SynthesisCluster(
      clusterId: id,
      sequenceNumber: '#S-${number.toString().padLeft(2, '0')}',
      folder: folder,
      synthesizedContent: content,
      sessionStart: start,
      sessionEnd: start.add(Duration(minutes: 4 * thoughts)),
      sessionDuration: Duration(minutes: 4 * thoughts),
      originNotes: [
        for (var i = 0; i < thoughts; i++)
          SynthesisOriginNote(
            id: id.hashCode.abs() % 100000 * 10 + i,
            formattedSequence: '#0${i + 1}',
            cleanedText: 'Spoken thought ${i + 1} behind "$id".',
            timestamp: start.add(Duration(minutes: 4 * i)),
          ),
      ],
      appliedStyleId: style,
      isUnread: unread,
      isReprocessing: reprocessing,
    );
  }

  static const String _tasks = '**Weekend errands**\n\n- [ ] Pick up the parcel.\n- [x] Call the dentist.\n- [ ] Buy almond milk.';
  static const String _bullets =
      '**Quarterly plan**\n\n**Tasks**\n- Prepare the deliverables before the 3 PM sync.\n- Send Marcus the roadmap.\n\n**Notes**\n- Platform leads join the call.';
  static const String _prose = 'Walked home thinking about the move. The new flat is quiet and the rent is fair, but I still worry about the main road.';

  /// Seventeen notes over four days, with every folder, a checklist and a note waiting for its rewrite.
  static List<SynthesisCluster> manyNotes() => [
        _note('n24', 6, 0, 17, 'Work', '**Roadmap review**\n\n- Decide the order of the next three releases.\n- Ask design for the new empty states.', unread: true, thoughts: 3),
        _note('n23', 5, 0, 15, 'Personal', _tasks, unread: true),
        _note('n22', 4, 0, 13, 'Journal', _prose, thoughts: 1),
        _note('n21', 3, 0, 11, 'Work', _bullets, thoughts: 3, reprocessing: true),
        _note('n20', 2, 0, 9, 'Personal', '**Birthday gift ideas**\n\n- A book about sailing.\n- Concert tickets in spring.'),
        _note('n19', 1, 0, 8, 'Uncategorized', 'Remember the umbrella tomorrow, rain from the afternoon.', thoughts: 1),
        _note('n18', 4, 1, 18, 'Work', '**Client call follow-up**\n\n- Send the revised quote.\n- Book a demo for Thursday.', unread: true),
        _note('n17', 3, 1, 16, 'Journal', '**Evening reflection**\n\nA slow day, but the walk helped. I should sleep earlier this week.', thoughts: 1),
        _note('n16', 2, 1, 12, 'Personal', '**Groceries**\n\n- Oats.\n- Eggs.\n- Lemons.', thoughts: 1),
        _note('n15', 1, 1, 9, 'Work', '**Standup notes**\n\n- Blocked on the staging build.\n- Pairing with Sam after lunch.'),
        _note('n14', 4, 3, 19, 'Personal', '**Trip planning**\n\n- Book the train before Friday.\n- Check the hotel cancellation terms.'),
        _note('n13', 3, 3, 14, 'Work', '**Hiring**\n\n- Two interviews on Monday.\n- Send the take-home task.'),
        _note('n12', 2, 3, 10, 'Journal', '**Morning pages**\n\nWoke up early and felt calm.', thoughts: 1),
        _note('n11', 1, 3, 8, 'Uncategorized', 'Idea: a shelf above the desk for the plants.', thoughts: 1),
        _note('n10', 3, 4, 17, 'Work', '**Budget**\n\n- Cut the unused licences.\n- Review the cloud bill.'),
        _note('n09', 2, 4, 13, 'Personal', '**Gym plan**\n\n- Three sessions a week.\n- Start with legs on Monday.'),
        _note('n08', 1, 4, 9, 'Journal', '**Gratitude**\n\nThankful for the quiet morning and good coffee.', thoughts: 1),
      ];

  /// [manyNotes] with one note edited by hand.
  static List<SynthesisCluster> _withHandEdited() {
    final notes = manyNotes();
    return [
      for (final n in notes)
        if (n.clusterId == 'n20')
          n.copyWith(
            synthesizedContent: '**Birthday gift ideas**\n\nA book about sailing, concert tickets in spring. Ask Mia first.',
            appliedStyleId: manualStyleId,
          )
        else
          n,
    ];
  }

  static List<SynthesisPreviewScenario> get scenarios => [
        SynthesisPreviewScenario(label: 'Many notes', notes: manyNotes()),
        SynthesisPreviewScenario(label: 'Open (Read)', notes: manyNotes(), openIds: const {'n24', 'n23', 'n21'}),
        SynthesisPreviewScenario(
          label: 'Edit mode',
          notes: _withHandEdited(),
          openIds: const {'n24', 'n20'},
          readMode: false,
        ),
        SynthesisPreviewScenario(label: 'Folder panel', notes: manyNotes(), panelOpen: true),
      ];
}
