import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/invite.dart';
import 'package:incomodo/models/user_profile.dart';

void main() {
  group('linkFor', () {
    test('builds a link the landing page can read', () {
      expect(Invite.linkFor('goto'), '${Invite.site}/?id=goto');
    });

    test('normalises the handle it is given', () {
      expect(Invite.linkFor('@Goto '), '${Invite.site}/?id=goto');
    });
  });

  group('handleFrom', () {
    test('reads an invite link', () {
      expect(Invite.handleFrom(Invite.linkFor('goto')), 'goto');
    });

    test('ignores extra query parameters', () {
      expect(
        Invite.handleFrom('${Invite.site}/?id=goto&utm_source=line'),
        'goto',
      );
    });

    test('reads a path-style link, in case the domain changes shape', () {
      expect(Invite.handleFrom('https://incomodo.app/i/goto'), 'goto');
    });

    test('accepts a bare id and an @id', () {
      expect(Invite.handleFrom('goto'), 'goto');
      expect(Invite.handleFrom(' @Goto '), 'goto');
    });

    test('rejects a link with no id on it', () {
      expect(Invite.handleFrom(Invite.site), isNull);
      expect(Invite.handleFrom('${Invite.site}/?id='), isNull);
    });

    test('rejects text that is not a usable handle', () {
      expect(Invite.handleFrom(''), isNull);
      expect(Invite.handleFrom('   '), isNull);
      expect(Invite.handleFrom('ab'), isNull); // too short
      expect(Invite.handleFrom('後藤'), isNull);
    });
  });

  test('messageFor names the sender and carries the link', () {
    const profile =
        UserProfile(uid: 'u1', displayName: '後藤', handle: 'goto');
    final message = Invite.messageFor(profile);

    expect(message, contains('後藤'));
    expect(message, contains('@goto'));
    expect(Invite.handleFrom(message.split('\n').last), 'goto');
  });
}
