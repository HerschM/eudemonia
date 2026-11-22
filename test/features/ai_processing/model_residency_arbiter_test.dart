import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/model_residency_arbiter.dart';

void main() {
  late ModelResidencyArbiter arbiter;
  setUp(() => arbiter = ModelResidencyArbiter());

  test('speech is acquired immediately when free and acquiring again is idempotent', () async {
    await arbiter.acquireSpeech();
    await arbiter.acquireSpeech();
    expect(arbiter.holder, HeavyModel.speech);
    arbiter.releaseSpeech();
    expect(arbiter.holder, isNull);
  });

  test('language is refused while speech holds, and when language already holds', () async {
    await arbiter.acquireSpeech();
    expect(arbiter.tryAcquireLanguage(onPreempt: () async {}), isFalse);
    arbiter.releaseSpeech();
    expect(arbiter.tryAcquireLanguage(onPreempt: () async {}), isTrue);
    expect(arbiter.tryAcquireLanguage(onPreempt: () async {}), isFalse);
    expect(arbiter.holder, HeavyModel.language);
  });

  test('release calls are no-ops for the wrong holder', () async {
    arbiter.tryAcquireLanguage(onPreempt: () async {});
    arbiter.releaseSpeech();
    expect(arbiter.holder, HeavyModel.language);
    arbiter.releaseLanguage();
    arbiter.releaseLanguage();
    expect(arbiter.holder, isNull);
  });

  test('speech preempts language and waits for releaseLanguage', () async {
    final gate = Completer<void>();
    var preempted = 0;
    arbiter.tryAcquireLanguage(onPreempt: () async {
      preempted++;
      await gate.future;
      arbiter.releaseLanguage();
    });

    var acquired = false;
    final f = arbiter.acquireSpeech().then((_) => acquired = true);
    await Future<void>.delayed(Duration.zero);
    expect(preempted, 1);
    expect(acquired, isFalse);
    expect(arbiter.holder, HeavyModel.language);

    gate.complete();
    await f;
    expect(arbiter.holder, HeavyModel.speech);
    expect(arbiter.tryAcquireLanguage(onPreempt: () async {}), isFalse);
  });

  test('a throwing onPreempt does not block speech', () async {
    arbiter.tryAcquireLanguage(onPreempt: () async => throw Exception('boom'));
    await arbiter.acquireSpeech().timeout(const Duration(seconds: 1));
    expect(arbiter.holder, HeavyModel.speech);
  });

  test('concurrent acquireSpeech calls share one preemption', () async {
    var preempted = 0;
    arbiter.tryAcquireLanguage(onPreempt: () async {
      preempted++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      arbiter.releaseLanguage();
    });
    await Future.wait([arbiter.acquireSpeech(), arbiter.acquireSpeech(), arbiter.acquireSpeech()]);
    expect(preempted, 1);
    expect(arbiter.holder, HeavyModel.speech);
  });

  test('a callback that releases synchronously still hands the hold to speech', () async {
    final arbiter = ModelResidencyArbiter();
    expect(
      arbiter.tryAcquireLanguage(onPreempt: () {
        arbiter.releaseLanguage();
        return Future.value();
      }),
      isTrue,
    );
    await arbiter.acquireSpeech();
    expect(arbiter.holder, HeavyModel.speech);
    expect(arbiter.tryAcquireLanguage(onPreempt: () async {}), isFalse);
  });
}
