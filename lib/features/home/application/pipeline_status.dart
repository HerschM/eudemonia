import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/resident_model.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';

/// The one picture of the on-device pipeline that the top-bar chip and every line of the status
/// sheet are drawn from, so they never disagree.
@immutable
class PipelineStatus {
  /// Recordings waiting for or in transcription.
  final int transcribing;

  /// Thoughts waiting in Capture for synthesis.
  final int readyThoughts;

  /// Notes flagged to be rewritten (a merge, a moved or edited thought, a style or folder change).
  final int rewriting;

  /// A synthesis run holds the writing model, or one was just asked for; also a rewrite or
  /// restyle with no new thoughts.
  final bool synthesizing;
  final ResidentModel residentModel;

  const PipelineStatus({
    this.transcribing = 0,
    this.readyThoughts = 0,
    this.rewriting = 0,
    this.synthesizing = false,
    this.residentModel = ResidentModel.none,
  });

  /// What the chip counts as in the pipeline.
  int get pending => transcribing + readyThoughts + rewriting;

  /// False only when the chip may say the pipeline is in sync.
  bool get isActive => synthesizing || pending > 0;

  @override
  bool operator ==(Object other) =>
      other is PipelineStatus &&
      other.transcribing == transcribing &&
      other.readyThoughts == readyThoughts &&
      other.rewriting == rewriting &&
      other.synthesizing == synthesizing &&
      other.residentModel == residentModel;

  @override
  int get hashCode => Object.hash(transcribing, readyThoughts, rewriting, synthesizing, residentModel);
}

final pipelineStatusProvider = Provider<PipelineStatus>((ref) => PipelineStatus(
      transcribing: ref.watch(pendingQueueCountProvider),
      readyThoughts: ref.watch(rawNotesReadyToClusterCountProvider).value ?? 0,
      rewriting: ref.watch(synthesisRepositoryProvider.select((s) => s.where((c) => c.isReprocessing).length)),
      synthesizing: ref.watch(synthesisBusyProvider),
      residentModel: ref.watch(residentModelProvider),
    ));
