import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Note note) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ThoughtCard(note: note, sequenceNumber: 3, onPlayAudio: () {}, onDelete: () {}),
      ),
    ));
  }

  testWidgets('a voice thought whose recording was removed shows a muted marker that is not a button', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, Note(correctedText: 'Call the plumber.', isRead: true));

    expect(find.byKey(const Key('recording_removed_marker')), findsOneWidget);
    expect(find.byKey(const Key('play_audio_button')), findsNothing);
    expect(find.byKey(const Key('written_note_marker')), findsNothing);
    expect(find.byTooltip('Recording no longer kept'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Recording no longer kept')), findsOneWidget);
    // Not tappable: no button anywhere in the header holds it.
    expect(
      find.ancestor(of: find.byKey(const Key('recording_removed_marker')), matching: find.byType(IconButton)),
      findsNothing,
    );
    final icon = tester.widget<Icon>(find.byKey(const Key('recording_removed_marker')));
    expect(icon.color, isNot(Theme.of(tester.element(find.byType(ThoughtCard))).colorScheme.primary));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a thought with a recording keeps its play control and no marker', (tester) async {
    await pumpCard(tester, Note(correctedText: 'Call the plumber.', originalAudioPath: '/rec/a.wav', isRead: true));

    expect(find.byKey(const Key('play_audio_button')), findsOneWidget);
    expect(find.byKey(const Key('recording_removed_marker')), findsNothing);
  });

  testWidgets('a written thought keeps its pen and never shows the removed-recording marker', (tester) async {
    await pumpCard(tester, Note(correctedText: 'Typed.', isWritten: true, isRead: true));

    expect(find.byKey(const Key('written_note_marker')), findsOneWidget);
    expect(find.byKey(const Key('recording_removed_marker')), findsNothing);
    expect(find.byKey(const Key('play_audio_button')), findsNothing);
  });

  testWidgets('a written thought that somehow has a path still shows the pen', (tester) async {
    await pumpCard(tester, Note(correctedText: 'Typed.', isWritten: true, originalAudioPath: '/x.wav', isRead: true));
    expect(find.byKey(const Key('written_note_marker')), findsOneWidget);
    expect(find.byKey(const Key('play_audio_button')), findsNothing);
  });
}
