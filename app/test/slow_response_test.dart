import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/services/slow_response.dart';

void main() {
  test('an answer in time comes straight through', () async {
    final answer = await answerWithin(
      Future.value(42),
      limit: const Duration(seconds: 1),
      message: '遅い',
    );
    expect(answer, 42);
  });

  test('no answer ends the wait with the message, not a spinner', () async {
    // A Completer that is never completed: what a Firestore write looks
    // like when the server never acknowledges it.
    final never = Completer<void>().future;

    await expectLater(
      answerWithin(never,
          limit: const Duration(milliseconds: 10), message: '通信に時間がかかっています'),
      throwsA(isA<SlowResponseException>()
          .having((e) => e.toString(), 'message', '通信に時間がかかっています')),
    );
  });

  test('a real failure is passed on as it is', () async {
    await expectLater(
      answerWithin(Future<void>.error(StateError('denied')),
          limit: const Duration(seconds: 1), message: '遅い'),
      throwsA(isA<StateError>()),
    );
  });

  test('a write not confirmed in time is still on its way', () async {
    await expectLater(
      handOver(Completer<void>().future,
          limit: const Duration(milliseconds: 10), message: '送信待ち'),
      throwsA(isA<StillSendingException>()),
    );
  });
}
