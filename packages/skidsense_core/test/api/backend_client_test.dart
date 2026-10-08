import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/src/api/backend_client.dart';
import 'package:skidsense_core/src/store/stores.dart';
import 'package:test/test.dart';

/// The backend client against a mock HTTP client: the
/// `{success,message,data}` envelope, the refresh-once-on-401 rule, the single
/// `new_api_refresh` cookie, and the companion endpoints' paths and shapes.
void main() {
  const base = 'https://backend.example';

  String ok(String data) => '{"success":true,"message":"","data":$data}';
  int epochSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String loginBody([String token = 'tok-1']) =>
      '{"access_token":"$token","access_expires_at":${epochSeconds() + 900},"user":{"id":42,"username":"liunian"},"session":{"id":"sess-1"}}';

  (BackendClient, List<http.Request>) client(
    (int, String) Function(http.Request request) handler, {
    SecretStore? secrets,
    String language = 'zh-CN',
  }) {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      final (status, body) = handler(request);
      return http.Response(body, status, headers: {
        'content-type': 'application/json; charset=utf-8',
        'set-cookie': 'new_api_refresh=cookie-1; Path=/; HttpOnly',
      });
    });
    return (BackendClient(http: mock, secrets: secrets ?? MemorySecretStore(), defaultBaseUrl: base, language: () => language), requests);
  }

  (int, String) loginFlow(http.Request request, {String token = 'tok-1'}) {
    final path = request.url.path;
    if (path.endsWith('encryption-key')) return (200, ok('{"enabled":false}'));
    if (path.endsWith('/api/user/login')) return (200, ok(loginBody(token)));
    return (200, ok('null'));
  }

  test("every request asks for messages in the app's language", () async {
    final (backend, requests) = client((_) => (200, ok('{"system_name":"x"}')), language: 'zh-TW');
    await backend.status(base);
    expect(requests.last.headers['Accept-Language'], 'zh-TW');
  });

  test('a login stores the token, the cookie and the session', () async {
    final secrets = MemorySecretStore();
    final (backend, requests) = client(loginFlow, secrets: secrets);
    expect(await backend.login(base, 'liunian', 'pw'), isNull);
    final session = backend.session.value!;
    expect(session.accessToken, 'tok-1');
    expect(session.refreshCookie, 'cookie-1');
    expect(session.sessionId, 'sess-1');
    expect(session.userId, 42);
    expect(session.username, 'liunian');
    expect(await secrets.getString('auth-session'), contains('tok-1'));
    expect(requests.map((r) => r.url.path), ['/api/user/login/encryption-key', '/api/user/login']);
    expect(requests.every((r) => !r.followRedirects), isTrue, reason: 'no redirect gets the bearer');
  });

  test('the session survives a restart', () async {
    final secrets = MemorySecretStore();
    final (first, _) = client(loginFlow, secrets: secrets);
    await first.login(base, 'u', 'p');
    final (second, _) = client(loginFlow, secrets: secrets);
    expect(second.session.value, isNull);
    await second.restore();
    expect(second.session.value?.accessToken, 'tok-1');
    expect(second.baseUrl, base);
  });

  test('a login sends the GeeTest validate as a query parameter', () async {
    final (backend, requests) = client((_) => (200, ok(loginBody())));
    const validate = '{"lot_number":"lot","captcha_output":"cap","pass_token":"pass","gen_time":"1700000000"}';
    await backend.login(base, 'u', 'p', geetest: validate);
    final login = requests.firstWhere((r) => r.url.path.endsWith('/api/user/login'));
    expect(login.url.queryParameters['geetest'], validate);
    expect(login.url.queryParameters.containsKey('turnstile'), isFalse);
    expect(jsonDecode(login.body), {'username': 'u', 'password': 'p'});
  });

  test('a second factor comes back as a challenge', () async {
    final (backend, _) = client((_) => (
          200,
          ok('{"require_verification":true,"flow_token":"flow-1","expires_at":1,"methods":[{"method":"2fa","available":true},{"method":"passkey","available":false,"reason":"no key"}]}')
        ));
    final challenge = (await backend.login(base, 'u', 'p'))!;
    expect(challenge.flowToken, 'flow-1');
    expect(challenge.methods.first.method, '2fa');
    expect(challenge.methods[1].available, isFalse);
    expect(backend.session.value, isNull);
  });

  test('verify completes the challenge', () async {
    final (backend, requests) =
        client((request) => request.url.path.endsWith('/verify') ? (200, ok(loginBody('tok-2'))) : (200, ok('{"enabled":false}')));
    await backend.verifyLogin(base, 'flow-1', ' 123456 ');
    expect(backend.session.value?.accessToken, 'tok-2');
    expect(requests.last.url.path, '/api/user/login/verify');
    expect((jsonDecode(requests.last.body) as Map<String, Object?>)['code'], '123456');
  });

  test("a failed call carries the server's message", () async {
    final (backend, _) = client((_) => (200, '{"success":false,"message":"密码错误","data":null}'));
    await expectLater(
      backend.login(base, 'u', 'p'),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'server').having((e) => e.message, 'message', '密码错误')),
    );
  });

  test('a 401 refreshes once, then succeeds', () async {
    var refreshes = 0;
    final (backend, requests) = client((request) {
      final path = request.url.path;
      if (path.endsWith('encryption-key')) return (200, ok('{"enabled":false}'));
      if (path.endsWith('/api/user/login')) return (200, ok(loginBody('stale')));
      if (path.endsWith('/auth/refresh')) {
        refreshes += 1;
        return (200, ok(loginBody('fresh')));
      }
      if (path.endsWith('/hosts')) {
        return request.headers['Authorization'] == 'Bearer stale'
            ? (401, '{"success":false,"message":"token expired"}')
            : (200, ok('[{"host_id":"h1","name":"Mac","online":true}]'));
      }
      return (200, ok('null'));
    });
    await backend.login(base, 'u', 'p');
    final hosts = await backend.hosts();
    expect(hosts.single.hostId, 'h1');
    expect(hosts.single.online, isTrue);
    expect(refreshes, 1);
    expect(requests.firstWhere((r) => r.url.path.endsWith('/hosts')).headers['Authorization'], 'Bearer stale');
    expect(backend.session.value?.accessToken, 'fresh');
  });

  test('a refresh sends the cookie and the session header, once for concurrent callers', () async {
    var refreshes = 0;
    final (backend, requests) = client((request) {
      if (request.url.path.endsWith('/auth/refresh')) refreshes += 1;
      return request.url.path.endsWith('/auth/refresh') ? (200, ok(loginBody('tok-2'))) : loginFlow(request);
    });
    await backend.login(base, 'u', 'p');
    await backend.invalidateAccessToken();
    final tokens = await Future.wait([backend.accessToken(), backend.accessToken(), backend.accessToken()]);
    expect(tokens, ['tok-2', 'tok-2', 'tok-2']);
    expect(refreshes, 1, reason: 'single-flight');
    final refresh = requests.firstWhere((r) => r.url.path.endsWith('/auth/refresh'));
    expect(refresh.headers['Cookie'], 'new_api_refresh=cookie-1');
    expect(refresh.headers['X-Auth-Session'], 'sess-1');
  });

  test('a refused refresh is a real logout', () async {
    final secrets = MemorySecretStore();
    final (backend, _) = client(
      (request) => request.url.path.endsWith('/auth/refresh') ? (401, '{"success":false,"message":"invalid refresh"}') : loginFlow(request),
      secrets: secrets,
    );
    await backend.login(base, 'u', 'p');
    await backend.invalidateAccessToken();
    expect(await backend.accessToken(), isNull);
    expect(backend.session.value, isNull);
    expect(await secrets.getString('auth-session'), isNull);
  });

  test('the companion paths and shapes', () async {
    final (backend, requests) = client((request) {
      final path = request.url.path;
      final method = request.method;
      final body = switch (path) {
        _ when path.endsWith('/api/user/login') => ok(loginBody()),
        _ when path.endsWith('/api/companion/config') => ok(
            '{"enabled":true,"grant_public_key":"k","access_ttl":3600,"enroll_ttl":600,"ws_path":"/api/companion/ws","history":{"enabled":true,"max_blob_bytes":8388608,"max_user_bytes":268435456},"relay":{"user_bytes_per_second":102400}}'),
        _ when path.endsWith('/api/companion/devices') && method == 'POST' => ok(
            '{"device":{"device_id":"dev-1","host_id":"h1","name":"我的手机","public_key":"pub-key","scopes":["sessions"],"status":"pending"},"ticket":"ticket-1","ticket_expires_at":3}'),
        _ when path.endsWith('/api/companion/devices') =>
          ok('[{"device_id":"dev-1","host_id":"h1","name":"我的手机","status":"active","scopes":["sessions"]}]'),
        _ when path.contains('/api/companion/devices/') =>
          ok('{"device_id":"dev-1","host_id":"h1","name":"新名字","status":"active","scopes":["sessions","prompt"]}'),
        _ when path.endsWith('/api/companion/grant') => ok('{"grant":"a.b","expires_at":99}'),
        _ when path.endsWith('/api/companion/history/keys') => ok('[{"epoch":1,"wrapped":"w"}]'),
        _ when path.endsWith('/api/companion/history/sessions/blob') =>
          ok('{"session_key":"claude:1","epoch":1,"updated_at":5,"blob":"b"}'),
        _ when path.endsWith('/api/companion/history/sessions') => ok('[{"session_key":"claude:1","epoch":1,"updated_at":5,"size":10}]'),
        _ => ok('null'),
      };
      return (200, body);
    });
    await backend.login(base, 'u', 'p');
    final device = await backend.registerDevice('h1', '我的手机', 'pub-key', 'android');
    expect(device.device.deviceId, 'dev-1');
    expect(device.ticket, 'ticket-1');
    expect((await backend.grant('h1', 'dev-1')).grant, 'a.b');
    expect(await backend.devices('h1'), hasLength(1));
    await backend.updateDevice('dev-1', name: '新名字', scopes: ['sessions', 'prompt']);
    await backend.revokeDevice('dev-1');
    final config = await backend.companionConfig();
    expect(config.enabled, isTrue);
    expect(config.accessTtl, 3600);
    expect(config.relay?.userBytesPerSecond, 102400);
    expect((await backend.historyKeys('h1', 'dev-1')).single.epoch, 1);
    expect((await backend.historySessions('h1', since: 5)).single.size, 10);
    expect((await backend.historyBlob('h1', 'claude:1')).blob, 'b');

    final patch = requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/companion/devices/dev-1');
    expect(jsonDecode(patch.body), {
      'name': '新名字',
      'scopes': ['sessions', 'prompt'],
    });
    expect(requests.firstWhere((r) => r.method == 'DELETE').url.path, '/api/companion/devices/dev-1');
    final sessions = requests.where((r) => r.url.path == '/api/companion/history/sessions').toList();
    expect(sessions.single.url.queryParameters['since'], '5');
    expect(requests.last.url.queryParameters['session_key'], 'claude:1');
    expect(() => backend.revokeDevice('../etc'), throwsArgumentError);
  });

  test('the companion API needs a login', () async {
    final (backend, _) = client((_) => (200, ok('null')));
    await expectLater(backend.hosts(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'not-signed-in')));
  });

  test('a body that is not JSON is reported as such, with the address', () async {
    final (backend, _) = client((_) => (200, '<html>proxy error</html>'));
    await expectLater(
      backend.status(base),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unparsable').having((e) => e.base, 'base', base)),
    );
  });

  test('an unreachable server is reported with its address', () async {
    final backend = BackendClient(
      http: MockClient((_) => throw Exception('connection refused')),
      secrets: MemorySecretStore(),
    );
    await expectLater(
      backend.status(base),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable').having((e) => e.base, 'base', base)),
    );
  });

  test('logout clears the session even when the server fails', () async {
    final secrets = MemorySecretStore();
    final (backend, _) = client(
      (request) => request.url.path.endsWith('/auth/logout') ? (500, '{"success":false,"message":"boom"}') : loginFlow(request),
      secrets: secrets,
    );
    await backend.login(base, 'u', 'p');
    await backend.logout();
    expect(backend.session.value, isNull);
    expect(await secrets.getString('auth-session'), isNull);
  });
}
