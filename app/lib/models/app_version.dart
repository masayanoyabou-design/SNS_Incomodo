/// Which build of the app this is, and whether the server still accepts it
/// (backlog B31).
///
/// When the rules start requiring something new of every write, builds
/// from before then can no longer do their job — as happened when letters
/// had to name their envelope and paper. Raising `minBuild` in
/// `config/app` on the server then asks those builds to update, instead of
/// leaving them failing with permission errors.
abstract final class AppVersion {
  /// The number after `+` in pubspec.yaml's `version:`. They have to change
  /// together; app_version_test checks that they match.
  static const build = 1;
}

/// True when the server has said builds below [minimum] must update. No
/// answer from the server never blocks anyone.
bool needsUpdate({required int current, required int? minimum}) =>
    minimum != null && current < minimum;
