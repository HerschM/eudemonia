import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';

/// Which thoughts the Capture view shows by whether they were seen: all, only unread or only read.
enum CaptureTriageFilter { all, unread, read }

/// Which thoughts the Capture view shows by where they are in the pipeline.
enum CaptureStatusFilter { all, processing, processed, synthesized, failed }

bool matchesCaptureTriage(Note n, CaptureTriageFilter filter) => switch (filter) {
      CaptureTriageFilter.all => true,
      CaptureTriageFilter.unread => !n.isRead,
      CaptureTriageFilter.read => n.isRead,
    };

/// A recording with no speech in it is not a failure, so the Failed status leaves it out.
bool matchesCaptureStatus(Note n, CaptureStatusFilter filter) => switch (filter) {
      CaptureStatusFilter.all => true,
      CaptureStatusFilter.processing => n.state == ThoughtState.enqueued,
      CaptureStatusFilter.processed => n.state == ThoughtState.processed,
      CaptureStatusFilter.synthesized => n.state == ThoughtState.synthesized,
      CaptureStatusFilter.failed => n.state == ThoughtState.failed && !isSilentRecordingMessage(n.failureReason),
    };

/// The word the view panel shows for [filter].
String captureTriageLabel(CaptureTriageFilter filter) => switch (filter) {
      CaptureTriageFilter.all => 'All thoughts',
      CaptureTriageFilter.unread => 'Unread',
      CaptureTriageFilter.read => 'Read',
    };

String captureStatusLabel(CaptureStatusFilter filter) => switch (filter) {
      CaptureStatusFilter.all => 'Any status',
      CaptureStatusFilter.processing => 'Processing',
      CaptureStatusFilter.processed => 'Processed',
      CaptureStatusFilter.synthesized => 'Synthesized',
      CaptureStatusFilter.failed => 'Failed',
    };

/// The title of the Capture bar: names what the two filters show together, `All thoughts`,
/// `Unread`, `Failed`, `Unread · Failed`, and so on.
String captureViewTitle(CaptureTriageFilter triage, CaptureStatusFilter status) {
  final seen = triage == CaptureTriageFilter.all ? null : captureTriageLabel(triage);
  final where = status == CaptureStatusFilter.all ? null : captureStatusLabel(status);
  if (seen == null && where == null) return captureTriageLabel(CaptureTriageFilter.all);
  return [?seen, ?where].join(' · ');
}

/// How many of [thoughts] each row of the view panel would list, given the other group's current
/// choice: the Show counts follow [status], the Status counts follow [triage].
class CaptureViewCounts {
  final Map<CaptureTriageFilter, int> show;
  final Map<CaptureStatusFilter, int> status;

  const CaptureViewCounts({required this.show, required this.status});

  factory CaptureViewCounts.of(
    List<Note> thoughts, {
    required CaptureTriageFilter triage,
    required CaptureStatusFilter statusFilter,
  }) {
    return CaptureViewCounts(
      show: {
        for (final t in CaptureTriageFilter.values)
          t: thoughts.where((n) => matchesCaptureTriage(n, t) && matchesCaptureStatus(n, statusFilter)).length,
      },
      status: {
        for (final s in CaptureStatusFilter.values)
          s: thoughts.where((n) => matchesCaptureTriage(n, triage) && matchesCaptureStatus(n, s)).length,
      },
    );
  }
}
