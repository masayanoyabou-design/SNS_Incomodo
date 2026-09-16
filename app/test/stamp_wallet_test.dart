import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/stamp_wallet.dart';

void main() {
  StampWallet wallet(int count, DateTime refilledOn) =>
      StampWallet(count: count, refilledOn: refilledOn);

  group('jstDate', () {
    test('is the day in Japan, not in UTC', () {
      // 09:00 UTC on the 16th is already the 17th in Tokyo.
      expect(jstDate(DateTime.utc(2026, 9, 16, 15, 30)),
          DateTime.utc(2026, 9, 17));
      expect(jstDate(DateTime.utc(2026, 9, 16, 14, 59)),
          DateTime.utc(2026, 9, 16));
    });
  });

  group('refills', () {
    test('a day\'s worth is added', () {
      expect(StampWallet.afterRefill(0), StampWallet.dailyRefill);
      expect(StampWallet.afterRefill(3), 3 + StampWallet.dailyRefill);
    });

    test('they stop piling up at the ceiling', () {
      expect(StampWallet.afterRefill(StampWallet.maxHeld - 1),
          StampWallet.maxHeld);
      expect(StampWallet.afterRefill(StampWallet.maxHeld),
          StampWallet.maxHeld);
    });

    test('a wallet refilled today is not stale', () {
      final now = DateTime.utc(2026, 9, 16, 5, 0); // 14:00 JST
      expect(wallet(2, jstDate(now)).isStale(now), isFalse);
    });

    test('a wallet refilled yesterday is', () {
      final now = DateTime.utc(2026, 9, 16, 5, 0);
      expect(wallet(2, DateTime.utc(2026, 9, 15)).isStale(now), isTrue);
    });

    test('being away for a week still only earns one day\'s worth', () {
      // Deliberate: stamps mark the rhythm of opening the app, they are
      // not a balance that accrues while you are gone.
      expect(wallet(0, DateTime.utc(2026, 9, 9)).refill().count,
          StampWallet.dailyRefill);
    });
  });

  group('sending', () {
    test('needs at least one stamp', () {
      expect(wallet(1, DateTime.utc(2026, 9, 16)).canSend, isTrue);
      expect(wallet(0, DateTime.utc(2026, 9, 16)).canSend, isFalse);
    });
  });
}
