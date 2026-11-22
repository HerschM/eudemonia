import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llama_isolate_engine.dart';

/// Scripted token source: yields [pieces] as (text, done=false, contextLimit=false), then
/// [end] forever. Counts calls so tests can prove how many tokens were generated.
class ScriptedTokens {
  final List<String> pieces;
  final (String, bool, bool) end;
  int calls = 0;

  ScriptedTokens(this.pieces, {this.end = ('', true, false)});

  (String, bool, bool) next() {
    final i = calls++;
    return i < pieces.length ? (pieces[i], false, false) : end;
  }
}

void main() {
  group('runTokenLoop', () {
    test('stops at the cap with exactly maxOutputTokens tokens and reports hitOutputCap', () async {
      final src = ScriptedTokens(List.filled(10, 'a'));
      final chunks = <String>[];
      final r = await runTokenLoop(next: src.next, maxOutputTokens: 3, onChunk: chunks.add, stopRequested: () => false);
      expect(src.calls, 3);
      expect(chunks, ['a', 'a', 'a']);
      expect(r.hitOutputCap, isTrue);
      expect(r.stopped, isFalse);
      expect(r.error, isNull);
    });

    test('empty pieces count as tokens but are not sent', () async {
      final src = ScriptedTokens(['a', '', 'b', 'c']);
      final chunks = <String>[];
      final r = await runTokenLoop(next: src.next, maxOutputTokens: 3, onChunk: chunks.add, stopRequested: () => false);
      expect(src.calls, 3);
      expect(chunks, ['a', 'b']);
      expect(r.hitOutputCap, isTrue);
    });

    test('done ends the loop without the cap flag', () async {
      final src = ScriptedTokens(['a', 'b']);
      final chunks = <String>[];
      final r = await runTokenLoop(next: src.next, maxOutputTokens: 10, onChunk: chunks.add, stopRequested: () => false);
      expect(src.calls, 3);
      expect(chunks, ['a', 'b']);
      expect(r.hitOutputCap, isFalse);
      expect(r.stopped, isFalse);
      expect(r.error, isNull);
    });

    test('a done token on the cap boundary is reported as done, not capped', () async {
      final src = ScriptedTokens(['a', 'b']);
      final r = await runTokenLoop(next: src.next, maxOutputTokens: 3, onChunk: (_) {}, stopRequested: () => false);
      expect(src.calls, 3);
      expect(r.hitOutputCap, isFalse);
    });

    test('the context limit ends the loop', () async {
      final src = ScriptedTokens(['a'], end: ('', true, true));
      final r = await runTokenLoop(next: src.next, maxOutputTokens: 10, onChunk: (_) {}, stopRequested: () => false);
      expect(src.calls, 2);
      expect(r.hitOutputCap, isFalse);
      expect(r.stopped, isFalse);
      expect(r.error, isNull);
    });

    test('the stop flag ends the loop and reports stopped', () async {
      final src = ScriptedTokens(List.filled(10, 'a'));
      final r = await runTokenLoop(
          next: src.next, maxOutputTokens: 100, onChunk: (_) {}, stopRequested: () => src.calls >= 2);
      expect(src.calls, 2);
      expect(r.stopped, isTrue);
      expect(r.hitOutputCap, isFalse);
    });

    test('an exception from the token source yields an error outcome', () async {
      var calls = 0;
      (String, bool, bool) next() {
        if (++calls == 2) throw StateError('native fault');
        return ('a', false, false);
      }

      final chunks = <String>[];
      final r = await runTokenLoop(next: next, maxOutputTokens: 10, onChunk: chunks.add, stopRequested: () => false);
      expect(chunks, ['a']);
      expect(r.error, contains('native fault'));
      expect(r.hitOutputCap, isFalse);
      expect(r.stopped, isFalse);
    });

    test('yields to the event loop between tokens so a stop sent by a timer is honoured', () async {
      var stop = false;
      final src = ScriptedTokens(List.filled(1000, 'a'));
      // Runs only if the loop returns to the event loop; a synchronous loop would reach the cap.
      Timer.run(() => stop = true);
      final r = await runTokenLoop(next: src.next, maxOutputTokens: 1000, onChunk: (_) {}, stopRequested: () => stop);
      expect(r.stopped, isTrue);
      expect(src.calls, lessThan(1000));
    });
  });
}
