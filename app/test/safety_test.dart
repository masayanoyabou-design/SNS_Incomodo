import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/report.dart';
import 'package:incomodo/models/user_profile.dart';
import 'package:incomodo/providers/auth_provider.dart';
import 'package:incomodo/providers/post_provider.dart';
import 'package:incomodo/providers/safety_provider.dart';
import 'package:incomodo/providers/user_provider.dart';
import 'package:incomodo/screens/friends_screen.dart';
import 'package:incomodo/screens/letter_screen.dart';
import 'package:incomodo/services/safety_service.dart';

/// Reporting and blocking (B33), wired to a fake service.
void main() {
  const me = UserProfile(uid: 'me', displayName: 'わたし', handle: 'me');
  const sender = UserProfile(uid: 'u2', displayName: '後藤', handle: 'goto');

  final letter = Letter(
    id: 'l1',
    direction: LetterDirection.received,
    counterpartUid: sender.uid,
    counterpartDisplayName: sender.displayName,
    counterpartHandle: sender.handle,
    sentAt: DateTime(2026, 9, 17),
  );

  Widget app(
    Widget home,
    _FakeSafetyService safety, {
    List<UserProfile> friends = const [],
    List<UserProfile> blocked = const [],
  }) =>
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
          myProfileProvider.overrideWith((ref) => Stream.value(me)),
          friendsProvider.overrideWith((ref) => Stream.value(friends)),
          friendRequestsProvider.overrideWith((ref) => Stream.value(const [])),
          blockedProvider.overrideWith((ref) => Stream.value(blocked)),
          postsProvider.overrideWith((ref) => Stream.value(const {})),
          safetyServiceProvider.overrideWithValue(safety),
        ],
        child: MaterialApp(home: _SignedIn(child: home)),
      );

  test('the report reasons are exactly the ones the rules accept', () {
    final rules = File('firestore.rules').readAsStringSync();
    final match =
        RegExp(r"data\.reason in\s*\[([^\]]*)\]").firstMatch(rules);
    expect(match, isNotNull, reason: 'reason list not found in the rules');
    final inRules = RegExp("'([^']+)'")
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1))
        .toSet();
    expect(inRules, ReportReason.values.map((r) => r.id).toSet());
  });

  group('届いた手紙から', () {
    testWidgets('a sender can be reported, with a reason', (tester) async {
      final safety = _FakeSafetyService();
      await tester.pumpWidget(app(LetterScreen(letter: letter), safety));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('通報・ブロック'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('通報する'));
      await tester.pumpAndSettle();

      // No reason, no report.
      final send = find.widgetWithText(TextButton, '通報する');
      expect(tester.widget<TextButton>(send).onPressed, isNull);

      await tester.tap(find.text(ReportReason.locating.label));
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(safety.reports, [('me', 'u2', ReportReason.locating, 'l1')]);
      expect(find.textContaining('通報を受け付けました'), findsOneWidget);
    });

    testWidgets('a sender can be blocked, after saying what that does',
        (tester) async {
      final safety = _FakeSafetyService();
      await tester.pumpWidget(app(LetterScreen(letter: letter), safety));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('通報・ブロック'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ブロックする'));
      await tester.pumpAndSettle();

      expect(find.textContaining('手紙と友だちリクエストは届かなくなります'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'ブロックする'));
      await tester.pumpAndSettle();

      expect(safety.blocked, ['u2']);
    });

    testWidgets('a letter you sent offers neither', (tester) async {
      final sent = Letter(
        id: 'l2',
        direction: LetterDirection.sent,
        counterpartUid: sender.uid,
        counterpartDisplayName: sender.displayName,
        counterpartHandle: sender.handle,
        sentAt: DateTime(2026, 9, 17),
        body: 'やあ',
      );
      await tester
          .pumpWidget(app(LetterScreen(letter: sent), _FakeSafetyService()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('通報・ブロック'), findsNothing);
    });
  });

  group('友だち画面', () {
    final page = find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first;

    testWidgets('a friend can be blocked from the list', (tester) async {
      final safety = _FakeSafetyService();
      await tester.pumpWidget(
          app(const FriendsScreen(), safety, friends: [sender]));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byTooltip('通報・ブロック'), 200, scrollable: page);
      await tester.ensureVisible(find.byTooltip('通報・ブロック'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('通報・ブロック'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ブロックする'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'ブロックする'));
      await tester.pumpAndSettle();

      expect(safety.blocked, ['u2']);
    });

    testWidgets('blocked people are listed and can be unblocked',
        (tester) async {
      final safety = _FakeSafetyService();
      await tester.pumpWidget(
          app(const FriendsScreen(), safety, blocked: [sender]));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('解除'), 200, scrollable: page);
      expect(find.text('ブロック中（1）'), findsOneWidget);
      await tester.tap(find.text('解除'));
      await tester.pumpAndSettle();

      expect(safety.unblocked, ['u2']);
    });
  });
}

class _FakeSafetyService implements SafetyService {
  final reports = <(String, String, ReportReason, String?)>[];
  final blocked = <String>[];
  final unblocked = <String>[];

  @override
  Future<void> report({
    required String reporterUid,
    required String targetUid,
    required ReportReason reason,
    String detail = '',
    String? letterId,
  }) async =>
      reports.add((reporterUid, targetUid, reason, letterId));

  @override
  Future<void> block({required String uid, required UserProfile target}) async =>
      blocked.add(target.uid);

  @override
  Future<void> unblock({required String uid, required String targetUid}) async =>
      unblocked.add(targetUid);

  @override
  Stream<List<UserProfile>> watchBlocked(String uid) => const Stream.empty();
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    ref.watch(myProfileProvider);
    return child;
  }
}

class _FakeUser implements User {
  @override
  String get uid => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
