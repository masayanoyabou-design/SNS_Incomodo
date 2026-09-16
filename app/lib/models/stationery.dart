/// Something a letter is made of that the sender chooses: the stamp, the
/// envelope, the paper (MANUAL 23, 25).
///
/// All three work the same way, so adding a new design of any of them is
/// the same three steps:
///
/// 1. add it to that kind's `free` list (e.g. EnvelopeDesign.free)
/// 2. give it a look in theme/ (e.g. theme/envelope_art.dart)
/// 3. add its id to the matching list in firestore.rules
///    (stationery_test fails until you do)
abstract interface class StationeryDesign {
  String get id;
  String get name;
}

/// The design with [id], or [fallback] for letters written before this kind
/// of design existed, or with one this build of the app doesn't know yet.
T designById<T extends StationeryDesign>(
  List<T> designs,
  String? id, {
  required T fallback,
}) =>
    designs.firstWhere((design) => design.id == id, orElse: () => fallback);

/// The envelope a letter arrives in. Like the stamp, it is visible before
/// the letter is opened.
class EnvelopeDesign implements StationeryDesign {
  const EnvelopeDesign._(this.id, this.name);

  @override
  final String id;
  @override
  final String name;

  static const plain = EnvelopeDesign._('plain', '白い封筒');

  /// Everyone can use these. firestore.rules keeps a copy (freeEnvelope).
  static const free = [plain];

  static const defaultId = 'plain';

  static EnvelopeDesign byId(String? id) =>
      designById(free, id, fallback: plain);
}

/// The paper the letter is written on. Unlike the stamp and envelope it is
/// inside, so it is stored with the letter's text and — like the text —
/// the server won't hand it over until the letter has been opened.
class PaperDesign implements StationeryDesign {
  const PaperDesign._(this.id, this.name);

  @override
  final String id;
  @override
  final String name;

  static const ruled = PaperDesign._('ruled', '罫線の便箋');

  /// Everyone can use these. firestore.rules keeps a copy (freePaper).
  static const free = [ruled];

  static const defaultId = 'ruled';

  static PaperDesign byId(String? id) => designById(free, id, fallback: ruled);
}
