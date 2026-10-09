import 'dart:async';
import 'dart:convert';
import 'dart:io' show OSError, SocketException;

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

/// A backend whose `/grant` is over the per-user limit while [limit] is set:
/// 429 with that `Retry-After`, and [body] — empty from new-api's limiter,
/// an envelope from something else in front of it.
class _RateLimitedBackend extends TestBackend {
  _RateLimitedBackend(this.body);

  final String body;
  Duration? limit;

  @override
  BackendClient client(SecretStore secrets) => BackendClient(
        http: MockClient((request) async {
          final path = request.url.path;
          log.add('${request.method} $path');
          final wait = limit;
          if (wait != null && path.endsWith('/api/companion/grant')) {
            return http.Response(body, 429, headers: {
              'retry-after': '${wait.inSeconds}',
              if (body.isNotEmpty) 'content-type': 'application/json; charset=utf-8',
            });
          }
          final text = switch (path) {
            _ when path.endsWith('/api/companion/grant') => TestBackend.grant(),
            _ when path.endsWith('/api/companion/config') => TestBackend.ok('{"enabled":true}'),
            _ => TestBackend.ok('[]'),
          };
          return http.Response(text, 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        secrets: secrets,
        defaultBaseUrl: base,
      );
}

/// The refresh in front of `/grant`, behind new-api's in-memory
/// AuthSessionRateLimit: 60 let through in any 20 minutes — a 500 counted
/// like any other, a refused one not — and past that 429, without a body,
/// with the whole window as its Retry-After. Answers 500 while [down].
class _RefreshLimitedBackend extends TestBackend {
  bool down = false;
  final List<DateTime> _through = [];
  final List<int> answered = [];
  final List<DateTime> sent = [];

  /// The limit already spent, by refreshes that age out after [left].
  void spend(Duration left) {
    final at = clock.now().subtract(const Duration(minutes: 20)).add(left);
    _through.addAll(List.filled(60, at));
  }

  @override
  BackendClient client(SecretStore secrets) => BackendClient(
        http: MockClient((request) async {
          final path = request.url.path;
          log.add('${request.method} $path');
          const json = {'content-type': 'application/json; charset=utf-8'};
          if (path.endsWith('/api/user/auth/refresh')) {
            final now = clock.now();
            sent.add(now);
            _through.removeWhere((at) => now.difference(at) >= const Duration(minutes: 20));
            final (status, body) = _through.length >= 60
                ? (429, '')
                : down
                    ? (500, '{"success":false,"code":"AUTH_INTERNAL_ERROR","message":"Internal Server Error"}')
                    : (200, TestBackend.ok(TestBackend.loginBody(42, 'user42')));
            if (status != 429) _through.add(now);
            answered.add(status);
            return http.Response(body, status, headers: {...json, if (status == 429) 'retry-after': '1200'});
          }
          final text = switch (path) {
            _ when path.endsWith('/api/companion/grant') => TestBackend.grant(),
            _ when path.endsWith('/api/companion/config') => TestBackend.ok('{"enabled":true}'),
            _ => TestBackend.ok('[]'),
          };
          return http.Response(text, 200, headers: json);
        }),
        secrets: secrets,
        defaultBaseUrl: base,
      );
}

/// A backend out of reach while [unreachable] is set: every request fails
/// with that exception — dart:io's own — after its delay: at once for a name
/// that does not resolve, after the connect timeout for an address that
/// never answers. While it is not, every answer takes [slow] to come, and
/// each `/grant` is a new grant (`grant-1`, `grant-2`, …) unless [handler]
/// says otherwise.
class _OutOfReachBackend extends TestBackend {
  (SocketException, Duration)? unreachable;
  Duration slow = Duration.zero;
  int _issued = 0;

  @override
  BackendClient client(SecretStore secrets) => BackendClient(
        http: MockClient((request) async {
          final path = request.url.path;
          log.add('${request.method} $path');
          final out = unreachable;
          if (out != null) {
            await Future<void>.delayed(out.$2);
            throw out.$1;
          }
          await Future<void>.delayed(slow);
          final (status, text) = handler(request.method, path, request.body) ??
              switch (path) {
                _ when path.endsWith('/api/companion/grant') =>
                  (200, TestBackend.ok('{"grant":"grant-${++_issued}","expires_at":${TestBackend.epochSeconds() + 3600}}')),
                _ when path.endsWith('/api/companion/config') => (200, TestBackend.ok('{"enabled":true}')),
                _ when path.endsWith('/api/user/auth/refresh') => (200, TestBackend.ok(TestBackend.loginBody(42, 'user42'))),
                _ => (200, TestBackend.ok('[]')),
              };
          return http.Response(text, status, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        secrets: secrets,
        defaultBaseUrl: base,
      );
}

/// The app's grant cache (spec §8): one grant per paired host, used until it
/// expires, given up only when refused — and the backend's word on `/grant`
/// taken as it means it: a limit waited out, remote control off as final.
void main() {
  int grants(TestApp app) => app.backend.log.where((line) => line == 'POST /api/companion/grant').length;

  Future<ClientState?> connection(TestApp app, bool Function(ClientState state) test) async =>
      (await app.controller.states.firstWhere((s) => test(s.connection), timeout: const Duration(minutes: 5)))?.connection;

  /// Every open used to throw the cached grant away, so going back and forth
  /// between the list and a computer spent the account's 20 grants in 20
  /// minutes — and then not even the LAN could be had.
  test('opening a computer again uses the grant it already has', () => runFake((_) async {
        final app = TestApp();
        final a = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        final b = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [
          TestApp.pairedHost(a.hostId, a.hostStatic, 'dev-a', base: app.backend.base),
          TestApp.pairedHost(b.hostId, b.hostStatic, 'dev-b', base: app.backend.base),
        ]);
        final asked = <String>[];
        app.backend.handler = (method, path, body) {
          if (!path.endsWith('/api/companion/grant')) return null;
          final device = (jsonDecode(body) as Map<String, Object?>)['device_id'];
          asked.add('$device');
          return (200, TestBackend.ok('{"grant":"grant-$device-${asked.length}","expires_at":${TestBackend.epochSeconds() + 3600}}'));
        };
        var at = a;
        app.carriers.lan = (_) => at;
        // Signed in for longer than the test: the grants are what expire.
        await app.signIn(accessExpiresAt: clock.now().add(const Duration(hours: 3)).millisecondsSinceEpoch);
        await app.controller.start();

        Future<void> open(FakeHost host) async {
          at = host;
          final connections = host.connections;
          await app.controller.connect(host.hostId);
          await app.controller.states.firstWhere((s) => s.connected && host.connections > connections, timeout: const Duration(minutes: 1));
          await Future<void>.delayed(const Duration(seconds: 20));
          // Back to the list.
          app.controller.disconnect();
        }

        for (var round = 0; round < 3; round++) {
          await open(a);
          await open(b);
        }
        expect(asked, ['dev-a', 'dev-b'], reason: 'one grant per computer, each its own');
        expect(a.helloGrants.toSet(), {'grant-dev-a-1'});
        expect(b.helloGrants.toSet(), {'grant-dev-b-2'});

        // A kick for new scopes gives up that computer's grant, not the other's.
        at = a;
        await app.controller.connect(a.hostId);
        await app.controller.states.firstWhere((s) => s.connected, timeout: const Duration(minutes: 1));
        final connections = a.connections;
        await a.kick('scopes-changed');
        await app.controller.states.firstWhere((s) => s.connected && a.connections > connections, timeout: const Duration(minutes: 1));
        app.controller.disconnect();
        await open(b);
        expect(asked, ['dev-a', 'dev-b', 'dev-a']);
        expect(b.helloGrants.toSet(), {'grant-dev-b-2'});

        // An hour on, they have expired.
        await Future<void>.delayed(const Duration(hours: 1));
        await open(b);
        expect(asked, ['dev-a', 'dev-b', 'dev-a', 'dev-b']);
      }, limit: const Duration(hours: 2)));

  /// A scope widened on the desktop is told only to the devices connected
  /// right then; this phone, at the list, learns of it from its next grant.
  /// A computer opened again 5 minutes or more after its grant was fetched
  /// asks for a new one first — and makes do with the one it has when the
  /// backend cannot give another, but not when it says the pairing is over.
  test('a computer opened again after 5 minutes asks for a new grant first', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
        var issued = 0;
        (int, String) issue() {
          issued += 1;
          return (200, TestBackend.ok('{"grant":"grant-$issued","expires_at":${TestBackend.epochSeconds() + 3600}}'));
        }

        var answer = issue;
        app.backend.handler = (_, path, _) => path.endsWith('/api/companion/grant') ? answer() : null;
        app.carriers.lan = (_) => host;
        // Signed in for longer than the test: the grants are what is looked at.
        await app.signIn(accessExpiresAt: clock.now().add(const Duration(hours: 3)).millisecondsSinceEpoch);
        await app.controller.start();

        Future<void> open() async {
          final connections = host.connections;
          await app.controller.connect(host.hostId);
          await app.controller.states.firstWhere((s) => s.connected && host.connections > connections, timeout: const Duration(minutes: 1));
          app.controller.disconnect();
        }

        await open();
        await Future<void>.delayed(const Duration(minutes: 4));
        await open();
        expect(host.helloGrants, ['grant-1', 'grant-1'], reason: 'a grant this new is kept');

        await Future<void>.delayed(const Duration(minutes: 2));
        await open();
        expect(host.helloGrants.last, 'grant-2', reason: 'the scopes as they are now');
        expect(grants(app), 2);

        // The backend over its limit: the grant in hand serves, at once (out
        // of reach, or slow: see below).
        await Future<void>.delayed(const Duration(minutes: 6));
        answer = () => (429, '');
        final seen = <ClientState>[];
        final watching = app.controller.states.changes.listen((s) => seen.add(s.connection));
        await open();
        // Not awaited: a cancel's future belongs to the root zone, where fake
        // time does not run.
        unawaited(watching.cancel());
        expect(host.helloGrants.last, 'grant-2');
        expect(grants(app), 3);
        expect(seen.whereType<ClientWaiting>(), isEmpty, reason: 'not "no grant, retrying"');

        // The pairing over: not the grant in hand, but the backend's word.
        await Future<void>.delayed(const Duration(minutes: 6));
        answer = () => (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}'));
        final hellos = host.helloGrants.length;
        await app.controller.connect(host.hostId);
        final failed = await connection(app, (c) => c is ClientFailed) as ClientFailed?;
        expect(failed?.code, 'revoked');
        expect(host.helloGrants, hasLength(hellos));
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// The renewal above with the backend out of reach — what LAN mode is for
  /// (spec §8.4). It used to wait the renewal out: a refresh sent again
  /// after 2 s and 5 s however surely it had never left, each send a connect
  /// timeout of 10 s — up to 22 s of "connecting" before the LAN.
  group('a computer opened again with the backend out of reach', () {
    const noName = SocketException("Failed host lookup: 'backend.example'",
        osError: OSError('nodename nor servname provided, or not known', 8));
    const timedOut = SocketException('HTTP connection timed out after 0:00:10.000000, host: backend.example, port: 443');
    for (final (expired, out, within) in [
      (false, (noName, Duration.zero), const Duration(seconds: 1)),
      (true, (noName, Duration.zero), const Duration(seconds: 1)),
      (false, (timedOut, const Duration(seconds: 10)), const Duration(seconds: 4)),
      (true, (timedOut, const Duration(seconds: 10)), const Duration(seconds: 4)),
    ]) {
      final how = out.$2 == Duration.zero ? 'failing at once' : 'connect timing out';
      test('is on the LAN in under ${within.inSeconds} s (${expired ? 'token run out' : 'token good'}, $how)', () => runFake((_) async {
            final backend = _OutOfReachBackend();
            final app = TestApp(backend: backend);
            final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
            await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: backend.base)]);
            app.carriers.lan = (_) => host;
            // Run out by the time the computer is opened again, or good for
            // longer than the test.
            await app.signIn(accessExpiresAt: clock.now().add(expired ? const Duration(minutes: 5) : const Duration(hours: 3)).millisecondsSinceEpoch);
            await app.controller.start();

            Future<Duration> open() async {
              final connections = host.connections;
              final started = clock.now();
              await app.controller.connect(host.hostId);
              await app.controller.states.firstWhere((s) => s.connected && host.connections > connections, timeout: const Duration(minutes: 1));
              final took = clock.now().difference(started);
              app.controller.disconnect();
              return took;
            }

            await open();
            await Future<void>.delayed(const Duration(minutes: 6));
            backend.unreachable = out;
            final seen = <ClientState>[];
            final watching = app.controller.states.changes.listen((s) => seen.add(s.connection));
            expect(await open(), lessThan(within));
            unawaited(watching.cancel());
            expect(host.helloGrants, ['grant-1', 'grant-1']);
            expect(seen.whereType<ClientWaiting>(), isEmpty, reason: 'not "no grant, retrying"');

            // Asked just now: opened again meanwhile, no waiting at all.
            await Future<void>.delayed(const Duration(minutes: 1));
            expect(await open(), lessThan(const Duration(seconds: 1)));
            expect(host.helloGrants, ['grant-1', 'grant-1', 'grant-1']);

            // Back: renewed as before.
            backend.unreachable = null;
            await Future<void>.delayed(const Duration(minutes: 5));
            await open();
            expect(host.helloGrants.last, 'grant-2');
          }, limit: const Duration(hours: 1)));
    }
  });

  /// A backend that answers, but slowly: the open does not wait on it past a
  /// few seconds. What it says then still counts — a new grant from the next
  /// open on, a refusal by ending the one in hand.
  test('a renewal slow to come serves from the next open', () => runFake((_) async {
        final backend = _OutOfReachBackend();
        final app = TestApp(backend: backend);
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: backend.base)]);
        app.carriers.lan = (_) => host;
        await app.signIn(accessExpiresAt: clock.now().add(const Duration(hours: 3)).millisecondsSinceEpoch);
        await app.controller.start();

        Future<Duration> open() async {
          final connections = host.connections;
          final started = clock.now();
          await app.controller.connect(host.hostId);
          await app.controller.states.firstWhere((s) => s.connected && host.connections > connections, timeout: const Duration(minutes: 1));
          final took = clock.now().difference(started);
          app.controller.disconnect();
          return took;
        }

        backend.slow = const Duration(seconds: 5);
        expect(await open(), greaterThanOrEqualTo(const Duration(seconds: 5)), reason: 'none in hand: waited for');
        await Future<void>.delayed(const Duration(minutes: 6));
        expect(await open(), lessThan(const Duration(seconds: 4)));
        expect(host.helloGrants, ['grant-1', 'grant-1']);
        await Future<void>.delayed(const Duration(seconds: 10));
        expect(grants(app), 2);
        expect(await open(), lessThan(const Duration(seconds: 1)));
        expect(host.helloGrants.last, 'grant-2', reason: 'the one that came late');
        expect(grants(app), 2);

        // A refusal that comes late ends the grant in hand: the next open
        // asks, and is told.
        await Future<void>.delayed(const Duration(minutes: 6));
        backend.handler = (_, path, _) =>
            path.endsWith('/api/companion/grant') ? (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}')) : null;
        await open();
        await Future<void>.delayed(const Duration(seconds: 10));
        final hellos = host.helloGrants.length;
        await app.controller.connect(host.hostId);
        final failed = await connection(app, (c) => c is ClientFailed) as ClientFailed?;
        expect(failed?.code, 'revoked');
        expect(host.helloGrants, hasLength(hellos));
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// `/grant` over the per-user limit says when it lifts; asking every 30 s
  /// until then only got 429 after 429.
  for (final (name, body) in [
    ('empty', ''),
    ('with an envelope', '{"success":false,"message":"请求过于频繁，请稍后再试"}'),
  ]) {
    test('a 429 from /grant ($name) is waited out as Retry-After says', () => runFake((_) async {
          final backend = _RateLimitedBackend(body)..limit = const Duration(minutes: 10);
          final app = TestApp(backend: backend);
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
          await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: backend.base)]);
          app.carriers.lan = (_) => host;
          await app.start();
          await app.controller.connect(host.hostId);

          final waiting = await connection(app, (c) => c is ClientWaiting) as ClientWaiting?;
          expect(waiting, isNotNull);
          expect(waiting!.retryIn, greaterThanOrEqualTo(const Duration(minutes: 10)));
          expect(
            waiting.error,
            isA<RcException>()
                .having((e) => e.code, 'code', 'grant')
                .having((e) => e.cause, 'cause', isA<BackendException>().having((e) => e.status, 'status', 429)),
            reason: 'a grant failure, worded once',
          );
          await Future<void>.delayed(const Duration(minutes: 9));
          expect(grants(app), 1);

          backend.limit = null;
          expect(await connection(app, (c) => c is ClientConnected), isNotNull);
          expect(grants(app), 2);
          app.controller.disconnect();
        }, limit: const Duration(hours: 1)));
  }

  group('a refresh that keeps failing', () {
    Future<(TestApp, FakeHost)> opened(_RefreshLimitedBackend backend) async {
      final app = TestApp(backend: backend);
      final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
      await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: backend.base)]);
      app.carriers.lan = (_) => host;
      // The token has run out: /grant needs a refresh first.
      await app.signIn(accessExpiresAt: clock.now().millisecondsSinceEpoch - 1000);
      await app.controller.start();
      await app.controller.connect(host.hostId);
      return (app, host);
    }

    /// Every refresh was sent three times (the resends that keep a rotated
    /// cookie, see backend_client.dart) every half minute: the limit was gone
    /// within ten minutes, and the backend, back, answered 429 for twenty
    /// more. Five sends a refresh now, and a pause after each that ends in a
    /// 5xx — 1 minute, doubling to 5 — keep it to some 30 in 20 minutes; the
    /// backend back is asked again when the pause is over.
    for (final outage in [const Duration(minutes: 10), const Duration(minutes: 20), const Duration(minutes: 30)]) {
      test('${outage.inMinutes} minutes of 500s leave its limit unspent: connected within a pause of the backend', () => runFake((_) async {
            final backend = _RefreshLimitedBackend()..down = true;
            final started = clock.now();
            final (app, _) = await opened(backend);
            await Future<void>.delayed(outage);
            expect(app.controller.state.connection, anyOf(isA<ClientWaiting>(), isA<ClientConnecting>()), reason: 'still trying');
            final first20 = backend.sent.where((at) => at.difference(started) < const Duration(minutes: 20)).length;
            expect(first20, lessThanOrEqualTo(60), reason: 'the 20-minute limit');
            expect(first20, lessThanOrEqualTo(35));
            backend.down = false;
            final back = clock.now();
            expect(await app.controller.states.firstWhere((s) => s.connected, timeout: const Duration(minutes: 30)), isNotNull);
            expect(clock.now().difference(back), lessThan(const Duration(minutes: 5, seconds: 30)));
            expect(backend.answered, isNot(contains(429)));
            expect(app.controller.state.user, isNotNull, reason: 'still signed in');
            app.controller.disconnect();
          }, limit: const Duration(hours: 2)));
    }

    /// The in-memory limiter's Retry-After is its whole window, however
    /// little of it is left; the phone used to wait all of it out.
    test('over its limit, it is asked again within 2 minutes whatever Retry-After says', () => runFake((_) async {
          final backend = _RefreshLimitedBackend()..spend(const Duration(minutes: 5));
          final started = clock.now();
          final (app, _) = await opened(backend);
          final waiting = await connection(app, (c) => c is ClientWaiting) as ClientWaiting?;
          expect(waiting!.error, isA<RcException>().having((e) => e.code, 'code', 'grant'));
          expect(waiting.retryIn, lessThanOrEqualTo(const Duration(minutes: 2)));
          expect(await app.controller.states.firstWhere((s) => s.connected, timeout: const Duration(minutes: 30)), isNotNull);
          expect(clock.now().difference(started), lessThan(const Duration(minutes: 7, seconds: 30)));
          app.controller.disconnect();
        }, limit: const Duration(hours: 1)));
  });

  group('remote control turned off on the server', () {
    Future<TestApp> openWith((int, String)? Function(String path) answer) async {
      final app = TestApp();
      final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
      await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
      app.backend.handler = (_, path, _) => answer(path);
      app.carriers.lan = (_) => host;
      await app.start();
      await app.controller.connect(host.hostId);
      return app;
    }

    test('is final when /grant says COMPANION_DISABLED', () => runFake((_) async {
          final app = await openWith((path) => path.endsWith('/api/companion/grant')
              ? (200, '{"success":false,"message":"远程控制功能未启用","code":"COMPANION_DISABLED"}')
              : null);
          final failed = await connection(app, (c) => c is ClientFailed) as ClientFailed?;
          expect(failed?.code, 'companion-disabled');
          await Future<void>.delayed(const Duration(minutes: 10));
          expect(grants(app), 1, reason: 'not asked again every 30 s');
          expect(app.carriers.opened, isEmpty);
          app.controller.disconnect();
        }));

    /// A backend from before the code answers 200 `success:false` with a
    /// sentence only; `/config` still answers, and says it is off.
    test('is final when an older backend refuses and /config says it is off', () => runFake((_) async {
          final app = await openWith((path) => switch (path) {
                _ when path.endsWith('/api/companion/grant') => (200, TestBackend.fail('远程控制功能未启用')),
                _ when path.endsWith('/api/companion/config') => (200, TestBackend.ok('{"enabled":false}')),
                _ => null,
              });
          final failed = await connection(app, (c) => c is ClientFailed) as ClientFailed?;
          expect(failed?.code, 'companion-disabled');
          await Future<void>.delayed(const Duration(minutes: 10));
          expect(grants(app), 1);
          app.controller.disconnect();
        }));

    test('a refusal while /config says it is on is retried', () => runFake((_) async {
          final app = await openWith((path) => path.endsWith('/api/companion/grant') ? (200, TestBackend.fail('参数错误')) : null);
          final waiting = await connection(app, (c) => c is ClientWaiting) as ClientWaiting?;
          expect(waiting?.error, isA<RcException>().having((e) => e.code, 'code', 'grant'));
          await Future<void>.delayed(const Duration(minutes: 2));
          expect(grants(app), greaterThan(1));
          expect(app.controller.state.connection, isNot(isA<ClientFailed>()));
          app.controller.disconnect();
        }));
  });

  /// Revoked from elsewhere while the phone was away from home, with a grant
  /// still cached: the relay refuses the upgrade (403), `/grant` settles it,
  /// and the phone stays "revoked" — also when the computer is opened again,
  /// now that opening it keeps the cache.
  test('a relay 403 with a grant cached ends in "revoked", and stays there', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
        app.carriers.relay = () => host;
        await app.start();
        await app.controller.connect(host.hostId);
        expect(await connection(app, (c) => c is ClientConnected), isNotNull);
        expect(grants(app), 1);

        app.backend.handler = (_, path, _) =>
            path.endsWith('/api/companion/grant') ? (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}')) : null;
        app.carriers.relayFailure = const CarrierUnavailable('forbidden', detail: 'HTTP/1.1 403 Forbidden');
        await host.drop();
        final failed = await connection(app, (c) => c is ClientFailed) as ClientFailed?;
        expect(failed?.error, isA<RcException>().having((e) => e.code, 'code', 'revoked').having((e) => e.detail, 'detail', 'device'));
        expect(grants(app), 2);

        // Back to the list, and the computer opened again.
        final relayOpens = app.carriers.opened.whereType<RouteRelay>().length;
        app.controller.disconnect();
        await app.controller.connect(host.hostId);
        final again = await connection(app, (c) => c is ClientFailed) as ClientFailed?;
        expect(again?.error, isA<RcException>().having((e) => e.code, 'code', 'revoked'));
        await Future<void>.delayed(const Duration(minutes: 10));
        expect(app.controller.state.connection, isA<ClientFailed>());
        expect(grants(app), 3, reason: 'the backend asked once, not the old grant replayed');
        expect(app.carriers.opened.whereType<RouteRelay>().length, relayOpens, reason: 'the relay is not dialled again');
        app.controller.disconnect();
      }));

  /// The renewal on opening a computer again refused for good: the grant in
  /// hand is not the backend's word, and a retry — the user's, or the app
  /// back in the foreground — does not connect with it.
  for (final (name, answer, code) in [
    ('revoked', (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}')), 'revoked'),
    ('gone', (404, TestBackend.fail('设备不存在')), 'revoked'),
    ('remote control off', (200, '{"success":false,"message":"远程控制功能未启用","code":"COMPANION_DISABLED"}'), 'companion-disabled'),
  ]) {
    test('a renewal refused for good ($name) ends the grant in hand, also on retry', () => runFake((_) async {
          final app = TestApp();
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
          await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
          app.carriers.lan = (_) => host;
          await app.signIn(accessExpiresAt: clock.now().add(const Duration(hours: 3)).millisecondsSinceEpoch);
          await app.controller.start();
          await app.controller.connect(host.hostId);
          expect(await connection(app, (c) => c is ClientConnected), isNotNull);
          app.controller.disconnect();

          await Future<void>.delayed(const Duration(minutes: 6));
          app.backend.handler = (_, path, _) => path.endsWith('/api/companion/grant') ? answer : null;
          await app.controller.connect(host.hostId);
          expect((await connection(app, (c) => c is ClientFailed) as ClientFailed?)?.code, code);
          app.controller.retry();
          await Future<void>.delayed(const Duration(minutes: 1));
          expect(app.controller.state.connection, isA<ClientFailed>().having((f) => f.code, 'code', code));
          expect(host.helloGrants, hasLength(1), reason: 'the refused grant is not tried');
          expect(grants(app), 3, reason: 'the retry asked the backend');
          app.controller.disconnect();
        }, limit: const Duration(hours: 1)));
  }

  /// A relay refusal the backend does not mean about the device (a firewall
  /// in front of `/ws`, say) while `/grant` keeps issuing must not cost a
  /// `/grant` per round, nor per open of the computer: every phone of the
  /// account shares that budget (spec §8.2). The backend is asked once an
  /// outage — a grant it has just issued is that answer — then every 10
  /// minutes; a device revoked after the first ask is still found out.
  test('a relay that keeps refusing has /grant asked once per outage, then every 10 minutes', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        final paired = TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base);
        await TestApp.writePaired(app.files, [paired.copyWith(lanAddrs: const [])]);
        app.carriers
          ..relay = (() => host)
          ..relayFailure = const CarrierUnavailable('forbidden', detail: 'HTTP/1.1 403 Forbidden');
        await app.start();
        final started = clock.now();
        await app.controller.connect(host.hostId);
        await Future<void>.delayed(const Duration(seconds: 40));
        expect(grants(app), 1, reason: 'the grant just issued is the backend’s answer');

        // Back to the list and in again, the outage going on.
        for (var i = 0; i < 4; i++) {
          app.controller.disconnect();
          await Future<void>.delayed(const Duration(seconds: 10));
          await app.controller.connect(host.hostId);
          await Future<void>.delayed(const Duration(seconds: 30));
        }
        expect(app.controller.state.connection, isA<ClientWaiting>());
        expect(app.carriers.opened.whereType<RouteRelay>().length, greaterThan(10));
        expect(grants(app), 1, reason: 'opening it again is no new outage');

        await Future<void>.delayed(const Duration(minutes: 11) - clock.now().difference(started));
        expect(grants(app), 2);
        await Future<void>.delayed(const Duration(minutes: 5));
        expect(grants(app), 2);

        // Up again, then refused again: a new outage, asked about at once.
        app.carriers.relayFailure = null;
        expect(await connection(app, (c) => c is ClientConnected), isNotNull);
        app.carriers.relayFailure = const CarrierUnavailable('not-found', detail: 'HTTP/1.1 404 Not Found');
        await host.drop();
        await Future<void>.delayed(const Duration(seconds: 10));
        expect(grants(app), 3);
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  test('a revoke after a relay refusal that was not about the device is found out within 10 minutes', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        final paired = TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base);
        await TestApp.writePaired(app.files, [paired.copyWith(lanAddrs: const [])]);
        app.carriers.relayFailure = const CarrierUnavailable('forbidden', detail: 'HTTP/1.1 403 Forbidden');
        await app.start();
        await app.controller.connect(host.hostId);
        await until(() => grants(app) == 1);
        app.backend.handler = (_, path, _) =>
            path.endsWith('/api/companion/grant') ? (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}')) : null;
        final failed = await app.controller.states.firstWhere((s) => s.connection is ClientFailed, timeout: const Duration(minutes: 11));
        expect((failed?.connection as ClientFailed?)?.code, 'revoked');
        expect(grants(app), 2);
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// The host refusing the grant in hand had a fresh one fetched; that ask is
  /// counted apart from the relay's (spec §10.2). A device revoked after it
  /// is asked about as soon as the relay refuses, not 10 minutes on.
  test('a revoke after the host refused a grant is found out at once', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        final paired = TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base);
        await TestApp.writePaired(app.files, [paired.copyWith(lanAddrs: const [])]);
        app.carriers.relay = () => host;
        await app.start();
        await app.controller.connect(host.hostId);
        expect(await connection(app, (c) => c is ClientConnected), isNotNull);

        // The desktop's device list out of date, say: it refuses every grant.
        host.acceptGrant = (_) => false;
        await host.drop();
        await until(() => grants(app) == 2 && host.helloGrants.length >= 4);
        app.backend.handler = (_, path, _) =>
            path.endsWith('/api/companion/grant') ? (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}')) : null;
        app.carriers.relayFailure = const CarrierUnavailable('forbidden', detail: 'HTTP/1.1 403 Forbidden');
        final failed = await app.controller.states.firstWhere((s) => s.connection is ClientFailed, timeout: const Duration(minutes: 2));
        expect((failed?.connection as ClientFailed?)?.code, 'revoked');
        expect(grants(app), 3);
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// The host refusing every grant — its device list out of date, say: one
  /// fresh grant per outage (spec §10.2). Going back to the list and opening
  /// the computer again is the same outage, as it is for the relay's
  /// refusals; it used to fetch another grant on every open.
  test('a host refusing grants has one fetched per outage, however often the computer is opened', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        final paired = TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base);
        await TestApp.writePaired(app.files, [paired.copyWith(lanAddrs: const [])]);
        app.carriers.relay = () => host;
        await app.start();
        await app.controller.connect(host.hostId);
        expect(await connection(app, (c) => c is ClientConnected), isNotNull);
        expect(grants(app), 1);

        host.acceptGrant = (_) => false;
        await host.drop();
        await until(() => grants(app) == 2 && host.helloGrants.length >= 4);
        for (var i = 0; i < 4; i++) {
          app.controller.disconnect();
          await Future<void>.delayed(const Duration(seconds: 10));
          await app.controller.connect(host.hostId);
          await Future<void>.delayed(const Duration(seconds: 30));
        }
        expect(grants(app), 2, reason: 'opening it again is no new outage');

        // Up again, then refused again: a new outage, one more.
        host.acceptGrant = (_) => true;
        expect(await connection(app, (c) => c is ClientConnected), isNotNull);
        host.acceptGrant = (_) => false;
        await host.drop();
        await until(() => grants(app) == 3);
        await Future<void>.delayed(const Duration(minutes: 2));
        expect(grants(app), 3);
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// Signed out and in again, the account's grants start over, and so does
  /// the one fresh grant a host refusing them gets.
  test('after signing out and in, a host refusing the grant has a fresh one fetched again', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        final paired = TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base);
        await TestApp.writePaired(app.files, [paired.copyWith(lanAddrs: const [])]);
        app.carriers.relay = () => host;
        host.acceptGrant = (_) => false;
        await app.start();
        await app.controller.connect(host.hostId);
        await until(() => grants(app) == 2 && host.helloGrants.length >= 3);

        await app.controller.logout();
        app.backend.handler = (method, path, _) =>
            path.endsWith('/api/user/login') && method == 'POST' ? (200, TestBackend.ok(TestBackend.loginBody(42, 'user42'))) : null;
        await app.controller.login(app.backend.base, 'user42', 'pass');
        await app.controller.connect(host.hostId);
        await until(() => grants(app) == 4);
        await Future<void>.delayed(const Duration(minutes: 2));
        expect(grants(app), 4, reason: 'one for the open, one fresh after the refusal');
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// A firewall in front of the backend refusing everything — the relay's
  /// upgrade (403) and `/grant` (its own page, or a 429) alike. The grant in
  /// hand says nothing was refused that it stands for: it is kept, and back
  /// home the LAN lives on it until it expires (spec §8.4).
  for (final (name, status, body) in [('a firewall page', 403, '<html>Access denied</html>'), ('a 429', 429, '')]) {
    test('relay and /grant refused by $name: the grant in hand still serves the LAN', () => runFake((_) async {
          final app = TestApp();
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
          await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
          // Away from home: the LAN address answers nothing.
          app.carriers
            ..blackhole = {'192.168.1.20'}
            ..lan = ((_) => host)
            ..relay = () => host;
          await app.start();
          await app.controller.connect(host.hostId);
          expect(await connection(app, (c) => c is ClientConnected), isNotNull);

          app.backend.handler = (_, path, _) => path.endsWith('/api/companion/grant') ? (status, body) : null;
          app.carriers.relayFailure = const CarrierUnavailable('forbidden', detail: 'HTTP/1.1 403 Forbidden');
          await host.drop();
          await Future<void>.delayed(const Duration(minutes: 3));
          expect(grants(app), 2, reason: 'asked once, and not every round');
          expect(app.controller.state.connection, anyOf(isA<ClientWaiting>(), isA<ClientConnecting>()));

          // Home.
          app.carriers.blackhole = {};
          app.controller.networkChanged();
          final home = await connection(app, (c) => c is ClientConnected) as ClientConnected?;
          expect(home?.route, isA<RouteLan>());
          expect(host.helloGrants.toSet(), {'grant-token'});
          expect(grants(app), 2);
          app.controller.disconnect();
        }, limit: const Duration(hours: 1)));
  }
}
