import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

/// The encrypted history (spec §11), end to end against a backend that holds
/// only ciphertext: keys wrapped to this device, blobs bound to their
/// session and epoch, decrypted here and searched here.
void main() {
  const hostId = 'host-1';
  const base = 'https://backend.example';
  final device = Primitives.generateKeyPair();
  final historyKey = Primitives.randomBytes(32);
  final otherKey = Primitives.randomBytes(32);

  String sealed(String sessionKey, int epoch, Map<String, Object?> session, {List<int>? key}) => B64u.encode(
        HistoryCrypto.sealBlob(key ?? historyKey, HistoryCrypto.historyAad(hostId, sessionKey, epoch), utf8.encode(jsonEncode(session))),
      );

  Map<String, Object?> session(String title, String said) => {
        'v': 1,
        'row': {'key': 'claude:$title', 'title': title, 'agent': 'claude', 'preview': said},
        'turns': [
          {
            'taskId': 't1',
            'prompt': '问一下 $title',
            'snapshot': {'text': said},
          },
        ],
      };

  late List<String> downloads;

  Future<HistoryRepository> repository() async {
    downloads = [];
    final blobs = {
      'claude:a': sealed('claude:a', 1, session('a', '关于数据库迁移的讨论')),
      'claude:b': sealed('claude:b', 2, session('b', 'the weather is nice')),
      // Swapped in by the backend: a's ciphertext under b's name.
      'claude:swapped': sealed('claude:a', 1, session('a', 'x')),
      'claude:wrong-key': sealed('claude:wrong-key', 1, session('w', 'x'), key: otherKey),
    };
    final wraps = [
      {'epoch': 1, 'wrapped': B64u.encode(HistoryCrypto.wrapKey(historyKey, device.pub, HistoryCrypto.wrapContext(hostId, 1)))},
      {'epoch': 2, 'wrapped': B64u.encode(HistoryCrypto.wrapKey(historyKey, device.pub, HistoryCrypto.wrapContext(hostId, 2)))},
      // Wrapped to some other device: skipped, not fatal.
      {
        'epoch': 3,
        'wrapped': B64u.encode(HistoryCrypto.wrapKey(historyKey, Primitives.generateKeyPair().pub, HistoryCrypto.wrapContext(hostId, 3))),
      },
    ];
    final backend = BackendClient(
      http: MockClient((request) async {
        final path = request.url.path;
        String data;
        if (path.endsWith('/api/user/login')) {
          data = '{"access_token":"t","access_expires_at":9999999999,"user":{"id":1,"username":"u"}}';
        } else if (path.endsWith('/history/keys')) {
          data = jsonEncode(wraps);
        } else if (path.endsWith('/history/sessions/blob')) {
          final key = request.url.queryParameters['session_key']!;
          downloads.add(key);
          data = jsonEncode({'session_key': key, 'epoch': key == 'claude:b' ? 2 : 1, 'blob': blobs[key]});
        } else if (path.endsWith('/history/sessions')) {
          data = jsonEncode([
            {'session_key': 'claude:a', 'epoch': 1, 'updated_at': 10, 'size': 100},
            {'session_key': 'claude:b', 'epoch': 2, 'updated_at': 30, 'size': 100},
            {'session_key': 'claude:swapped', 'epoch': 1, 'updated_at': 20, 'size': 100},
            {'session_key': 'claude:wrong-key', 'epoch': 1, 'updated_at': 5, 'size': 100},
            {'session_key': 'claude:future', 'epoch': 9, 'updated_at': 1, 'size': 100},
          ]);
        } else {
          data = '{"enabled":false}';
        }
        return http.Response('{"success":true,"message":"","data":$data}', 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      secrets: MemorySecretStore(),
    );
    await backend.login(base, 'u', 'p');
    final repository = HistoryRepository(backend: backend, identity: device, hostId: hostId);
    await repository.refreshKeys('dev-1');
    return repository;
  }

  test('keys wrapped to this device open; one wrapped to another is skipped', () async {
    final history = await repository();
    expect(history.keysKnown, isTrue);
    expect(history.currentEpoch, 2);
  });

  test('the list downloads nothing; opening downloads once (S25)', () async {
    final history = await repository();
    final entries = await history.load();
    expect(entries.map((e) => e.sessionKey).first, 'claude:b', reason: 'newest first');
    expect(downloads, isEmpty);
    final a = entries.firstWhere((e) => e.sessionKey == 'claude:a');
    final opened = await history.open(a);
    expect(opened.problem, isNull);
    expect(opened.row?.title, 'a');
    expect(opened.turns.single.snapshot.text, '关于数据库迁移的讨论');
    await history.open(a);
    expect(downloads, ['claude:a'], reason: 'cached after the first open');
  });

  test('a swapped blob, a wrong key and an unknown epoch each say what went wrong', () async {
    final history = await repository();
    final entries = {for (final e in await history.load()) e.sessionKey: e};
    expect((await history.open(entries['claude:swapped']!)).problem, HistoryProblem.decrypt);
    expect((await history.open(entries['claude:wrong-key']!)).problem, HistoryProblem.decrypt);
    expect((await history.open(entries['claude:future']!)).problem, HistoryProblem.noKey);
    expect(downloads, isNot(contains('claude:future')), reason: 'no download without a key for it');
  });

  test('search runs here, over decrypted text', () async {
    final history = await repository();
    final entries = await history.load();
    final opened = [for (final e in entries) await history.open(e)];
    final hits = HistoryRepository.search(opened, '数据库');
    expect(hits.map((e) => e.sessionKey), ['claude:a']);
    expect(HistoryRepository.excerpt(hits.single, '数据库'), contains('数据库迁移'));
    expect(HistoryRepository.search(opened, 'WEATHER').single.sessionKey, 'claude:b');
  });
}
