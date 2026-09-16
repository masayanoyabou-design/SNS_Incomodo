// ignore_for_file: avoid_print — this is a command-line script; its output
// is the result.
//
// Checks firestore.rules against the local Firestore emulator.
//
//   firebase emulators:start --only firestore --project incomodo-c161e
//   dart run tool/rules_check.dart
//
// The point is the *negative* cases (backlog B22): a rule that allows the
// right thing is easy to write by accident, so what matters is that the
// wrong thing is refused. Talks to the emulator's REST API directly, so
// it needs no Node toolchain — just the emulator and the Dart SDK.
import 'dart:convert';
import 'dart:io';

const projectId = 'incomodo-c161e';
const host = '127.0.0.1';
const port = 8080;
const _docs = '/v1/projects/$projectId/databases/(default)/documents';

String docName(String path) =>
    'projects/$projectId/databases/(default)/documents/$path';

/// The emulator does not verify signatures, so an unsigned token is enough
/// to act as a given user. `owner` is the emulator's admin token, which
/// bypasses the rules and is how the fixtures are set up.
String tokenFor(String uid) {
  String segment(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = segment({'alg': 'none', 'typ': 'JWT'});
  final payload = segment({
    'iss': 'https://securetoken.google.com/$projectId',
    'aud': projectId,
    'iat': now,
    'exp': now + 3600,
    'auth_time': now,
    'user_id': uid,
    'sub': uid,
    'firebase': {'identities': {}, 'sign_in_provider': 'custom'},
  });
  return '$header.$payload.';
}

Map<String, dynamic> str(String v) => {'stringValue': v};
Map<String, dynamic> number(num v) => {'doubleValue': v};
const nullValue = {'nullValue': null};
Map<String, dynamic> time(DateTime v) =>
    {'timestampValue': v.toUtc().toIso8601String()};

final _client = HttpClient();
String _lastBody = '';

/// [as] is a uid, or 'owner' to bypass the rules when setting fixtures up.
Future<int> _send(String method, String path,
    {Object? body, String? as}) async {
  final request =
      await _client.openUrl(method, Uri.parse('http://$host:$port$path'));
  if (as != null) {
    request.headers.set(HttpHeaders.authorizationHeader,
        'Bearer ${as == 'owner' ? 'owner' : tokenFor(as)}');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  _lastBody = await response.transform(utf8.decoder).join();
  return response.statusCode;
}

/// One or more writes, applied together like the app's WriteBatch. Rules
/// that use getAfter() only make sense inside one of these.
Future<int> commit(List<Map<String, dynamic>> writes, {String? as}) =>
    _send('POST', '$_docs:commit', body: {'writes': writes}, as: as);

Future<int> read(String path, {String? as}) =>
    _send('GET', '$_docs/$path', as: as);

/// A create-or-overwrite of a whole document.
Map<String, dynamic> set(String path, Map<String, Object> fields,
        {List<String> serverTimestamps = const []}) =>
    {
      'update': {'name': docName(path), 'fields': fields},
      if (serverTimestamps.isNotEmpty)
        'updateTransforms': [
          for (final field in serverTimestamps)
            {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'},
        ],
    };

/// Touches only [field], setting it to the server's clock.
Map<String, dynamic> stamp(String path, String field) => {
      'update': {'name': docName(path), 'fields': <String, Object>{}},
      'updateMask': {'fieldPaths': <String>[]},
      'updateTransforms': [
        {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'}
      ],
      'currentDocument': {'exists': true},
    };

var _passed = 0;
final _failures = <String>[];

Future<void> allow(String what, Future<int> Function() action) async {
  final status = await action();
  if (status >= 200 && status < 300) {
    _passed++;
    print('  ok    $what');
  } else {
    _failures.add(what);
    print('  FAIL  $what — expected to be allowed, got $status');
    print('        $_lastBody');
  }
}

Future<void> deny(String what, Future<int> Function() action) async {
  final status = await action();
  if (status == 403) {
    _passed++;
    print('  ok    $what');
  } else {
    _failures.add(what);
    print('  FAIL  $what — expected to be refused, got $status');
    print('        $_lastBody');
  }
}

const alice = 'alice';
const bob = 'bob';
const carol = 'carol';

Map<String, Object> envelope(String fromUid) => {
      'fromUid': str(fromUid),
      'fromDisplayName': str('ボブ'),
      'fromHandle': str('bob'),
      'openedAt': nullValue,
    };

List<Map<String, dynamic>> delivery(String id, String fromUid) => [
      set('users/$alice/letters/$id', envelope(fromUid),
          serverTimestamps: ['sentAt']),
      set('users/$alice/letters/$id/content/body', {'body': str('会いたいね')}),
      set('users/$fromUid/sentLetters/$id', {
        'toUid': str(alice),
        'toDisplayName': str('アリス'),
        'toHandle': str('alice'),
        'body': str('会いたいね'),
        'openedAt': nullValue,
      }, serverTimestamps: ['sentAt']),
    ];

Map<String, Object> post(String name, {double latitude = 35.0}) => {
      'name': str(name),
      'latitude': number(latitude),
      'longitude': number(139.0),
    };

Future<void> main() async {
  // Fixtures, written as the emulator's owner so the rules don't apply.
  await commit([
    set('users/$alice', {'displayName': str('アリス'), 'handle': str('alice')}),
    set('users/$bob', {'displayName': str('ボブ'), 'handle': str('bob')}),
    set('users/$carol', {'displayName': str('キャロル'), 'handle': str('carol')}),
    // Alice has accepted Bob, so Bob may write to her. Carol she has not.
    set('users/$alice/friends/$bob',
        {'displayName': str('ボブ'), 'handle': str('bob')}),
  ], as: 'owner');

  print('');
  print('手紙を届ける');
  await deny('a stranger cannot deliver a letter',
      () => commit(delivery('l0', carol), as: carol));
  await deny('nor by putting someone else\'s name on it',
      () => commit(delivery('l0', bob), as: carol));
  await allow('someone the recipient accepted can deliver',
      () => commit(delivery('l1', bob), as: bob));
  await deny('a backdated letter is refused', () {
    final old = DateTime.now().subtract(const Duration(days: 3));
    return commit([
      set('users/$alice/letters/l2', {...envelope(bob), 'sentAt': time(old)}),
    ], as: bob);
  });
  await deny(
      'the text cannot be planted without an envelope',
      () => commit([
            set('users/$alice/letters/l3/content/body', {'body': str('のぞき見')})
          ], as: bob));

  print('');
  print('封をしたままの手紙は読めない');
  await deny('the recipient cannot read the text before opening it',
      () => read('users/$alice/letters/l1/content/body', as: alice));
  await deny('the sender cannot read the recipient\'s envelope',
      () => read('users/$alice/letters/l1', as: bob));
  await deny('a stranger cannot read the envelope',
      () => read('users/$alice/letters/l1', as: carol));
  await deny('the sender cannot mark it opened',
      () => commit([stamp('users/$alice/letters/l1', 'openedAt')], as: bob));

  print('');
  print('開封');
  await allow('the recipient opens it',
      () => commit([stamp('users/$alice/letters/l1', 'openedAt')], as: alice));
  await allow('and only then can read the text',
      () => read('users/$alice/letters/l1/content/body', as: alice));
  await deny(
      'the text can never be rewritten',
      () => commit([
            set('users/$alice/letters/l1/content/body', {'body': str('書き換え')})
          ], as: bob));
  await allow(
      'opening marks the sender\'s copy received',
      () =>
          commit([stamp('users/$bob/sentLetters/l1', 'openedAt')], as: alice));
  await deny(
      'someone else cannot mark the sender\'s copy received',
      () =>
          commit([stamp('users/$bob/sentLetters/l1', 'openedAt')], as: carol));

  print('');
  print('ポスト（B22：不正が拒否されるか）');
  await allow(
      'registering your own post',
      () => commit([
            set('users/$alice/posts/home', post('自宅'),
                serverTimestamps: ['constructionStartedAt'])
          ], as: alice));
  await deny('backdating the construction to skip the 48 hours', () {
    final old = DateTime.now().subtract(const Duration(days: 3));
    return commit([
      set('users/$alice/posts/slot1',
          {...post('拠点1'), 'constructionStartedAt': time(old)})
    ], as: alice);
  });
  await deny(
      'a fifth post',
      () => commit([
            set('users/$alice/posts/slot4', post('拠点4'),
                serverTimestamps: ['constructionStartedAt'])
          ], as: alice));
  await deny(
      'writing someone else\'s post',
      () => commit([
            set('users/$alice/posts/slot1', post('乗っ取り'),
                serverTimestamps: ['constructionStartedAt'])
          ], as: bob));
  await deny('reading someone else\'s post',
      () => read('users/$alice/posts/home', as: bob));
  await deny('moving a post while keeping the old construction time', () async {
    final existing = await read('users/$alice/posts/home', as: alice);
    if (existing != 200) return existing;
    final startedAt = (jsonDecode(_lastBody)['fields']
        as Map)['constructionStartedAt'] as Object;
    return commit([
      set('users/$alice/posts/home', {
        ...post('自宅', latitude: 36.0), // moved
        'constructionStartedAt': startedAt,
      })
    ], as: alice);
  });
  await allow('renaming a post keeps its construction time', () async {
    final existing = await read('users/$alice/posts/home', as: alice);
    if (existing != 200) return existing;
    final startedAt = (jsonDecode(_lastBody)['fields']
        as Map)['constructionStartedAt'] as Object;
    return commit([
      set('users/$alice/posts/home', {
        ...post('うち'),
        'constructionStartedAt': startedAt,
      })
    ], as: alice);
  });

  print('');
  print('プロフィールとID');
  await deny(
      'claiming a handle for someone else',
      () => commit([
            set('handles/taken', {'uid': str(bob)})
          ], as: alice));
  await deny(
      'changing your handle after the fact',
      () => commit([
            set('users/$alice',
                {'displayName': str('アリス'), 'handle': str('alice2')})
          ], as: alice));
  await allow(
      'changing only your display name',
      () => commit([
            set('users/$alice',
                {'displayName': str('アリス改'), 'handle': str('alice')})
          ], as: alice));
  await deny(
      'adding yourself to someone else\'s friends',
      () => commit([
            set('users/$alice/friends/$carol',
                {'displayName': str('キャロル'), 'handle': str('carol')})
          ], as: carol));

  _client.close();
  print('');
  print('$_passed passed, ${_failures.length} failed');
  if (_failures.isNotEmpty) {
    for (final failure in _failures) {
      print('  - $failure');
    }
    exit(1);
  }
}
