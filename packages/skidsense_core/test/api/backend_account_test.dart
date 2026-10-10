import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/src/api/backend_client.dart';
import 'package:skidsense_core/src/api/backend_models.dart';
import 'package:skidsense_core/src/store/stores.dart';
import 'package:test/test.dart';

/// The account's own pages, straight from the phone's new-api login: the
/// balance (`/api/user/self`), the cloud keys (`/api/token/*`) and the groups
/// a key may go in — the paths and shapes the desktop's `src/main/backend.ts`
/// uses, and its dollar figures.
void main() {
  const base = 'https://backend.example';

  String ok(String data) => '{"success":true,"message":"","data":$data}';

  Future<(BackendClient, List<http.Request>)> signedIn((int, String)? Function(http.Request request) handler) async {
    final requests = <http.Request>[];
    final secrets = MemorySecretStore();
    await secrets.putString(
      'auth-session',
      jsonEncode(AuthSession(
        baseUrl: base,
        accessToken: 'tok',
        accessExpiresAt: DateTime.now().millisecondsSinceEpoch + 3600000,
        refreshCookie: 'cookie',
        userId: 42,
        username: 'liunian',
      ).toJson()),
    );
    final backend = BackendClient(
      http: MockClient((request) async {
        requests.add(request);
        final (status, body) = handler(request) ?? (404, '{"success":false,"message":"not found"}');
        return http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      secrets: secrets,
      defaultBaseUrl: base,
    );
    await backend.restore();
    return (backend, requests);
  }

  const tokenList = '''{"page":1,"page_size":100,"total":3,"items":[
    {"id":9,"name":"手机","key":"abcd**********wxyz","status":1,"unlimited_quota":true,"remain_quota":0,"used_quota":250000,
     "expired_time":-1,"group":"default","model_limits_enabled":false,"model_limits":""},
    {"id":8,"name":"手机","key":"older**********","status":2,"unlimited_quota":false,"remain_quota":"1000000","used_quota":0,
     "expired_time":1800000000,"group":"vip","model_limits_enabled":true,"model_limits":"gpt-5,claude-opus"},
    {"id":7,"future":true}
  ]}''';

  test('the balance in dollars, as the desktop counts it', () async {
    final (backend, requests) = await signedIn((request) => request.url.path == '/api/user/self'
        ? (200, ok('{"id":42,"username":"liunian","display_name":"刘念","group":"vip","aff_code":"AbC1","quota":12500000,"used_quota":"750000"}'))
        : null);
    final me = await backend.self();
    expect((me.id, me.username, me.displayName, me.group, me.affCode), (42, 'liunian', '刘念', 'vip', 'AbC1'));
    expect(me.quotaUsd, 25.0);
    expect(me.usedQuotaUsd, 1.5, reason: 'a number in a string reads as the number');
    expect(requests.single.headers['Authorization'], 'Bearer tok');

    expect(usdFromQuota(null), 0);
    expect(usdFromQuota('lots'), 0);
    expect(usdFromQuota(double.nan), 0);
    expect(quotaFromUsd(2.5), 1250000);
    expect(quotaFromUsd(-1), 0);
  });

  test('the keys, newest first, masked', () async {
    final (backend, requests) = await signedIn((request) => request.url.path == '/api/token/' ? (200, ok(tokenList)) : null);
    final keys = await backend.tokens();
    expect(requests.single.method, 'GET');
    expect(requests.single.url.queryParameters, {'p': '1', 'page_size': '100', 'sort_by': 'id', 'sort_order': 'desc'});
    expect(keys.map((key) => key.id), [9, 8, 7]);
    final first = keys.first;
    expect((first.name, first.maskedKey, first.status, first.unlimited, first.usedQuotaUsd, first.expiredTime),
        ('手机', 'abcd**********wxyz', 1, true, 0.5, -1));
    final second = keys[1];
    expect((second.unlimited, second.remainQuotaUsd, second.group, second.modelLimitsEnabled, second.modelLimits),
        (false, 2.0, 'vip', true, 'gpt-5,claude-opus'));
    expect((keys.last.name, keys.last.expiredTime, keys.last.status), ('', -1, 0), reason: 'what is missing defaults');
  });

  test('a new key: created, found by its name among the newest, then revealed', () async {
    final (backend, requests) = await signedIn((request) => switch ((request.method, request.url.path)) {
          ('POST', '/api/token/') => (200, '{"success":true,"message":""}'),
          ('GET', '/api/token/') => (200, ok(tokenList)),
          ('POST', '/api/token/9/key') => (200, ok('{"key":"abcdEFGHijklwxyz"}')),
          _ => null,
        });
    final created = await backend.createToken(const CreateKeyInput(name: '手机', unlimited: false, quotaUsd: 10, group: 'vip'));
    expect((created.id, created.key), (9, 'sk-abcdEFGHijklwxyz'), reason: 'the bearer has the sk- new-api leaves off');
    expect(requests.map((r) => '${r.method} ${r.url.path}'), ['POST /api/token/', 'GET /api/token/', 'POST /api/token/9/key']);
    expect(jsonDecode(requests.first.body), {
      'name': '手机',
      'unlimited_quota': false,
      'remain_quota': 5000000,
      'expired_time': -1,
      'group': 'vip',
      'model_limits_enabled': false,
      'model_limits': '',
    });
  });

  test('a new key that cannot be found again is said so, not made twice', () async {
    final (backend, requests) = await signedIn((request) => switch ((request.method, request.url.path)) {
          ('POST', '/api/token/') => (200, '{"success":true,"message":""}'),
          ('GET', '/api/token/') => (200, ok(tokenList)),
          _ => null,
        });
    await expectLater(
      backend.createToken(const CreateKeyInput(name: '平板')),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'key-not-located')),
    );
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(jsonDecode(requests.first.body), containsPair('remain_quota', 0), reason: 'unlimited by default');
  });

  test('a key revealed keeps an sk- it already has; an empty one is refused; a key is deleted by id', () async {
    final (backend, requests) = await signedIn((request) => switch ((request.method, request.url.path)) {
          ('POST', '/api/token/3/key') => (200, ok('{"key":"sk-already"}')),
          ('POST', '/api/token/4/key') => (200, ok('{"key":""}')),
          ('DELETE', '/api/token/3') => (200, '{"success":true,"message":""}'),
          _ => null,
        });
    expect(await backend.revealToken(3), 'sk-already');
    await expectLater(backend.revealToken(4), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'no-key')));
    await backend.deleteToken(3);
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.path, '/api/token/3');
  });

  test("the groups a key may go in, the auto group's ratio a word", () async {
    final (backend, _) = await signedIn((request) => request.url.path == '/api/user/self/groups'
        ? (200, ok('{"default":{"ratio":1,"desc":"默认分组"},"vip":{"ratio":0.8,"desc":"VIP"},"auto":{"ratio":"自动","desc":"自动选择"},"odd":5}'))
        : null);
    final groups = await backend.tokenGroups();
    expect(groups.map((g) => g.name), ['default', 'vip', 'auto', 'odd']);
    expect((groups[1].ratio, groups[1].ratioLabel, groups[1].desc), (0.8, null, 'VIP'));
    expect((groups[2].ratio, groups[2].ratioLabel), (null, '自动'));
    expect((groups[3].ratio, groups[3].desc), (null, ''));
  });

  test('a refusal from new-api keeps its message', () async {
    final (backend, _) = await signedIn((request) => (200, '{"success":false,"message":"令牌名称过长"}'));
    await expectLater(
      backend.createToken(const CreateKeyInput(name: 'x')),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'server').having((e) => e.message, 'message', '令牌名称过长')),
    );
  });

  test("/config's scopes: what this backend knows, absent from one before them", () async {
    var body = ok('{"enabled":true,"scopes":["sessions","prompt","approve","files","files.write","git","git.write","terminal","settings"],'
        '"default_scopes":["sessions","prompt","approve","files","files.write","git","git.write"]}');
    final (backend, _) = await signedIn((request) => request.url.path == '/api/companion/config' ? (200, body) : null);
    final config = await backend.companionConfig();
    expect(config.scopes?.last, 'settings');
    expect(config.defaultScopes, isNot(contains('settings')));
    body = ok('{"enabled":true}');
    final old = await backend.companionConfig();
    expect(old.scopes, isNull);
    expect(old.defaultScopes, isNull);
  });
}
