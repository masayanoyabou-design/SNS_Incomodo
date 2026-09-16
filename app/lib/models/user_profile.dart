/// A user's public identity: the name shown on letters, and the handle
/// other people use to find them (PRD F-02 addresses letters by person).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.handle,
  });

  final String uid;
  final String displayName;

  /// Unique, lowercase, without the leading "@".
  final String handle;

  String get handleWithAt => '@$handle';

  static const handlePattern = r'^[a-z0-9_]{3,15}$';

  /// Returns an error message, or null if the name is usable.
  static String? validateDisplayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '表示名を入力してください';
    if (trimmed.length > 20) return '表示名は20文字以内にしてください';
    return null;
  }

  /// Returns an error message, or null if the handle is usable.
  /// Accepts input with or without a leading "@".
  static String? validateHandle(String value) {
    final normalized = normalizeHandle(value);
    if (normalized.isEmpty) return 'IDを入力してください';
    if (normalized.length < 3) return 'IDは3文字以上にしてください';
    if (normalized.length > 15) return 'IDは15文字以内にしてください';
    if (!RegExp(handlePattern).hasMatch(normalized)) {
      return 'IDに使えるのは英小文字・数字・アンダースコア（_）だけです';
    }
    return null;
  }

  /// Strips "@", trims, and lowercases so "@Goto " and "goto" match.
  static String normalizeHandle(String value) =>
      value.trim().replaceFirst(RegExp('^@'), '').toLowerCase();
}
