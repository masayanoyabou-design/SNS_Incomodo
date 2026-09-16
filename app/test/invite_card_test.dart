import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/user_profile.dart';
import 'package:incomodo/widgets/invite_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const profile = UserProfile(uid: 'u1', displayName: '後藤', handle: 'goto');

  Future<void> pump(WidgetTester tester, {VoidCallback? onCopyLink}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InviteCard(profile: profile, onCopyLink: onCopyLink),
        ),
      ));

  testWidgets('shows a QR code alongside the name and id', (tester) async {
    await pump(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('後藤'), findsOneWidget);
    expect(find.text('@goto'), findsOneWidget);
  });

  testWidgets('the QR encodes this person\'s invite link', (tester) async {
    await pump(tester);

    final card = tester.widget<InviteCard>(find.byType(InviteCard));
    expect(card.link, contains('id=goto'));
    // A screen reader should say whose code this is, not just "qr code".
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, contains('@goto'));
  });

  testWidgets('copying the link is one tap', (tester) async {
    var copied = 0;
    await pump(tester, onCopyLink: () => copied++);

    await tester.tap(find.text('招待リンクをコピー'));
    await tester.pump();

    expect(copied, 1);
  });
}
