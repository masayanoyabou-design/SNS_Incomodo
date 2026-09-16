import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/user_profile.dart';

void main() {
  group('normalizeHandle', () {
    test('strips a leading @, trims, and lowercases', () {
      expect(UserProfile.normalizeHandle(' @Goto_01 '), 'goto_01');
    });

    test('leaves an already-normal handle alone', () {
      expect(UserProfile.normalizeHandle('goto_01'), 'goto_01');
    });

    test('only strips the first @', () {
      expect(UserProfile.normalizeHandle('@@goto'), '@goto');
    });
  });

  group('validateHandle', () {
    test('accepts letters, digits and underscores', () {
      expect(UserProfile.validateHandle('goto_01'), isNull);
      expect(UserProfile.validateHandle('@goto_01'), isNull);
    });

    test('rejects handles that are too short or too long', () {
      expect(UserProfile.validateHandle('ab'), isNotNull);
      expect(UserProfile.validateHandle('a' * 15), isNull);
      expect(UserProfile.validateHandle('a' * 16), isNotNull);
    });

    test('rejects empty input', () {
      expect(UserProfile.validateHandle(''), isNotNull);
      expect(UserProfile.validateHandle('@'), isNotNull);
    });

    test('rejects characters that would break lookups', () {
      expect(UserProfile.validateHandle('goto san'), isNotNull);
      expect(UserProfile.validateHandle('ごとう'), isNotNull);
      expect(UserProfile.validateHandle('goto-san'), isNotNull);
      expect(UserProfile.validateHandle('goto.san'), isNotNull);
    });

    test('uppercase input is accepted and normalized, not rejected', () {
      expect(UserProfile.validateHandle('GOTO'), isNull);
      expect(UserProfile.normalizeHandle('GOTO'), 'goto');
    });
  });

  group('validateDisplayName', () {
    test('accepts a normal name', () {
      expect(UserProfile.validateDisplayName('後藤'), isNull);
    });

    test('rejects empty or whitespace-only names', () {
      expect(UserProfile.validateDisplayName(''), isNotNull);
      expect(UserProfile.validateDisplayName('   '), isNotNull);
    });

    test('rejects names longer than 20 characters', () {
      expect(UserProfile.validateDisplayName('あ' * 20), isNull);
      expect(UserProfile.validateDisplayName('あ' * 21), isNotNull);
    });
  });

  test('handleWithAt shows the handle the way users type it', () {
    const profile =
        UserProfile(uid: 'u1', displayName: '後藤', handle: 'goto_01');
    expect(profile.handleWithAt, '@goto_01');
  });
}
