import 'stationery.dart';

/// A stamp's design — what gets stuck on a letter (MANUAL 23, 24).
///
/// Separate from how many stamps you hold (StampWallet): the count decides
/// whether you can send, the design is what you say by choosing it. And on
/// a letter still waiting at the post, the stamp and the envelope are all
/// the recipient can see.
///
/// This is the catalogue only. What each design looks like lives in
/// theme/stamp_art.dart, so real artwork can replace it without touching
/// any of this. Adding one is described on [StationeryDesign].
class StampDesign implements StationeryDesign {
  const StampDesign._(this.id, this.name);

  @override
  final String id;
  @override
  final String name;

  static const basic = StampDesign._('basic', '通常切手');
  static const sakura = StampDesign._('sakura', '桜');
  static const aozora = StampDesign._('aozora', '青空');
  static const yoru = StampDesign._('yoru', '夜');
  static const konoha = StampDesign._('konoha', '木の葉');

  /// Everyone can stick these on any letter.
  ///
  /// firestore.rules keeps its own copy of these ids (freeStamp), so a
  /// letter can't carry a design nobody was given — a future paid one, say.
  static const free = [basic, sakura, aozora, yoru, konoha];

  static const defaultId = 'basic';

  static StampDesign byId(String? id) => designById(free, id, fallback: basic);
}
