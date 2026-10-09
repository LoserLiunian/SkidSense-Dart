import 'dart:async';
import 'dart:io' show HttpDate, OSError, SocketException;
import 'dart:math' show min;

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/src/api/backend_client.dart';
import 'package:skidsense_core/src/store/stores.dart';
import 'package:test/test.dart';

import '../support/fake_time.dart';

/// The session behind every authenticated call: what a refresh that fails
/// means, the rotated cookie surviving a lost answer or a failing keystore,
/// an invalidation racing a refresh, the deadline over a whole exchange, a
/// phone clock that is off, and the `Origin` the cookie endpoints need.
void main() {
  const base = 'https://backend.example';

  String ok(String data) => '{"success":true,"message":"","data":$data}';
  int seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

  /// A login or refresh answer: [token] for 15 minutes on the server's clock.
  http.Response session(String token, String cookie, {DateTime? server, bool date = false}) {
    final now = server ?? clock.now();
    return http.Response(
      ok('{"access_token":"$token","access_expires_at":${seconds(now) + 900},"user":{"id":42,"username":"liunian"},"session":{"id":"sess-1"}}'),
      200,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'set-cookie': 'new_api_refresh=$cookie; Path=/api/user/auth; HttpOnly',
        if (date) 'date': HttpDate.format(now),
      },
    );
  }

  http.Response json(int status, String body, [Map<String, String> headers = const {}]) =>
      http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8', ...headers});

  bool isRefresh(http.BaseRequest request) => request.url.path.endsWith('/api/user/auth/refresh');

  /// Signed in as `tok-1` with cookie `c1`, then [refresh] answers refreshes.
  Future<(BackendClient, List<http.Request>)> signedIn(
    FutureOr<http.Response> Function(http.Request request) refresh, {
    SecretStore? secrets,
    FutureOr<http.Response> Function(http.Request request)? other,
  }) async {
    final requests = <http.Request>[];
    final backend = BackendClient(
      http: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('encryption-key')) return json(200, ok('{"enabled":false}'));
        if (path.endsWith('/api/user/login')) return session('tok-1', 'c1');
        if (isRefresh(request)) return refresh(request);
        return other?.call(request) ?? json(200, ok('[]'));
      }),
      secrets: secrets ?? MemorySecretStore(),
      defaultBaseUrl: base,
    );
    await backend.login(base, 'u', 'p');
    return (backend, requests);
  }

  group('a refresh that fails without a refusal is not a sign-out', () {
    test('no answer: the calls say the server is unreachable, and the session stays', () {
      runFake((_) async {
        final (backend, _) = await signedIn((_) => throw http.ClientException('Connection reset by peer'));
        await backend.invalidateAccessToken();
        await expectLater(backend.hosts(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
        expect(backend.session.value?.refreshCookie, 'c1', reason: 'still signed in');
      });
    });

    test('a 5xx or a 429 keeps its own code, and the session', () {
      runFake((_) async {
        var status = 500;
        final (backend, _) = await signedIn((_) => status == 500
            ? json(500, '{"success":false,"code":"AUTH_INTERNAL_ERROR","message":"Internal Server Error"}')
            : http.Response('', 429, headers: {'retry-after': '120'}));
        await backend.invalidateAccessToken();
        await expectLater(
          backend.hosts(),
          throwsA(isA<BackendException>().having((e) => e.status, 'status', 500).having((e) => e.code, 'code', isNot('session-expired'))),
        );
        // Past the pause a 5xx earns (see below).
        await Future<void>.delayed(const Duration(minutes: 1));
        status = 429;
        await expectLater(
          backend.hosts(),
          throwsA(isA<BackendException>().having((e) => e.code, 'code', 'http').having((e) => e.status, 'status', 429)),
        );
        expect(backend.session.value, isNotNull);
      });
    });

    /// Every send counts against the session's refresh limit (60 in 20
    /// minutes), a 500 too: three every half minute spent it within ten
    /// minutes of a failing backend, and then its 429 kept the phone out. A
    /// refresh that ends in a 5xx, its resends and all, is followed by none
    /// for a minute — then two, four, five, while they keep ending so.
    test('after a 5xx, no refresh is sent for a minute, then for longer; the failure says how long is left', () {
      runFake((_) async {
        var status = 500;
        final sent = <Duration>[];
        final started = clock.now();
        final (backend, requests) = await signedIn((_) {
          sent.add(clock.now().difference(started));
          return switch (status) {
            200 => session('tok-2', 'c2'),
            429 => http.Response('', 429, headers: {'retry-after': '1200'}),
            _ => json(status, '{"success":false,"code":"AUTH_INTERNAL_ERROR","message":"Internal Server Error"}'),
          };
        });
        await backend.invalidateAccessToken();
        await expectLater(
          backend.accessToken(),
          throwsA(isA<BackendException>()
              .having((e) => e.status, 'status', 500)
              .having((e) => e.fromRefresh, 'fromRefresh', isTrue)
              .having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 1))),
        );
        expect(sent, [for (final s in [0, 2, 7, 15, 24]) Duration(seconds: s)], reason: 'sent again inside the replay window');

        await Future<void>.delayed(const Duration(seconds: 20));
        await expectLater(
          backend.hosts(),
          throwsA(isA<BackendException>()
              .having((e) => e.status, 'status', 500)
              .having((e) => e.fromRefresh, 'fromRefresh', isTrue)
              .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 40))),
        );
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>()));
        expect(sent, hasLength(5), reason: 'not sent while the pause lasts');
        expect(backend.session.value?.refreshCookie, 'c1', reason: 'still signed in');

        var left = const Duration(seconds: 40);
        for (final pause in const [Duration(minutes: 2), Duration(minutes: 4), Duration(minutes: 5), Duration(minutes: 5)]) {
          await Future<void>.delayed(left);
          await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.retryAfter, 'retryAfter', pause)));
          left = pause;
        }
        expect(sent, hasLength(25));

        await Future<void>.delayed(left);
        status = 200;
        expect(await backend.accessToken(), 'tok-2');
        expect(sent, hasLength(26));

        // A 429 is no reason to pause: a refused refresh is not counted, and
        // its Retry-After is the caller's to keep.
        await backend.invalidateAccessToken();
        status = 429;
        for (var i = 0; i < 2; i++) {
          await expectLater(
            backend.accessToken(),
            throwsA(isA<BackendException>()
                .having((e) => e.status, 'status', 429)
                .having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 20))),
          );
        }
        expect(sent, hasLength(28));

        // An answer that settled something: the next 5xx pauses for a minute again.
        status = 500;
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 1))));
      }, limit: const Duration(hours: 1));
    });

    /// Only a 5xx starts or lengthens the pause, and only an answer that
    /// settles something ends it: no answer and a 429 do neither (spec §12).
    test('no answer and a 429 neither pause the refresh nor end a pause', () {
      runFake((_) async {
        var play = '500';
        var sends = 0;
        final (backend, _) = await signedIn((_) {
          sends++;
          return switch (play) {
            '429' => http.Response('', 429, headers: {'retry-after': '30'}),
            'none' => throw http.ClientException('Connection reset by peer'),
            _ => json(500, '{"success":false,"code":"AUTH_INTERNAL_ERROR","message":"Internal Server Error"}'),
          };
        });
        Matcher pausedFor(Duration pause) => throwsA(isA<BackendException>().having((e) => e.retryAfter, 'retryAfter', pause));

        await backend.invalidateAccessToken();
        await expectLater(backend.accessToken(), pausedFor(const Duration(minutes: 1)));
        await Future<void>.delayed(const Duration(minutes: 1));

        // No answer: the resends run their course, and nothing is paused.
        play = 'none';
        sends = 0;
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
        expect(sends, 5);
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
        expect(sends, 10, reason: 'sent at once again: no pause after no answer');

        // A 429: thrown as it came, not paused.
        play = '429';
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.status, 'status', 429)));
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.status, 'status', 429)));
        expect(sends, 12);

        // Neither ended the pause before: the next 5xx doubles it.
        play = '500';
        await expectLater(backend.accessToken(), pausedFor(const Duration(minutes: 2)));
      }, limit: const Duration(hours: 1));
    });

    /// The pause is the session's: signed out and in again — on that server
    /// or another — the new session refreshes at once.
    test('a pause after a 5xx is not the next session’s', () {
      runFake((_) async {
        var down = true;
        final sent = <String>[];
        final backend = BackendClient(
          http: MockClient((request) async {
            final path = request.url.path;
            final server = request.url.host;
            if (path.endsWith('encryption-key')) return json(200, ok('{"enabled":false}'));
            if (path.endsWith('/api/user/login')) return session('tok-$server', 'c-$server-${sent.length}');
            if (path.endsWith('/api/user/auth/logout')) return json(200, ok('null'));
            if (isRefresh(request)) {
              sent.add(server);
              if (server == 'a.example' && down) {
                return json(500, '{"success":false,"code":"AUTH_INTERNAL_ERROR","message":"Internal Server Error"}');
              }
              return session('fresh-$server', 'c-new-${sent.length}');
            }
            return json(200, ok('[]'));
          }),
          secrets: MemorySecretStore(),
        );
        await backend.login('https://a.example', 'u', 'p');
        await backend.invalidateAccessToken();
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 1))));
        expect(sent, hasLength(5));

        down = false;
        for (final server in ['a.example', 'b.example']) {
          await backend.logout();
          await backend.login('https://$server', 'u', 'p');
          await backend.invalidateAccessToken(); // the relay said 401, say
          expect(await backend.accessToken(), 'fresh-$server');
        }
        expect(sent, hasLength(7));
      });
    });

    /// A refresh race is a 409 to ride out: the session stays (spec §12),
    /// as on the desktop.
    test('a 409 AUTH_REFRESH_RACE is not a sign-out', () async {
      final secrets = MemorySecretStore();
      final (backend, requests) =
          await signedIn((_) => json(409, '{"success":false,"code":"AUTH_REFRESH_RACE","message":"Conflict"}'), secrets: secrets);
      await backend.invalidateAccessToken();
      await expectLater(
        backend.accessToken(),
        throwsA(isA<BackendException>().having((e) => e.status, 'status', 409).having((e) => e.fromRefresh, 'fromRefresh', isTrue)),
      );
      expect(requests.where(isRefresh), hasLength(1), reason: 'an answer, not sent again');
      expect(backend.session.value?.refreshCookie, 'c1');
      expect(await secrets.getString('auth-session'), isNotNull);
    });

    /// The cookie belongs to another login than the session id sent with it:
    /// the pair gets the same 409 however often it is sent, so it ends the
    /// session as a refused cookie does (spec §12), as on the desktop.
    test('a 409 AUTH_SESSION_MISMATCH is a sign-out', () async {
      final secrets = MemorySecretStore();
      final (backend, requests) =
          await signedIn((_) => json(409, '{"success":false,"code":"AUTH_SESSION_MISMATCH","message":"Conflict"}'), secrets: secrets);
      await backend.invalidateAccessToken();
      expect(await backend.accessToken(), isNull);
      expect(requests.where(isRefresh), hasLength(1));
      await expectLater(backend.hosts(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'not-signed-in')));
      expect(backend.session.value, isNull);
      expect(await secrets.getString('auth-session'), isNull);
    });

    test('a refused refresh token (401 or 403) is a sign-out', () async {
      for (final status in [401, 403]) {
        final secrets = MemorySecretStore();
        final (backend, _) = await signedIn((_) => json(status, '{"success":false,"code":"AUTH_SESSION_REVOKED","message":"Unauthorized"}'),
            secrets: secrets);
        await backend.invalidateAccessToken();
        expect(await backend.accessToken(), isNull, reason: '$status');
        await expectLater(backend.hosts(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'not-signed-in')));
        expect(backend.session.value, isNull);
        expect(await secrets.getString('auth-session'), isNull);
      }
    });
  });

  group('the rotated cookie', () {
    test('an answer lost after the server rotated is asked for again inside the 30 s replay window', () {
      runFake((_) async {
        // The server's side (service/auth_session.go): each refresh rotates
        // the cookie; the old one is taken back — for the same new one —
        // for 30 s, and after that it is reuse, which revokes the session.
        var current = 'c1';
        String? previous;
        DateTime? previousUntil;
        var rotations = 0;
        var lose = true;
        final (backend, requests) = await signedIn((request) {
          final sent = request.headers['Cookie']?.split('=').last;
          if (sent == previous && previousUntil != null) {
            if (clock.now().isAfter(previousUntil!)) return json(401, '{"success":false,"code":"AUTH_SESSION_REVOKED"}');
            return session('fresh-$rotations', current);
          }
          if (sent != current) return json(401, '{"success":false,"code":"AUTH_UNAUTHORIZED"}');
          previous = current;
          previousUntil = clock.now().add(const Duration(seconds: 30));
          rotations += 1;
          current = 'c${rotations + 1}';
          if (lose) {
            lose = false;
            throw http.ClientException('Connection closed before full header was received');
          }
          return session('fresh-$rotations', current);
        });
        await backend.invalidateAccessToken();
        final started = clock.now();
        expect(await backend.accessToken(), 'fresh-1');
        expect(backend.session.value?.refreshCookie, 'c2');
        expect(clock.now().difference(started), lessThan(const Duration(seconds: 30)));
        expect(requests.where(isRefresh), hasLength(2));

        // And the session goes on with the new cookie.
        await backend.invalidateAccessToken();
        expect(await backend.accessToken(), 'fresh-2');
        expect(backend.session.value?.refreshCookie, 'c3');
      });
    });

    /// A backend restarting behind its proxy: the first send rotated the
    /// cookie and its answer became the proxy's 502, as does every send for
    /// the next 12 or 20 s. The old cookie, sent again once the backend is
    /// back, is still inside the server's 30 s window. Sent again only after
    /// a minute's pause, it was reuse, and reuse revoked the session.
    for (final down in [const Duration(seconds: 12), const Duration(seconds: 20)]) {
      test('a rotation whose answer was lost to ${down.inSeconds} s of 502s keeps the session', () {
        runFake((_) async {
          var current = 'c1';
          String? previous;
          DateTime? previousUntil;
          DateTime? downUntil;
          var rotations = 0;
          final (backend, _) = await signedIn((request) {
            final now = clock.now();
            final gateway = json(502, '<html><body>502 Bad Gateway</body></html>');
            if (downUntil != null && now.isBefore(downUntil!)) return gateway;
            final sent = request.headers['Cookie']?.split('=').last;
            if (sent == previous && previousUntil != null) {
              if (now.isAfter(previousUntil!)) return json(401, '{"success":false,"code":"AUTH_SESSION_REVOKED"}');
              return session('fresh-$rotations', current);
            }
            if (sent != current) return json(401, '{"success":false,"code":"AUTH_UNAUTHORIZED"}');
            previous = current;
            previousUntil = now.add(const Duration(seconds: 30));
            rotations += 1;
            current = 'c${rotations + 1}';
            if (downUntil == null) {
              downUntil = now.add(down);
              return gateway;
            }
            return session('fresh-$rotations', current);
          });
          await backend.invalidateAccessToken();
          expect(await backend.accessToken(), 'fresh-1');
          expect(backend.session.value?.refreshCookie, 'c2');
          expect(rotations, 1, reason: 'the old cookie taken back, not reused');
        });
      });
    }

    test('the retries stay inside the window, and then the failure is reported', () {
      runFake((_) async {
        final sent = <DateTime>[];
        final (backend, _) = await signedIn((_) {
          sent.add(clock.now());
          throw http.ClientException('Network is unreachable');
        });
        await backend.invalidateAccessToken();
        await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
        expect(sent.length, greaterThan(1));
        expect(sent.last.difference(sent.first), lessThan(const Duration(seconds: 30)));
      });
    });

    /// The app frozen while a resend waits — sent to the background, the
    /// phone asleep — wakes past the window. The overdue resend still goes:
    /// a cookie the server rotated is reuse whenever it is sent, so holding
    /// it back saves nothing, and one it did not rotate is taken at once. The
    /// sends that were due later are not made up for.
    test('a resend that wakes late is sent once, and no more', () {
      fakeAsync((time) {
        final sent = <Duration>[];
        final t0 = clock.now();
        var down = true;
        Object? outcome;
        signedIn((_) {
          sent.add(clock.now().difference(t0));
          return down ? json(502, '<html>502 Bad Gateway</html>') : session('tok-2', 'c2');
        }).then((signed) async {
          final (backend, _) = signed;
          await backend.invalidateAccessToken();
          try {
            outcome = await backend.accessToken();
          } catch (error) {
            outcome = error;
          }
        });
        time.elapse(const Duration(milliseconds: 100));
        expect(sent, hasLength(1));
        // Frozen for a minute; the backend is back meanwhile.
        time.elapseBlocking(const Duration(minutes: 1));
        down = false;
        time.elapse(const Duration(minutes: 3));
        expect(sent, hasLength(2), reason: 'the overdue resend, and none of the later ones');
        expect(outcome, 'tok-2', reason: 'not rotated: taken at once, not after a pause');
      });
    });

    /// dart:io's failures from before the request is written: the server got
    /// nothing and rotated nothing, and the resends only held up whoever
    /// waited on the refresh — 7 s with the backend out of reach.
    test('a first send that surely never left is not sent again', () {
      runFake((_) async {
        for (final failure in [
          const SocketException("Failed host lookup: 'backend.example'",
              osError: OSError('nodename nor servname provided, or not known', 8)),
          const SocketException('HTTP connection timed out after 0:00:10.000000, host: backend.example, port: 443'),
          const SocketException('Connection refused', osError: OSError('Connection refused', 61)),
          const SocketException('Connection refused', osError: OSError('Connection refused', 111)),
          const SocketException('Connection failed', osError: OSError('Network is unreachable', 101)),
          const OSError('Connection refused', 111),
        ]) {
          final sent = <DateTime>[];
          final (backend, _) = await signedIn((_) {
            sent.add(clock.now());
            throw failure;
          });
          await backend.invalidateAccessToken();
          final started = clock.now();
          await expectLater(
            backend.accessToken(),
            throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable').having((e) => e.fromRefresh, 'fromRefresh', isTrue)),
          );
          expect(sent, hasLength(1), reason: '$failure');
          expect(clock.now().difference(started), Duration.zero);
          expect(backend.session.value?.refreshCookie, 'c1', reason: 'still signed in');
        }
      });
    });

    test('one that may have left is sent again, and so is a later one that never did', () {
      runFake((_) async {
        for (final failures in [
          // Up, and then gone: reset in the TLS handshake, a write that failed.
          [const SocketException('Connection reset by peer', osError: OSError('Connection reset by peer', 54))],
          [const SocketException('Write failed', osError: OSError('Broken pipe', 32))],
          [http.ClientException('Connection closed before full header was received'), const SocketException('Connection refused', osError: OSError('Connection refused', 61))],
        ]) {
          var sent = 0;
          final (backend, _) = await signedIn((_) => throw failures[min(sent++, failures.length - 1)]);
          await backend.invalidateAccessToken();
          await expectLater(backend.accessToken(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
          expect(sent, 5, reason: '${failures.first}');
        }
      });
    });

    test('a keystore that fails to write does not lose the rotated cookie', () async {
      final secrets = _FlakySecretStore();
      var rotations = 0;
      final (backend, requests) = await signedIn((_) {
        rotations += 1;
        return session('tok-${rotations + 1}', 'c${rotations + 1}');
      }, secrets: secrets);
      secrets.failWrites = true;
      await backend.invalidateAccessToken();
      expect(await backend.accessToken(), 'tok-2');
      expect(backend.session.value?.refreshCookie, 'c2');

      await backend.invalidateAccessToken();
      expect(await backend.accessToken(), 'tok-3');
      expect(requests.where(isRefresh).last.headers['Cookie'], 'new_api_refresh=c2', reason: 'not the rotated-away c1');
    });

    /// The keystore failing once, as the refresh wrote the rotated cookie:
    /// the write is made again shortly, not left for the next refresh some
    /// 14 minutes on. A process killed before then came back with the
    /// rotated-away cookie, which the server, past its 30 s window, takes for
    /// reuse — and revokes the session for.
    test('a keystore write that failed is made again shortly', () => runFake((_) async {
          final secrets = _FlakySecretStore();
          final (backend, _) = await signedIn((_) => session('tok-2', 'c2'), secrets: secrets);
          await backend.invalidateAccessToken();
          secrets.failNext = 1;
          expect(await backend.accessToken(), 'tok-2');
          await Future<void>.delayed(const Duration(seconds: 30));

          // The process killed in the background, and started again.
          final restarted = BackendClient(http: MockClient((_) async => json(500, '')), secrets: secrets, defaultBaseUrl: base);
          await restarted.restore();
          expect(restarted.session.value?.refreshCookie, 'c2');
          expect(restarted.session.value?.accessToken, 'tok-2');
        }));

    /// The keystore failing for long (locked, full) as the refresh wrote the
    /// rotated cookie: the write is made again until it lands, not given up
    /// after a minute — a process killed after that came back with the old
    /// cookie, which the server took for reuse.
    test('a keystore that keeps failing gets the rotated cookie once it works', () => runFake((_) async {
          final secrets = _FlakySecretStore();
          final (backend, _) = await signedIn((_) => session('tok-2', 'c2'), secrets: secrets);
          await backend.invalidateAccessToken();
          secrets.failNext = 12;
          expect(await backend.accessToken(), 'tok-2');
          await Future<void>.delayed(const Duration(minutes: 40));
          expect(secrets.failNext, 0);

          final restarted = BackendClient(http: MockClient((_) async => json(500, '')), secrets: secrets, defaultBaseUrl: base);
          await restarted.restore();
          expect(restarted.session.value?.refreshCookie, 'c2');
        }, limit: const Duration(hours: 1)));

    /// One write being made again at a time, of the latest session: a later
    /// save takes over, and a sign-out ends it.
    test('the retries are one, until the write lands or the session is gone', () => runFake((_) async {
          final secrets = _FlakySecretStore();
          var rotations = 0;
          final (backend, _) = await signedIn((_) {
            rotations += 1;
            return session('tok-${rotations + 1}', 'c${rotations + 1}');
          }, secrets: secrets);
          secrets.failWrites = true;
          for (var i = 0; i < 3; i++) {
            await backend.invalidateAccessToken();
            await backend.accessToken();
            await Future<void>.delayed(const Duration(minutes: 1));
          }
          // An hour on, a write every 5 minutes: one chain of retries, not six.
          await Future<void>.delayed(const Duration(hours: 1));
          final puts = secrets.puts;
          await Future<void>.delayed(const Duration(minutes: 30));
          expect(secrets.puts - puts, inInclusiveRange(5, 7));

          secrets.failWrites = false;
          await Future<void>.delayed(const Duration(minutes: 5));
          expect(await secrets.getString('auth-session'), contains('"refreshCookie":"c4"'));
          final landed = secrets.puts;
          await Future<void>.delayed(const Duration(minutes: 30));
          expect(secrets.puts, landed, reason: 'landed: nothing more to write');

          secrets.failWrites = true;
          await backend.invalidateAccessToken();
          await backend.logout();
          final signedOut = secrets.puts;
          await Future<void>.delayed(const Duration(minutes: 30));
          expect(secrets.puts, signedOut, reason: 'signed out: nothing more to write');
          expect(secrets.holdsSession, isFalse);
        }, limit: const Duration(hours: 3)));

    test('an invalidation during the slow keystore write of a refresh does not bring the old cookie back', () async {
      final secrets = _GatedSecretStore();
      final (backend, _) = await signedIn((_) => session('tok-2', 'c2'), secrets: secrets);
      await backend.invalidateAccessToken();

      secrets.gate = (value) => value.contains('tok-2');
      final refreshed = backend.accessToken();
      await secrets.held.future; // the refresh is writing c2 to the keystore
      final invalidated = backend.invalidateAccessToken(); // e.g. the relay said 401
      secrets.release();
      await refreshed;
      await invalidated;

      expect(backend.session.value?.refreshCookie, 'c2');
      expect(await secrets.getString('auth-session'), allOf(contains('"refreshCookie":"c2"'), isNot(contains('"c1"'))));
    });

    test('a sign-out is off the keystore before the session turns null', () async {
      // The app tells a sign-out it asked for from one the server forced by
      // whether it still shows a user when the session goes.
      for (final refused in [false, true]) {
        final secrets = _FlakySecretStore();
        final (backend, _) = await signedIn((_) => json(401, '{"success":false,"code":"AUTH_SESSION_REVOKED"}'), secrets: secrets);
        bool? storedWhenGone;
        final watch = backend.session.changes.listen((session) {
          if (session == null) storedWhenGone = secrets.holdsSession;
        });
        if (refused) {
          await backend.invalidateAccessToken();
          expect(await backend.accessToken(), isNull);
        } else {
          await backend.logout();
        }
        await pumpEventQueue();
        await watch.cancel();
        expect(storedWhenGone, isFalse, reason: refused ? 'refused refresh' : 'logout');
      }
    });

    test('a 401 for a token a refresh has already replaced does not throw the new one away', () async {
      var refreshes = 0;
      final (backend, _) = await signedIn((_) {
        refreshes += 1;
        return session('tok-${refreshes + 1}', 'c${refreshes + 1}');
      });
      await backend.invalidateAccessToken();
      expect(await backend.accessToken(), 'tok-2');
      await backend.invalidateAccessToken('tok-1'); // a late 401 for the old token
      expect(await backend.accessToken(), 'tok-2');
      expect(refreshes, 1);
      await backend.invalidateAccessToken('tok-2');
      expect(await backend.accessToken(), 'tok-3');
    });
  });

  test("a failure carries the envelope's code and the Retry-After", () async {
    var reply = http.Response('', 429, headers: {'retry-after': '42'});
    final backend = BackendClient(http: MockClient((_) async => reply), secrets: MemorySecretStore());
    await expectLater(
      backend.status(base),
      throwsA(isA<BackendException>()
          .having((e) => e.code, 'code', 'http')
          .having((e) => e.status, 'status', 429)
          .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42))),
    );
    reply = json(200, '{"success":false,"message":"伺服器未啟用遠端控制","code":"COMPANION_DISABLED"}');
    await expectLater(
      backend.status(base),
      throwsA(isA<BackendException>()
          .having((e) => e.code, 'code', 'server')
          .having((e) => e.errorCode, 'errorCode', 'COMPANION_DISABLED')
          .having((e) => e.message, 'message', '伺服器未啟用遠端控制')
          .having((e) => e.retryAfter, 'retryAfter', isNull)),
    );
    reply = json(503, '{"success":false,"message":"","code":"AUTH_INTERNAL_ERROR"}', {'retry-after': 'soon'});
    await expectLater(
      backend.status(base),
      throwsA(isA<BackendException>()
          .having((e) => e.code, 'code', 'http')
          .having((e) => e.errorCode, 'errorCode', 'AUTH_INTERNAL_ERROR')
          .having((e) => e.retryAfter, 'retryAfter', isNull)),
    );
  });

  test('the relay path is fetched once per server; a failure or a hang is not kept', () {
    runFake((_) async {
      var configs = 0;
      var mode = 'fail';
      final (backend, _) = await signedIn((_) => session('tok-2', 'c2'), other: (request) {
        if (!request.url.path.endsWith('/api/companion/config')) return json(200, ok('[]'));
        configs += 1;
        return switch (mode) {
          'fail' => throw http.ClientException('Connection refused'),
          'hang' => Completer<http.Response>().future,
          _ => json(200, ok('{"enabled":true,"ws_path":"/relay/ws"}')),
        };
      });
      expect(await backend.relayPath(), isNull, reason: 'the default path meanwhile');
      mode = 'hang';
      final started = clock.now();
      expect(await backend.relayPath(), isNull);
      expect(clock.now().difference(started), lessThan(const Duration(seconds: 15)));
      mode = 'ok';
      expect(await backend.relayPath(), '/relay/ws');
      expect(await backend.relayPath(), '/relay/ws');
      expect(configs, 3, reason: 'asked again after the failure and the hang, then kept');
    });
  });

  group('one deadline over the whole exchange', () {
    test('a server that accepts and never answers fails in 20 s, and the request is aborted', () {
      runFake((_) async {
        final hanging = _SilentClient();
        final backend = BackendClient(http: hanging, secrets: MemorySecretStore());
        final started = clock.now();
        await expectLater(backend.status(base), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable')));
        expect(clock.now().difference(started).inMilliseconds, inInclusiveRange(20000, 21000));
        final request = hanging.requests.single;
        expect(request, isA<http.Abortable>());
        var aborted = false;
        unawaited((request as http.Abortable).abortTrigger?.then((_) => aborted = true));
        await Future<void>.delayed(Duration.zero);
        expect(aborted, isTrue, reason: 'the socket is torn down, not left open');
      }, limit: const Duration(minutes: 2));
    });

    /// Each send given up on after 20 s: the points it was still out at are
    /// skipped, not made up for with a burst of sends as it fails.
    test('a refresh that never answers releases everyone waiting on it', () {
      runFake((_) async {
        final sent = <Duration>[];
        late final DateTime started;
        final (backend, _) = await signedIn((_) {
          sent.add(clock.now().difference(started));
          return Completer<http.Response>().future;
        });
        await backend.invalidateAccessToken();
        started = clock.now();
        await Future.wait([
          for (final call in [backend.accessToken(), backend.accessToken(), backend.hosts()])
            expectLater(call, throwsA(isA<BackendException>().having((e) => e.code, 'code', 'unreachable'))),
        ]);
        expect(clock.now().difference(started), lessThan(const Duration(minutes: 1)));
        expect(sent, [Duration.zero, const Duration(seconds: 24)]);
      }, limit: const Duration(minutes: 5));
    });
  });

  group('a phone clock that is off', () {
    for (final skew in [const Duration(minutes: 20), const Duration(minutes: -20)]) {
      test('${skew.isNegative ? 'slow' : 'fast'} by ${skew.inMinutes.abs()} minutes: the token lasts its 15 minutes here', () {
        final server = DateTime.utc(2026, 10, 8, 12);
        withClock(Clock.fixed(server.add(skew)), () {
          runFake((_) async {
            var refreshes = 0;
            final requests = <http.Request>[];
            final backend = BackendClient(
              http: MockClient((request) async {
                requests.add(request);
                final path = request.url.path;
                // The server's clock runs true: the phone's, less the skew.
                final serverNow = clock.now().subtract(skew);
                if (path.endsWith('encryption-key')) return json(200, ok('{"enabled":false}'));
                if (path.endsWith('/api/user/login')) return session('tok-1', 'c1', server: serverNow, date: true);
                if (isRefresh(request)) {
                  refreshes += 1;
                  return session('tok-${refreshes + 1}', 'c${refreshes + 1}', server: serverNow, date: true);
                }
                return json(200, ok('[]'));
              }),
              secrets: MemorySecretStore(),
            );
            await backend.login(base, 'u', 'p');
            final left = backend.session.value!.accessExpiresAt - clock.now().millisecondsSinceEpoch;
            expect(left, inInclusiveRange(899000, 901000));
            for (var i = 0; i < 5; i++) {
              await backend.hosts();
            }
            expect(refreshes, 0, reason: 'no refresh before every call');
            // Fourteen and a half minutes on, the phone refreshes ahead of the expiry.
            await Future<void>.delayed(const Duration(minutes: 14, seconds: 31));
            await backend.hosts();
            expect(refreshes, 1);
          });
        });
      });
    }
  });

  test('refresh and logout carry the backend origin; nothing else does', () async {
    for (final (server, origin) in [
      (base, base),
      ('https://Backend.example:443/new-api/', base),
      ('http://192.168.1.20:3000/', 'http://192.168.1.20:3000'),
    ]) {
      final requests = <http.Request>[];
      final backend = BackendClient(
        http: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/api/status')) return json(200, ok('{"system_name":"x"}'));
          if (path.endsWith('encryption-key')) return json(200, ok('{"enabled":false}'));
          if (path.endsWith('/api/user/login')) return session('tok-1', 'c1');
          if (isRefresh(request)) return session('tok-2', 'c2');
          return json(200, ok('[]'));
        }),
        secrets: MemorySecretStore(),
      );
      await backend.status(server);
      await backend.login(server, 'u', 'p');
      await backend.hosts();
      await backend.invalidateAccessToken();
      await backend.hosts();
      await backend.logout();
      for (final request in requests) {
        final cookieEndpoint = isRefresh(request) || request.url.path.endsWith('/api/user/auth/logout');
        expect(request.headers['Origin'], cookieEndpoint ? origin : isNull, reason: '$server ${request.url.path}');
      }
      expect(requests.where(isRefresh), hasLength(1));
    }
  });
}

/// A keystore whose writes can start failing.
class _FlakySecretStore extends MemorySecretStore {
  bool failWrites = false;
  bool holdsSession = false;

  /// Writes still to fail before they work again.
  int failNext = 0;

  /// Writes asked for, failed or not.
  int puts = 0;

  @override
  Future<void> put(String name, List<int> value) async {
    puts += 1;
    if (failNext > 0) {
      failNext -= 1;
      throw StateError('keystore write failed');
    }
    if (failWrites) throw StateError('keystore write failed');
    await super.put(name, value);
    if (name == 'auth-session') holdsSession = true;
  }

  @override
  Future<void> delete(String name) async {
    await super.delete(name);
    if (name == 'auth-session') holdsSession = false;
  }
}

/// A slow platform keystore, made deterministic: writes run one at a time
/// in order (as flutter_secure_storage's single worker does), and the one
/// [gate] picks is held until [release].
class _GatedSecretStore extends MemorySecretStore {
  bool Function(String value)? gate;
  final Completer<void> held = Completer<void>();
  final Completer<void> _open = Completer<void>();
  Future<void> _queue = Future.value();

  void release() => _open.complete();

  @override
  Future<void> put(String name, List<int> value) {
    final text = String.fromCharCodes(value);
    final hold = gate?.call(text) ?? false;
    if (hold) gate = null;
    return _queue = _queue.then((_) async {
      if (hold) {
        held.complete();
        await _open.future;
      }
      await super.put(name, value);
    });
  }
}

/// A server that takes the connection and never answers.
class _SilentClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return Completer<http.StreamedResponse>().future;
  }
}
