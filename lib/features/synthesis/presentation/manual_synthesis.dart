import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/models/presentation/model_setup_screen.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Starts a manual synthesis run without waiting for it (a run takes minutes) and reports
/// whether it started.
Future<void> startManualSynthesis(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  if (container.read(synthesisRunningProvider)) {
    _show(messenger, 'Synthesis is already running.');
    return;
  }

  // Resolves with null once the run holds the model, or with the result of a run that ended before that.
  final outcome = Completer<SynthesisRunResult?>();
  final sub = container.listen<bool>(synthesisRunningProvider, (_, running) {
    if (running && !outcome.isCompleted) outcome.complete(null);
  });
  unawaited(container.read(synthesisRunnerProvider).run(manual: true).then((result) {
    if (!outcome.isCompleted) outcome.complete(result);
  }));
  final early = await outcome.future;
  sub.close();

  if (early == SynthesisRunResult.noModel) {
    _show(
      messenger,
      'Choose a writing model first',
      actionLabel: 'Choose',
      onAction: () => openModelSetup(navigator),
    );
    return;
  }

  _show(
    messenger,
    switch (early) {
      null => 'Synthesis started.',
      SynthesisRunResult.busy => 'Capture is busy. Try again in a moment.',
      SynthesisRunResult.nothingToDo => 'Nothing to synthesize.',
      SynthesisRunResult.failed => 'Synthesis could not start.',
      SynthesisRunResult.completed || SynthesisRunResult.preempted => 'Synthesis finished.',
      SynthesisRunResult.noModel => 'Choose a writing model first',
    },
  );
}

void _show(ScaffoldMessengerState messenger, String message, {String? actionLabel, VoidCallback? onAction}) {
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.surfaceElevated,
      content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
      duration: Duration(seconds: actionLabel == null ? 2 : 4),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(label: actionLabel, textColor: AppColors.accentAction, onPressed: onAction),
    ),
  );
}
