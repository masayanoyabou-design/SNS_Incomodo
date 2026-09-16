import 'dart:async';

/// Thrown when something the app waits on — the server, the phone's
/// location settings — takes too long to answer.
///
/// Without a limit, a spinner can turn forever: a Firestore write's future
/// only completes once the server has acknowledged it, and a busy or
/// offline phone may never get there. The message says what happened
/// instead, so it can be read out as is.
class SlowResponseException implements Exception {
  const SlowResponseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Waits for [future] for at most [limit], then gives up with [message].
///
/// Giving up only stops the waiting. A Firestore write that has been handed
/// over still goes through once the connection recovers, so messages for
/// writes should say to check back rather than to try again.
Future<T> answerWithin<T>(
  Future<T> future, {
  required Duration limit,
  required String message,
}) =>
    future.timeout(limit, onTimeout: () => throw SlowResponseException(message));
