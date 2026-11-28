import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

/// Which notes the triage chips show: every note, only unread ones or only read ones.
enum SynthesisTriage { all, unread, read }

bool matchesTriage(SynthesisCluster note, SynthesisTriage triage) => switch (triage) {
      SynthesisTriage.all => true,
      SynthesisTriage.unread => note.isUnread,
      SynthesisTriage.read => !note.isUnread,
    };

/// [folder] null is "All notes". Folder names are compared without regard to case.
bool matchesFolder(SynthesisCluster note, String? folder) =>
    folder == null || note.folder.toLowerCase() == folder.toLowerCase();

/// The notes to list: the ones matching [folder] and [triage] (plus those of [keep] that match
/// [folder], whatever their read state now is), newest day first and, inside a day, the highest
/// `#S-NN` first.
List<SynthesisCluster> visibleNotes(
  List<SynthesisCluster> notes, {
  String? folder,
  SynthesisTriage triage = SynthesisTriage.all,
  Set<String> keep = const {},
}) {
  return [
    for (final n in notes)
      if (matchesFolder(n, folder) && (matchesTriage(n, triage) || keep.contains(n.clusterId))) n,
  ]..sort(newestFirst);
}

int newestFirst(SynthesisCluster a, SynthesisCluster b) {
  final byDay = b.sessionDay.compareTo(a.sessionDay);
  return byDay != 0
      ? byDay
      : sessionLabelNumber(b.sequenceNumber).compareTo(sessionLabelNumber(a.sequenceNumber));
}

/// One row of the folder panel: a folder with how many notes it holds and how many are unread.
class FolderCount {
  final String name;
  final int count;
  final int unread;

  const FolderCount({required this.name, required this.count, required this.unread});
}

/// One entry per folder of [folderNames] in that order, then one for every other folder that
/// still holds notes (a folder removed since, in the order its notes first appear).
List<FolderCount> folderCounts(List<SynthesisCluster> notes, List<String> folderNames) {
  final names = [...folderNames];
  for (final n in notes) {
    if (!names.any((f) => f.toLowerCase() == n.folder.toLowerCase())) names.add(n.folder);
  }
  return [
    for (final name in names)
      FolderCount(
        name: name,
        count: notes.where((n) => matchesFolder(n, name)).length,
        unread: notes.where((n) => matchesFolder(n, name) && n.isUnread).length,
      ),
  ];
}
