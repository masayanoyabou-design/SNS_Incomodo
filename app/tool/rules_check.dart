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

/// Adds [by] to [field], the way FieldValue.increment does.
Map<String, dynamic> increment(String path, String field, int by) => {
      'update': {'name': docName(path), 'fields': <String, Object>{}},
      'updateMask': {'fieldPaths': <String>[]},
      'updateTransforms': [
        {
          'fieldPath': field,
          'increment': {'integerValue': '$by'}
        }
      ],
      'currentDocument': {'exists': true},
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
const dave = 'dave';

/// The day in Japan as midnight UTC — the same thing today() computes in
/// the rules.
final today = () {
  final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
  return DateTime.utc(jst.year, jst.month, jst.day);
}();
final yesterday = today.subtract(const Duration(days: 1));

Map<String, Object> purse(int count, DateTime on) => {
      'count': {'integerValue': '$count'},
      'refilledOn': time(on),
    };

/// Passing null for a design leaves it off entirely.
Map<String, Object> envelope(String fromUid,
        {String? stampId = 'basic', String? envelopeId = 'plain'}) =>
    {
      'fromUid': str(fromUid),
      'fromDisplayName': str('ボブ'),
      'fromHandle': str('bob'),
      if (stampId != null) 'stampId': str(stampId),
      if (envelopeId != null) 'envelopeId': str(envelopeId),
      'openedAt': nullValue,
    };

List<Map<String, dynamic>> delivery(
  String id,
  String fromUid, {
  String? stampId = 'basic',
  String? envelopeId = 'plain',
  String? paperId = 'ruled',
}) =>
    [
      set('users/$alice/letters/$id',
          envelope(fromUid, stampId: stampId, envelopeId: envelopeId),
          serverTimestamps: ['sentAt']),
      set('users/$alice/letters/$id/content/body', {
        'body': str('会いたいね'),
        if (paperId != null) 'paperId': str(paperId),
      }),
      set('users/$fromUid/sentLetters/$id', {
        'toUid': str(alice),
        'toDisplayName': str('アリス'),
        'toHandle': str('alice'),
        if (stampId != null) 'stampId': str(stampId),
        if (envelopeId != null) 'envelopeId': str(envelopeId),
        if (paperId != null) 'paperId': str(paperId),
        'body': str('会いたいね'),
        'openedAt': nullValue,
      }, serverTimestamps: ['sentAt']),
    ];

/// A delivery with a stamp spent on it, which is what the app always sends.
List<Map<String, dynamic>> stamped(
  String id,
  String fromUid, {
  String? stampId = 'basic',
  String? envelopeId = 'plain',
  String? paperId = 'ruled',
}) =>
    [
      increment('users/$fromUid/stamps/wallet', 'count', -1),
      ...delivery(id, fromUid,
          stampId: stampId, envelopeId: envelopeId, paperId: paperId),
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
    // Everyone but Dave starts with stamps, so a refused letter is
    // refused for the reason under test and not for want of one.
    set('users/$alice/stamps/wallet', purse(5, today)),
    set('users/$bob/stamps/wallet', purse(5, today)),
    set('users/$carol/stamps/wallet', purse(5, today)),
  ], as: 'owner');

  print('');
  print('手紙を届ける');
  await deny('a stranger cannot deliver a letter',
      () => commit(stamped('l0', carol), as: carol));
  await deny('nor by putting someone else\'s name on it',
      () => commit(stamped('l0', bob), as: carol));
  await allow('someone the recipient accepted can deliver',
      () => commit(stamped('l1', bob), as: bob));
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
  print('切手（P3-6）');
  await deny(
      'a wallet cannot be conjured with a pile of stamps',
      () => commit([set('users/$dave/stamps/wallet', purse(50, today))],
          as: dave));
  await deny(
      'nor dated tomorrow to skip ahead',
      () => commit([
            set('users/$dave/stamps/wallet',
                purse(2, today.add(const Duration(days: 1))))
          ], as: dave));
  await allow(
      'the first wallet holds one day\'s worth',
      () => commit([set('users/$dave/stamps/wallet', purse(2, today))],
          as: dave));
  await deny(
      'and cannot be refilled again the same day',
      () => commit([set('users/$dave/stamps/wallet', purse(4, today))],
          as: dave));
  await deny('nor read by anyone else',
      () => read('users/$dave/stamps/wallet', as: bob));

  // Rewind to yesterday as owner, so a refill becomes due.
  await commit([set('users/$dave/stamps/wallet', purse(2, yesterday))],
      as: 'owner');
  await deny(
      'a refill cannot hand out more than a day\'s worth',
      () => commit([set('users/$dave/stamps/wallet', purse(9, today))],
          as: dave));
  await allow(
      'a day later, a refill is due',
      () => commit([set('users/$dave/stamps/wallet', purse(4, today))],
          as: dave));

  await commit([set('users/$dave/stamps/wallet', purse(9, yesterday))],
      as: 'owner');
  await deny(
      'and it never goes past the ceiling',
      () => commit([set('users/$dave/stamps/wallet', purse(11, today))],
          as: dave));
  await allow(
      'stopping at ten',
      () => commit([set('users/$dave/stamps/wallet', purse(10, today))],
          as: dave));

  print('');
  print('切手を使って手紙を送る');
  await commit([set('users/$bob/stamps/wallet', purse(1, today))],
      as: 'owner');

  await deny('spending two stamps on one letter', () {
    final writes = stamped('l4', bob);
    writes[0] = increment('users/$bob/stamps/wallet', 'count', -2);
    return commit(writes, as: bob);
  });
  await deny('sending without paying at all',
      () => commit(delivery('l5', bob), as: bob));
  await allow('sending spends exactly one',
      () => commit(stamped('l6', bob), as: bob));
  await deny('out of stamps, the letter does not go either',
      () => commit(stamped('l7', bob), as: bob));
  print('');
  print('切手の絵柄（P3-7）');
  await commit([set('users/$bob/stamps/wallet', purse(5, today))],
      as: 'owner');
  await allow('a letter can carry any free design',
      () => commit(stamped('l8', bob, stampId: 'sakura'), as: bob));
  await deny(
      'but not a design nobody was given',
      () => commit(stamped('l9', bob, stampId: 'premium_gold'), as: bob));
  await deny('nor go out with no design at all',
      () => commit(stamped('l10', bob, stampId: null), as: bob));

  print('');
  print('封筒と便箋（P3-7の拡張）');
  await deny(
      'an envelope nobody was given is refused',
      () => commit(stamped('l11', bob, envelopeId: 'premium_gold'), as: bob));
  await deny('as is a letter with no envelope',
      () => commit(stamped('l12', bob, envelopeId: null), as: bob));
  await deny(
      'paper nobody was given is refused',
      () => commit(stamped('l13', bob, paperId: 'premium_gold'), as: bob));
  await deny('as is a letter with no paper',
      () => commit(stamped('l14', bob, paperId: null), as: bob));
  // l8 above was delivered with the default envelope and paper.
  await deny('the paper stays hidden with the text until opening',
      () => read('users/$alice/letters/l8/content/body', as: alice));

  await deny(
      'and helping yourself to more is refused',
      () => commit([increment('users/$bob/stamps/wallet', 'count', 5)],
          as: bob));

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
  print('');
  print('友だちリクエスト');
  Map<String, Object> request({bool? reply, Map<String, Object> extra = const {}}) =>
      {
        'displayName': str('キャロル'),
        'handle': str('carol'),
        if (reply != null) 'reply': {'booleanValue': reply},
        ...extra,
      };
  await allow(
      'asking someone to connect',
      () => commit([
            set('users/$alice/friendRequests/$carol', request(),
                serverTimestamps: ['createdAt'])
          ], as: carol));
  await allow(
      'the request sent back on accepting is marked as a reply',
      () => commit([
            set('users/$carol/friendRequests/$alice',
                request(reply: true)..['handle'] = str('alice'),
                serverTimestamps: ['createdAt'])
          ], as: alice));
  await deny(
      'a request cannot be sent in someone else\'s name',
      () => commit([
            set('users/$alice/friendRequests/$bob', request(),
                serverTimestamps: ['createdAt'])
          ], as: carol));
  await deny(
      'nor carry anything but who is asking',
      () => commit([
            set('users/$alice/friendRequests/$carol',
                request(extra: {'friendOf': str(alice)}),
                serverTimestamps: ['createdAt'])
          ], as: carol));
  await deny(
      'reply has to be a yes or a no',
      () => commit([
            set('users/$alice/friendRequests/$carol',
                request(extra: {'reply': str('yes')}),
                serverTimestamps: ['createdAt'])
          ], as: carol));
  await deny('and only the recipient can read them',
      () => read('users/$alice/friendRequests/$carol', as: bob));

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
