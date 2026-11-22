import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two heavy on-device models that must never be in RAM together.
enum HeavyModel { speech, language }

/// Decides which heavy model may be resident. Capture (speech) always has priority.
class ModelResidencyArbiter {
  HeavyModel? _holder;
  Future<void> Function()? _onPreempt;
  Completer<void>? _languageReleased;
  Future<void>? _preemption;

  /// Set before the preemption callback runs, so a release inside it already hands over to speech.
  bool _speechWaiting = false;

  HeavyModel? get holder => _holder;

  /// Speech always wins. If language holds, invokes the callback it registered and waits until
  /// [releaseLanguage] has been called, then marks speech as holder. Idempotent when speech
  /// already holds; concurrent callers share the same wait.
  Future<void> acquireSpeech() {
    if (_holder == HeavyModel.speech) return Future.value();
    if (_holder == null) {
      _holder = HeavyModel.speech;
      return Future.value();
    }
    final active = _preemption;
    if (active != null) return active;
    _speechWaiting = true;
    return _preemption = _preemptLanguage();
  }

  Future<void> _preemptLanguage() async {
    final released = _languageReleased!.future;
    try {
      await _onPreempt!();
    } catch (_) {
      // Speech must never be blocked forever: treat language as released.
    }
    releaseLanguage();
    await released;
    _holder = HeavyModel.speech;
    _speechWaiting = false;
    _preemption = null;
  }

  void releaseSpeech() {
    if (_holder == HeavyModel.speech) _holder = null;
  }

  /// Returns false when speech holds (or language already holds). [onPreempt] must stop
  /// generation, unload the language model and call [releaseLanguage].
  bool tryAcquireLanguage({required Future<void> Function() onPreempt}) {
    if (_holder != null) return false;
    _holder = HeavyModel.language;
    _onPreempt = onPreempt;
    _languageReleased = Completer<void>();
    return true;
  }

  void releaseLanguage() {
    if (_holder != HeavyModel.language) return;
    // Hand over directly while speech is waiting so language cannot slip in between.
    _holder = _speechWaiting ? HeavyModel.speech : null;
    _onPreempt = null;
    final released = _languageReleased;
    _languageReleased = null;
    if (released != null && !released.isCompleted) released.complete();
  }
}

final modelResidencyArbiterProvider = Provider<ModelResidencyArbiter>((ref) => ModelResidencyArbiter());
