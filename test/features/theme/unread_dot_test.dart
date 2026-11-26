import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/theme/widgets/unread_dot.dart';

class _Host extends StatefulWidget {
  final bool initiallyUnread;
  final bool disableAnimations;

  const _Host({super.key, required this.initiallyUnread, this.disableAnimations = false});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool unread = widget.initiallyUnread;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 800), disableAnimations: widget.disableAnimations),
        child: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(key: Key('before'), width: 20, height: 10),
                UnreadDot(unread: unread, dotKey: const Key('dot'), margin: const EdgeInsets.only(left: 8)),
                const SizedBox(key: Key('after'), width: 20, height: 10),
                GestureDetector(key: const Key('flip'), onTap: () => setState(() => unread = !unread), child: const Text('flip')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('an unread dot is solid and a read one takes no space', (tester) async {
    await tester.pumpWidget(const _Host(initiallyUnread: true));
    expect(find.byKey(const Key('dot')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('dot'))), const Size(8, 8));

    await tester.pumpWidget(const _Host(key: Key('read'), initiallyUnread: false));
    expect(find.byKey(const Key('dot')), findsNothing);
    final gap = tester.getTopLeft(find.byKey(const Key('after'))).dx - tester.getTopRight(find.byKey(const Key('before'))).dx;
    expect(gap, 0, reason: 'a card that was read from the start reserves nothing');
  });

  testWidgets('turning read dissolves the dot over about 700 ms and leaves its slot reserved', (tester) async {
    await tester.pumpWidget(const _Host(initiallyUnread: true));
    double gap() => tester.getTopLeft(find.byKey(const Key('after'))).dx - tester.getTopRight(find.byKey(const Key('before'))).dx;
    final reserved = gap();
    expect(reserved, 16, reason: '8 margin + 8 dot');

    await tester.tap(find.byKey(const Key('flip')));
    await tester.pump();
    expect(find.byKey(const Key('dot')), findsOneWidget, reason: 'still dissolving');
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('dot')), findsOneWidget);
    expect(tester.widget<CustomPaint>(find.byKey(const Key('dot'))).painter, isNotNull);
    expect(gap(), reserved, reason: 'the header row does not shift while it dissolves');

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('dot')), findsNothing);
    expect(gap(), reserved, reason: 'nor after');
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the dissolve really changes between frames', (tester) async {
    await tester.pumpWidget(const _Host(initiallyUnread: true));
    await tester.tap(find.byKey(const Key('flip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final early = tester.widget<CustomPaint>(find.byKey(const Key('dot'))).painter!;
    await tester.pump(const Duration(milliseconds: 300));
    final later = tester.widget<CustomPaint>(find.byKey(const Key('dot'))).painter!;
    expect(later.shouldRepaint(early), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('without animations the dot is removed at once', (tester) async {
    await tester.pumpWidget(const _Host(initiallyUnread: true, disableAnimations: true));
    expect(find.byKey(const Key('dot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('flip')));
    await tester.pump();
    expect(find.byKey(const Key('dot')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a dot that turns unread again is solid again', (tester) async {
    await tester.pumpWidget(const _Host(initiallyUnread: true));
    await tester.tap(find.byKey(const Key('flip')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('flip')));
    await tester.pump();
    expect(find.byKey(const Key('dot')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dot')), matching: find.byType(CustomPaint)), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
