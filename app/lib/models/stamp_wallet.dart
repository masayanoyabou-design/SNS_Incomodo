/// How many stamps you are holding (PRD F-05).
///
/// Sending a letter costs one. A few arrive each day and they do not pile
/// up past a ceiling, so the limit on how much you write is the day
/// itself rather than your patience — the same idea as the 48-hour
/// construction and the 50 metres.
class StampWallet {
  const StampWallet({required this.count, required this.refilledOn});

  /// Stamps handed out on a day you open the app.
  static const dailyRefill = 2;

  /// The most you can be holding. Stops a month away from turning into a
  /// month's worth of letters in one evening.
  static const maxHeld = 10;

  final int count;

  /// The day the last refill was for, as a JST date at midnight UTC.
  final DateTime refilledOn;

  bool get canSend => count > 0;

  /// What a refill would leave you with — never above [maxHeld], and
  /// never less than you already have.
  static int afterRefill(int count) {
    final topped = count + dailyRefill;
    if (topped > maxHeld) return count > maxHeld ? count : maxHeld;
    return topped;
  }

  bool isStale(DateTime now) => refilledOn.isBefore(jstDate(now));

  StampWallet refill() =>
      StampWallet(count: afterRefill(count), refilledOn: refilledOn);
}

/// The date in Japan, as midnight UTC, so the client and the security
/// rules agree on which day it is.
///
/// Incomodo is Japanese-only for now. When that changes, this and the
/// matching `today()` in firestore.rules have to move to the user's own
/// zone together, or stamps will arrive at an odd hour for them.
DateTime jstDate(DateTime now) {
  final jst = now.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(jst.year, jst.month, jst.day);
}
