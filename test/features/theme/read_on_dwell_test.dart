import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/theme/widgets/read_on_dwell.dart';

/// A 360x800 viewport with a 200 dp card at [cardTop] in a long list.
class _Host extends StatefulWidget {
  final ScrollController controller;
  final double cardTop;
  final VoidCallback onRead;
  final bool enabled;
  final bool active;
  final double cardHeight;

  const _Host({
    required this.controller,
    required this.onRead,
    this.cardTop = 100,
    this.enabled = true,
    this.active = true,
    this.cardHeight = 200,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: widget.controller,
          children: [
            SizedBox(height: widget.cardTop),
            ReadOnDwell(
              enabled: widget.enabled,
              active: widget.active,
              onRead: widget.onRead,
              child: SizedBox(key: const Key('card'), height: widget.cardHeight, child: const Text('card')),
            ),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    );
  }
}

void main() {
  late ScrollController controller;
  late int reads;

  setUp(() {
    controller = ScrollController();
    reads = 0;
  });

  tearDown(() => controller.dispose());

  Future<void> pumpHost(
    WidgetTester tester, {
    double cardTop = 100,
    bool enabled = true,
    bool active = true,
    double cardHeight = 200,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_Host(
      controller: controller,
      cardTop: cardTop,
      enabled: enabled,
      active: active,
      cardHeight: cardHeight,
      onRead: () => reads++,
    ));
    await tester.pump();
  }

  testWidgets('a card in view is read after 3 seconds, not before, and only once', (tester) async {
    await pumpHost(tester);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(reads, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 1);
  });

  testWidgets('a card 65 % in view counts as seen', (tester) async {
    // The card (200 dp) starts at 1000; the viewport is 800 tall.
    await pumpHost(tester, cardTop: 1000);
    controller.jumpTo(330); // card top at 670: 130 dp = 65 % visible
    await tester.pump();
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    expect(reads, 1);
  });

  testWidgets('a card only 50 % in view is never read', (tester) async {
    await pumpHost(tester, cardTop: 1000);
    controller.jumpTo(300); // card top at 700: 100 dp = 50 % visible
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);
  });

  testWidgets('a card scrolled away before 3 seconds is not read; coming back starts the count again',
      (tester) async {
    await pumpHost(tester, cardTop: 100);
    await tester.pump(const Duration(seconds: 2));
    controller.jumpTo(1500); // far away
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 0);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(reads, 0, reason: 'the 2 s spent before do not count');
    await tester.pump(const Duration(milliseconds: 700));
    expect(reads, 1);
  });

  testWidgets('scrolling is a break: a drag restarts the count', (tester) async {
    await pumpHost(tester, cardTop: 100);
    await tester.pump(const Duration(seconds: 2));
    final gesture = await tester.startGesture(const Offset(180, 600));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 0, reason: 'no reading while the finger is scrolling');
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 2900));
    expect(reads, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(reads, 1);
  });

  testWidgets('nothing happens on an inactive tab; the count starts once it becomes active', (tester) async {
    await pumpHost(tester, active: false);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);

    await pumpHost(tester, active: true);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(reads, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(reads, 1);
  });

  testWidgets('leaving the tab before 3 seconds cancels the count', (tester) async {
    await pumpHost(tester);
    await tester.pump(const Duration(seconds: 2));
    await pumpHost(tester, active: false);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 0);
  });

  testWidgets('a paused app does not read; resuming starts the count', (tester) async {
    await pumpHost(tester);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2900));
    expect(reads, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(reads, 1);
  });

  testWidgets('a card that is already read holds no timer and never reports', (tester) async {
    await pumpHost(tester, enabled: false);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a card taller than the viewport is read once it fills most of the screen', (tester) async {
    await pumpHost(tester, cardTop: 0, cardHeight: 2000);
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    expect(reads, 1);
  });

  testWidgets('removing the card cancels its timer', (tester) async {
    await pumpHost(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);
  });
}
