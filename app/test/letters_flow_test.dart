import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/post.dart';
import 'package:incomodo/models/stamp_wallet.dart';
import 'package:incomodo/models/user_profile.dart';
import 'package:incomodo/providers/auth_provider.dart';
import 'package:incomodo/providers/letter_provider.dart';
import 'package:incomodo/providers/post_provider.dart';
import 'package:incomodo/providers/stamp_provider.dart';
import 'package:incomodo/providers/user_provider.dart';
import 'package:incomodo/screens/letter_screen.dart';
import 'package:incomodo/screens/letters_screen.dart';
import 'package:incomodo/screens/write_letter_screen.dart';
import 'package:incomodo/services/letter_service.dart';

/// The letter screens wired to fakes, so the whole path — list, open,
/// write — is exercised without a device or Firebase.
void main() {
  const me = UserProfile(uid: 'me', displayName: 'わたし', handle: 'me');
  const friend = UserProfile(uid: 'u2', displayName: '後藤', handle: 'goto');
  final now = DateTime(2026, 9, 16, 12, 0);
  final finished = now.subtract(const Duration(hours: 49));

  final home = Post(
    slot: PostSlot.home,
    name: '自宅',
    latitude: 35.0,
    longitude: 139.0,
    constructionStartedAt: finished,
  );

  Letter letter({
    String id = 'l1',
    LetterDirection direction = LetterDirection.received,
    DateTime? openedAt,
  }) =>
      Letter(
        id: id,
        direction: direction,
        counterpartUid: friend.uid,
        counterpartDisplayName: friend.displayName,
        counterpartHandle: friend.handle,
        sentAt: now.subtract(const Duration(hours: 2)),
        openedAt: openedAt,
      );

  Widget app(
    Widget home, {
    List<Letter> received = const [],
    List<Letter> sent = const [],
    List<UserProfile> friends = const [],
    Map<PostSlot, Post> posts = const {},
    ({double latitude, double longitude})? here,
    LetterService? letters,
    int stamps = 3,
  }) =>
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
          myProfileProvider.overrideWith((ref) => Stream.value(me)),
          friendsProvider.overrideWith((ref) => Stream.value(friends)),
          receivedLettersProvider.overrideWith((ref) => Stream.value(received)),
          sentLettersProvider.overrideWith((ref) => Stream.value(sent)),
          postsProvider.overrideWith((ref) => Stream.value(posts)),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          hereProvider.overrideWith(() => _FixedHere(here)),
          stampWalletProvider.overrideWith((ref) => Stream.value(
              StampWallet(count: stamps, refilledOn: jstDate(now)))),
          if (letters != null) letterServiceProvider.overrideWithValue(letters),
        ],
        // AuthGate keeps these two alive for the whole app; screens read
        // them without watching, so the test has to do the same.
        child: MaterialApp(home: _SignedIn(child: home)),
      );

  group('手紙の一覧', () {
    testWidgets('with nothing delivered, it says so', (tester) async {
      await tester.pumpWidget(app(const LettersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('まだ手紙は届いていません。'), findsOneWidget);
    });

    testWidgets('standing at a post, a delivered letter offers to open',
        (tester) async {
      await tester.pumpWidget(app(
        const LettersScreen(),
        received: [letter()],
        posts: {PostSlot.home: home},
        here: (latitude: 35.0, longitude: 139.0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('後藤さんから'), findsOneWidget);
      expect(find.textContaining('「自宅」に着いています'), findsOneWidget);
    });

    testWidgets('away from every post, the same letter stays shut',
        (tester) async {
      await tester.pumpWidget(app(
        const LettersScreen(),
        received: [letter()],
        posts: {PostSlot.home: home},
        here: (latitude: 35.5, longitude: 139.0), // tens of km away
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ポストの近くではありません'), findsOneWidget);
    });

    testWidgets('the other tab holds what you have sent', (tester) async {
      await tester.pumpWidget(app(
        const LettersScreen(),
        sent: [letter(direction: LetterDirection.sent)],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('送った手紙'));
      await tester.pumpAndSettle();

      expect(find.text('後藤さんへ'), findsOneWidget);
      expect(find.textContaining('配送完了'), findsOneWidget);
    });
  });

  group('1通を開ける', () {
    testWidgets('before checking your location, it offers to check',
        (tester) async {
      await tester.pumpWidget(app(LetterScreen(letter: letter())));
      await tester.pumpAndSettle();

      expect(find.textContaining('ポストの前でしか開けません'), findsOneWidget);
      expect(find.text('現在地を確認する'), findsOneWidget);
      expect(find.text('ここで開ける'), findsNothing);
    });

    testWidgets('at a finished post, opening it fetches the text',
        (tester) async {
      final service = _FakeLetterService(body: 'また歩いて会いに行くよ');
      await tester.pumpWidget(app(
        LetterScreen(letter: letter()),
        posts: {PostSlot.home: home},
        here: (latitude: 35.0, longitude: 139.0),
        letters: service,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('「自宅」に着いています'), findsOneWidget);
      await tester.tap(find.text('ここで開ける'));
      await tester.pumpAndSettle();

      expect(service.opened, ['l1']);
      expect(find.text('また歩いて会いに行くよ'), findsOneWidget);
      expect(find.textContaining('消印'), findsOneWidget);
    });

    testWidgets('a letter you sent shows its text without any of that',
        (tester) async {
      await tester.pumpWidget(app(
        LetterScreen(
            letter: letter(direction: LetterDirection.sent)
                .withBody('元気にしてる？')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('元気にしてる？'), findsOneWidget);
      expect(find.text('ここで開ける'), findsNothing);
    });
  });

  group('手紙を書く', () {
    testWidgets('with nobody to write to, it points at the friends screen',
        (tester) async {
      await tester.pumpWidget(app(const WriteLetterScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('まだ友だちがいません'), findsOneWidget);
    });

    testWidgets('an empty letter is refused', (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
        letters: service,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('送る'));
      await tester.pumpAndSettle();

      expect(find.text('手紙の本文を入力してください'), findsOneWidget);
      expect(service.sent, isEmpty);
    });

    testWidgets('writing to a friend sends it to them', (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
        letters: service,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '駅前のカフェで待ってる');
      await tester.tap(find.text('送る'));
      await tester.pumpAndSettle();

      expect(service.sent, [('me', 'u2', '駅前のカフェで待ってる')]);
    });

    testWidgets('how many stamps are left is on the page', (tester) async {
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
        stamps: 3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('切手 3枚'), findsOneWidget);
    });

    testWidgets('out of stamps, there is no sending until tomorrow',
        (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
        letters: service,
        stamps: 0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('切手 0枚'), findsOneWidget);
      expect(find.textContaining('明日また'), findsOneWidget);

      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull);
      expect(service.sent, isEmpty);
    });
  });
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

class _FixedHere extends HereNotifier {
  _FixedHere(this.value);

  final ({double latitude, double longitude})? value;

  @override
  ({double latitude, double longitude})? build() => value;

  @override
  Future<void> check() async => state = value;
}

class _FakeLetterService implements LetterService {
  _FakeLetterService({this.body = ''});

  final String body;
  final sent = <(String, String, String)>[];
  final opened = <String>[];

  @override
  Future<void> sendLetter({
    required UserProfile from,
    required UserProfile to,
    required String body,
  }) async {
    final error = Letter.validateBody(body);
    if (error != null) throw ArgumentError(error);
    sent.add((from.uid, to.uid, body.trim()));
  }

  @override
  Future<void> open({required String uid, required Letter letter}) async =>
      opened.add(letter.id);

  @override
  Future<String?> readBody({required String uid, required String letterId}) async =>
      body;

  @override
  Stream<List<Letter>> watchReceived(String uid) => const Stream.empty();

  @override
  Stream<List<Letter>> watchSent(String uid) => const Stream.empty();
}

class _FakeUser implements User {
  @override
  String get uid => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
