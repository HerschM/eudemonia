import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two stages of the navigation shell, in tab order.
enum ShellTab { capture, synthesis }

/// Which tab the shell shows. Null while no shell hosts the screens (isolated screens in tests).
class SelectedShellTabNotifier extends Notifier<ShellTab?> {
  @override
  ShellTab? build() => null;

  void select(ShellTab tab) => state = tab;
}

final selectedShellTabProvider =
    NotifierProvider<SelectedShellTabNotifier, ShellTab?>(SelectedShellTabNotifier.new);

/// Whether [tab] is the one in front of the user. True for every tab when there is no shell,
/// so a screen shown on its own behaves as the visible one.
final shellTabActiveProvider = Provider.family<bool, ShellTab>((ref, tab) {
  final selected = ref.watch(selectedShellTabProvider);
  return selected == null || selected == tab;
});

/// A request to bring one synthesis session into view, by `clusterId`: set when the user taps the
/// session number on a Capture card, consumed (and cleared) by the Synthesis screen. The shell
/// switches to the Synthesis tab while a request is pending.
class SynthesisFocusRequestNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String clusterId) => state = clusterId;

  void clear() => state = null;
}

final synthesisFocusRequestProvider =
    NotifierProvider<SynthesisFocusRequestNotifier, String?>(SynthesisFocusRequestNotifier.new);

/// A request to bring one thought into view on the Capture screen, by note id: set when the user
/// taps a raw thought inside a Synthesis note or a thought in the search results, consumed (and
/// cleared) by the Capture screen. The shell switches to the Capture tab while a request is pending.
class CaptureFocusRequestNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int noteId) => state = noteId;

  void clear() => state = null;
}

final captureFocusRequestProvider =
    NotifierProvider<CaptureFocusRequestNotifier, int?>(CaptureFocusRequestNotifier.new);
