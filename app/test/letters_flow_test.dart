import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/post.dart';
import 'package:incomodo/models/stamp_design.dart';
import 'package:incomodo/models/stamp_wallet.dart';
import 'package:incomodo/models/stationery.dart';
import 'package:incomodo/models/user_profile.dart';
import 'package:incomodo/providers/auth_provider.dart';
import 'package:incomodo/providers/letter_provider.dart';
import 'package:incomodo/providers/post_provider.dart';
import 'package:incomodo/providers/stamp_provider.dart';
import 'package:incomodo/providers/user_provider.dart';
import 'package:incomodo/screens/album_screen.dart';
import 'package:incomodo/screens/letter_screen.dart';
import 'package:incomodo/screens/letters_screen.dart';
import 'package:incomodo/screens/write_letter_screen.dart';
import 'package:incomodo/services/letter_service.dart';
import 'package:incomodo/widgets/envelope_view.dart';
import 'package:incomodo/widgets/postmark.dart';
import 'package:incomodo/widgets/stamp_view.dart';

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
    List<UserProfile> requests = const [],
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
          friendRequestsProvider.overrideWith((ref) => Stream.value(requests)),
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
    testWidgets('a sealed letter shows only who sent it and their stamp',
        (tester) async {
      await tester.pumpWidget(app(LetterScreen(
        letter: Letter(
          id: 'l1',
          direction: LetterDirection.received,
          counterpartUid: friend.uid,
          counterpartDisplayName: friend.displayName,
          counterpartHandle: friend.handle,
          sentAt: now,
          stampId: 'yoru',
        ),
      )));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is StampView && w.design == StampDesign.yoru),
        findsOneWidget,
      );
      expect(find.byType(EnvelopeView), findsOneWidget);
      expect(find.text('差出人'), findsOneWidget);
    });

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

      expect(service.opened, [('l1', '自宅')]);
      expect(find.text('また歩いて会いに行くよ'), findsOneWidget);
      // The postmark says where, on the paper and above it.
      expect(find.textContaining('消印'), findsOneWidget);
      expect(find.textContaining('・自宅'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Postmark && w.place == '自宅'),
        findsOneWidget,
      );
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

  group('手紙を捨てる（B25）', () {
    /// Pushed on top of something, so being popped off can be seen.
    Widget opener(Letter l) => Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LetterScreen(letter: l))),
            child: const Text('ひらく'),
          ),
        );

    Future<void> throwAway(WidgetTester tester, {required bool confirm}) async {
      await tester.tap(find.byTooltip('手紙を捨てる'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(confirm ? '捨てる' : 'やめる'));
      await tester.pumpAndSettle();
    }

    testWidgets('a sealed letter warns it will never be read', (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(opener(letter()), letters: service));
      await tester.tap(find.text('ひらく'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('手紙を捨てる'));
      await tester.pumpAndSettle();
      expect(find.textContaining('もう読むことはできません'), findsOneWidget);

      await tester.tap(find.text('捨てる'));
      await tester.pumpAndSettle();
      expect(service.deleted, [('l1', LetterDirection.received)]);
      // Back where we came from.
      expect(find.byType(LetterScreen), findsNothing);
    });

    testWidgets('changing your mind keeps it', (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(opener(letter()), letters: service));
      await tester.tap(find.text('ひらく'));
      await tester.pumpAndSettle();

      await throwAway(tester, confirm: false);
      expect(service.deleted, isEmpty);
      expect(find.byType(LetterScreen), findsOneWidget);
    });

    testWidgets('a sent letter only loses your copy', (tester) async {
      final service = _FakeLetterService();
      final sent =
          letter(direction: LetterDirection.sent).withBody('元気にしてる？');
      await tester.pumpWidget(app(opener(sent), letters: service));
      await tester.tap(find.text('ひらく'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('手紙を捨てる'));
      await tester.pumpAndSettle();
      expect(find.textContaining('相手に届いた手紙はそのまま残ります'), findsOneWidget);
      await tester.tap(find.text('捨てる'));
      await tester.pumpAndSettle();

      expect(service.deleted, [('l1', LetterDirection.sent)]);
    });
  });

  group('アルバム（B28）', () {
    testWidgets('before any letter is opened, it says what will go there',
        (tester) async {
      await tester.pumpWidget(app(const AlbumScreen(), received: [letter()]));
      await tester.pumpAndSettle();

      expect(find.textContaining('開けた手紙が、ここに並んでいきます'), findsOneWidget);
    });

    testWidgets('opened letters are there, sealed ones are not',
        (tester) async {
      await tester.pumpWidget(app(
        const AlbumScreen(),
        received: [
          letter(id: 'sealed'),
          Letter(
            id: 'opened',
            direction: LetterDirection.received,
            counterpartUid: friend.uid,
            counterpartDisplayName: friend.displayName,
            counterpartHandle: friend.handle,
            sentAt: now.subtract(const Duration(days: 2)),
            openedAt: now,
            openedPlace: '自宅',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AlbumTile), findsOneWidget);
      expect(find.text('2026.9.16・自宅'), findsOneWidget);
    });

    testWidgets('the letters screen leads there', (tester) async {
      await tester.pumpWidget(app(const LettersScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('手紙のアルバム'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
    });
  });

  group('手紙を書く', () {
    testWidgets('with nobody to write to, it points at the friends screen',
        (tester) async {
      await tester.pumpWidget(app(const WriteLetterScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('まだ手紙を出せる相手がいません'), findsOneWidget);
    });

    testWidgets('an unanswered request is why you cannot write yet',
        (tester) async {
      // Accepting is mutual: the other person accepting you is not enough,
      // and without this the screen just says you have no friends.
      await tester.pumpWidget(app(
        const WriteLetterScreen(),
        requests: [friend],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('届いているリクエストが1件'), findsOneWidget);
    });

    testWidgets('an empty letter is refused', (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
        letters: service,
      ));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('送る'));
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
      await scrollTo(tester, find.text('送る'));
      await tester.tap(find.text('送る'));
      await tester.pumpAndSettle();

      expect(service.sent, [('me', 'u2', '駅前のカフェで待ってる')]);
      // Nothing chosen: the ordinary stamp.
      expect(service.stamps, ['basic']);
      expect(service.stationery, [('plain', 'ruled')]);
    });

    testWidgets('the stamp you pick is the one stuck on the letter',
        (tester) async {
      final service = _FakeLetterService();
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
        letters: service,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('桜'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '春になったね');
      await scrollTo(tester, find.text('送る'));
      await tester.tap(find.text('送る'));
      await tester.pumpAndSettle();

      expect(service.stamps, ['sakura']);
    });

    testWidgets('every free stamp is offered', (tester) async {
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
      ));
      await tester.pumpAndSettle();

      for (final design in StampDesign.free) {
        expect(find.text(design.name), findsOneWidget);
      }
    });

    testWidgets('with one envelope and one paper, there is nothing to pick',
        (tester) async {
      // Only one of each exists for now. The pickers are on the screen
      // already and appear by themselves once a second design is added.
      await tester.pumpWidget(app(
        const WriteLetterScreen(to: friend),
        friends: [friend],
      ));
      await tester.pumpAndSettle();

      expect(EnvelopeDesign.free, hasLength(1));
      expect(PaperDesign.free, hasLength(1));
      expect(find.text('封筒'), findsNothing);
      expect(find.text('便箋'), findsNothing);
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

      await scrollTo(tester, find.text('切手がありません'));
      final button = tester.widget<FilledButton>(find.ancestor(
          of: find.text('切手がありません'), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
      expect(service.sent, isEmpty);
    });
  });
}

/// The write screen is taller than the test surface, and its list only
/// builds what is on screen — so scroll the page (not the stamp row) until
/// [finder] exists.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first,
  );
  await tester.pumpAndSettle();
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
  final stamps = <String>[];
  final stationery = <(String envelope, String paper)>[];
  final opened = <(String id, String place)>[];
  final deleted = <(String id, LetterDirection direction)>[];

  @override
  Future<void> sendLetter({
    required UserProfile from,
    required UserProfile to,
    required String body,
    required StampDesign stamp,
    required EnvelopeDesign envelope,
    required PaperDesign paper,
  }) async {
    final error = Letter.validateBody(body);
    if (error != null) throw ArgumentError(error);
    sent.add((from.uid, to.uid, body.trim()));
    stamps.add(stamp.id);
    stationery.add((envelope.id, paper.id));
  }

  @override
  Future<void> open({
    required String uid,
    required Letter letter,
    required String place,
  }) async =>
      opened.add((letter.id, place));

  @override
  Future<void> delete({required String uid, required Letter letter}) async =>
      deleted.add((letter.id, letter.direction));

  @override
  Future<({String body, String paperId})?> readContents({
    required String uid,
    required String letterId,
  }) async =>
      (body: body, paperId: PaperDesign.defaultId);

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
