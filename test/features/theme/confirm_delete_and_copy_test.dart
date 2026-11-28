import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/theme/widgets/clipboard_copy.dart';
import 'package:eudemonia/features/theme/widgets/confirm_delete_dialog.dart';

void main() {
  Future<bool?> openDialog(WidgetTester tester, {String? consequence}) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open'),
            onPressed: () async => result = await confirmDelete(context, question: 'Delete thought #03?', consequence: consequence),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return result;
  }

  group('confirmDelete', () {
    testWidgets('shows the question and, when given, the consequence', (tester) async {
      await openDialog(tester, consequence: 'Note #S-01 "T" will be deleted too.');
      expect(find.text('Delete thought #03?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_consequence')), findsOneWidget);
      expect(find.text('Note #S-01 "T" will be deleted too.'), findsOneWidget);
    });

    testWidgets('shows no consequence line when there is none', (tester) async {
      await openDialog(tester);
      expect(find.byKey(const Key('confirm_delete_consequence')), findsNothing);
    });

    testWidgets('Delete resolves true, Cancel and a tap outside resolve false', (tester) async {
      bool? result;
      Future<void> run(Future<void> Function() answer) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () async => result = await confirmDelete(context, question: 'q'),
              child: const Text('open'),
            ),
          ),
        ));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        await answer();
        await tester.pumpAndSettle();
      }

      await run(() => tester.tap(find.byKey(const Key('confirm_delete_button'))));
      expect(result, isTrue);
      await run(() => tester.tap(find.byKey(const Key('confirm_delete_cancel'))));
      expect(result, isFalse);
      await run(() => tester.tapAt(const Offset(2, 2)));
      expect(result, isFalse);
    });
  });

  group('copyToClipboard', () {
    testWidgets('puts the text on the clipboard and says Copied', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('copy'),
              onPressed: () => copyToClipboard(context, 'hello there'),
              child: const Text('copy'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('copy')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(copied, 'hello there');
      expect(find.byKey(const Key('copied_snackbar')), findsOneWidget);
      expect(find.text('Copied'), findsOneWidget);
    });
  });
}
