import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/invite.dart';
import 'package:incomodo/screens/scan_invite_screen.dart';

void main() {
  group('handleFromScan', () {
    test('reads the invite a friend shows as a QR code', () {
      expect(handleFromScan(Invite.linkFor('goto')), 'goto');
    });

    test('takes a bare @id', () {
      expect(handleFromScan('@goto'), 'goto');
    });

    test('ignores other sites, whatever their links look like', () {
      // Read as a pasted link, this would find a user called "menu".
      expect(handleFromScan('https://some.shop/menu'), isNull);
      expect(handleFromScan('https://example.com/?id=goto'), isNull);
    });

    test('ignores plain words, which any poster might carry', () {
      expect(handleFromScan('welcome'), isNull);
      expect(handleFromScan(null), isNull);
    });
  });
}
