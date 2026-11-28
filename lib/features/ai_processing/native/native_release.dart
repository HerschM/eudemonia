import 'dart:ffi';

/// Frees one kind of native handle (one C free function) exactly once: through [release] when
/// its owner is disposed, or by a [NativeFinalizer] when the owner's isolate shuts down without
/// that. A worker isolate ends without running Dart code when the Flutter engine is destroyed
/// or the isolate is killed; the Dart VM still runs the native finalizers attached in it.
///
/// The finalizer also runs when the owner is garbage collected; owners that must free several
/// handles in a fixed order stay strongly reachable until they are disposed (see
/// `NativeLlamaBackend`).
class NativeRelease {
  final NativeFinalizer _finalizer;

  NativeRelease(Pointer<NativeFinalizerFunction> free) : _finalizer = NativeFinalizer(free);

  /// Frees [handle] when [owner]'s isolate shuts down, unless [release] comes first. One handle
  /// per owner and [NativeRelease].
  void attach(Finalizable owner, Pointer<NativeType> handle) =>
      _finalizer.attach(owner, handle.cast(), detach: owner);

  /// Detaches [owner]'s handle, then frees it through [free]: the finalizer never sees it again,
  /// so nothing is freed twice.
  void release(Finalizable owner, void Function() free) {
    _finalizer.detach(owner);
    free();
  }
}
