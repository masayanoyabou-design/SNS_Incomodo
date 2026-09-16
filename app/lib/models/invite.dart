import 'user_profile.dart';

/// Invite links and the QR codes that carry them.
///
/// A link points at the landing page, so someone who doesn't have the app
/// yet still lands somewhere useful. The handle rides along in `?id=`, and
/// the app reads it back out when the link is pasted (or a QR is scanned).
class Invite {
  Invite._();

  /// The landing page. Swap this for the real domain once we own one — the
  /// links already handed out keep working as long as [handleFrom] still
  /// recognises the shape.
  static const site = 'https://snazzy-parfait-172aba.netlify.app';

  /// The link to give someone so they can find [handle].
  static String linkFor(String handle) =>
      '$site/?id=${UserProfile.normalizeHandle(handle)}';

  /// The text to paste into a chat app, link included.
  static String messageFor(UserProfile profile) =>
      '${profile.displayName}（${profile.handleWithAt}）がIncomodoであなたとつながりたがっています。\n'
      '${linkFor(profile.handle)}';

  /// Reads a handle out of whatever the user pasted: a full invite link,
  /// an "@id", or a bare id. Returns null if there is no usable handle.
  ///
  /// Anything past the handle is ignored, so a link copied with extra
  /// tracking parameters still works.
  static String? handleFrom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    var candidate = trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final fromQuery = uri.queryParameters['id'];
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
      candidate = fromQuery ?? (segments.isEmpty ? '' : segments.last);
    }

    final handle = UserProfile.normalizeHandle(candidate);
    return UserProfile.validateHandle(handle) == null ? handle : null;
  }
}
