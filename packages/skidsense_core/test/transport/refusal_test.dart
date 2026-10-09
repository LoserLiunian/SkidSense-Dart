import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

/// `POST /grant` with a cache in front of it: a cached grant until
/// [onDropped], [onUnauthorized] or [onRelayRefused] clears it, then
/// whatever [answer] says. Every relay refusal is asked about (the app's
/// cache asks once in a while: grant_cache_test.dart).
class Backend extends Credentials {
  /// A refusal to throw, or null to issue a grant.
  Object? Function() answer = () => null;

  final List<bool> freshRequests = [];
  int fetched = 0;
  int dropped = 0;
  int relayRefusals = 0;
  int unauthorized = 0;
  String? _cached;

  @override
  Future<String> grant({required bool fresh}) async {
    freshRequests.add(fresh);
    final cached = _cached;
    if (!fresh && cached != null) return cached;
    fetched += 1;
    final refusal = answer();
    if (refusal != null) throw refusal;
    return _cached = 'grant-$fetched';
  }

  @override
  Future<void> onDropped() async {
    dropped += 1;
    _cached = null;
  }

  @override
  Future<void> onUnauthorized() async {
    unauthorized += 1;
    _cached = null;
  }

  @override
  Future<bool> onRelayRefused() async {
    relayRefusals += 1;
    _cached = null;
    return true;
  }
}

/// [FakeCarriers] whose LAN addresses refuse the upgrade with a plaintext
/// status — anything answering at that address can say it.
class _LanRefusing extends FakeCarriers {
  _LanRefusing(this.refusal);

  final CarrierUnavailable refusal;

  @override
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout}) async {
    if (route is! RouteLan) return super.open(route, target, timeout: timeout);
    opened.add(route);
    throw refusal;
  }
}

/// [FakeCarriers] whose relay takes the upgrade, then answers the first
/// frame with `relay-error revoked`: the device revoked, said before the
/// host is reached.
class _RevokingRelay extends FakeCarriers {
  @override
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout}) async {
    if (route is! RouteRelay) return super.open(route, target, timeout: timeout);
    opened.add(route);
    final (client, relay) = MemoryCarrier.pair(route.describe());
    unawaited(() async {
      await relay.receive(); // hs1
      relay.send(jsonEncode({'t': 'relay-error', 'code': 'revoked', 'message': '设备已撤销'}));
      await relay.close();
    }());
    return client;
  }
}

/// How the client takes the backend's and the host's refusals: which are
/// final, which have it ask `/grant` again — once — and which are only a
/// reason to reconnect.
void main() {
  final hostStatic = Primitives.generateKeyPair();
  final identity = Primitives.generateKeyPair();
  final hostId = B64u.encode(Primitives.randomBytes(16));

  HostEndpoint endpoint([List<String> lan = const []]) =>
      HostEndpoint(hostId: hostId, hostKey: hostStatic.pub, deviceId: 'dev-1', lanAddrs: lan, lanPort: lan.isEmpty ? 0 : 47290);

  RcClient client(FakeCarriers carriers, Backend backend, {HostEndpoint? at}) => RcClient(
    endpoint: at ?? endpoint(),
    identity: identity,
    credentials: backend,
    carriers: carriers,
    config: const ClientConfig(callWait: Duration(seconds: 20)),
  );

  /// The first state (the current one included) of type [T] that passes
  /// [where], or null after [within].
  Future<T?> next<T extends ClientState>(RcClient client, {bool Function(T state)? where, Duration within = const Duration(minutes: 5)}) async =>
      await client.states.firstWhere((state) => state is T && (where == null || where(state)), timeout: within) as T?;

  test(
    'a relay-error revoked is final, though the connection was in use',
    () => runFake((_) async {
      final host = FakeHost(hostId, hostStatic);
      final carriers = FakeCarriers()..relay = () => host;
      final backend = Backend();
      final rc = client(carriers, backend)..start();
      await next<ClientConnected>(rc);
      // What the app does on every connect; each call asks for a connection.
      await rc.call('sessions.list');
      await rc.subscribe('*');
      final opens = carriers.opened.length;

      await host.relayError('revoked');
      expect((await next<ClientFailed>(rc))!.code, 'revoked');
      await Future<void>.delayed(const Duration(minutes: 10));
      expect(rc.state, isA<ClientFailed>(), reason: 'it stays failed');
      expect(carriers.opened.length, opens, reason: 'no reconnect behind the failure');
      expect(backend.dropped, 1, reason: 'the cached grant is the revoked device’s');

      // Asked again (the app resumed, say): the backend has the last word,
      // not a grant cached from before the revoke.
      backend.answer = () => const RcException('revoked', detail: 'device');
      rc.retry();
      final failed = (await next<ClientFailed>(rc, where: (state) => state.error is! RelayRejected))!;
      expect(failed.error, isA<RcException>().having((e) => e.code, 'code', 'revoked').having((e) => e.detail, 'detail', 'device'));
      expect(backend.fetched, 2);
      expect(carriers.opened.length, opens, reason: 'the relay was not dialled with the old grant');
      await rc.stop();
    }),
  );

  for (final (reason, status) in [('forbidden', 403), ('not-found', 404)]) {
    test(
      'a relay upgrade refused with $status has /grant say what it means',
      () => runFake((_) async {
        final backend = Backend();
        // The grant cached from before the device was revoked or its host deleted.
        await backend.grant(fresh: false);
        backend
          ..answer = (() => RcException('revoked', detail: status == 404 ? 'gone' : 'device'))
          ..freshRequests.clear();
        final carriers = FakeCarriers()..relayFailure = CarrierUnavailable(reason, detail: 'HTTP/1.1 $status');
        final rc = client(carriers, backend)..start();
        final failed = await next<ClientFailed>(rc);
        expect(failed, isNotNull, reason: 'a revoked device is not "unreachable" for an hour');
        expect(failed!.code, 'revoked');
        expect(backend.relayRefusals, 1);
        expect(backend.fetched, 2, reason: 'the cached grant, then one from the backend');
        expect(carriers.opened, const [RouteRelay()], reason: 'the relay is not dialled again once /grant said no');
        await rc.stop();
      }),
    );
  }

  /// The host refusing the grant (its device list out of date, say) had a
  /// fresh one fetched; the relay refusing afterwards is told all the same —
  /// whether that is news is the credentials' to say. A device revoked, or
  /// remote control turned off, used to have the cached grant replayed for
  /// the hour, the relay dialled every round.
  for (final (what, answer) in [('a revoke', RcException('revoked', detail: 'device')), ('remote control turned off', RcException('companion-disabled'))]) {
    test(
      '$what after the host refused a grant is asked about',
      () => runFake((_) async {
        final host = FakeHost(hostId, hostStatic)..acceptGrant = (_) => false;
        final backend = Backend();
        final carriers = FakeCarriers()..relay = () => host;
        final rc = client(carriers, backend)..start();
        await until(() => backend.fetched == 2 && host.helloGrants.length >= 3);
        backend.answer = () => answer;
        carriers.relayFailure = const CarrierUnavailable('forbidden', detail: 'HTTP/1.1 403 Forbidden');
        final failed = await next<ClientFailed>(rc, within: const Duration(minutes: 2));
        expect(failed?.code, answer.code);
        expect(backend.relayRefusals, 1);
        expect(backend.fetched, 3);
        await rc.stop();
      }),
    );
  }

  /// A plaintext 401, 403 or 404 on the LAN is anyone's to send — the
  /// desktop never answers so (C6): it says nothing of the device or the
  /// bearer, and must spend neither a refresh, nor a `/grant`, nor the
  /// relay's ask.
  for (final (status, reason) in [(401, 'unauthorized'), (403, 'forbidden'), (404, 'not-found')]) {
    test(
      'a LAN that answers $status does not drop the grant, nor stand in for the relay',
      () => runFake((_) async {
        final backend = Backend();
        // The relay unreachable for now (the desktop is off, say).
        final carriers = _LanRefusing(CarrierUnavailable(reason, detail: 'HTTP/1.1 $status'));
        final rc = client(carriers, backend, at: endpoint(['192.168.1.20']))..start();
        await Future<void>.delayed(const Duration(minutes: 2));
        expect(carriers.opened.whereType<RouteLan>().length, greaterThan(3));
        expect(backend.unauthorized, 0);
        expect(backend.relayRefusals, 0);
        expect(backend.fetched, 1);

        // Revoked, and the relay up to say so.
        backend.answer = () => const RcException('revoked', detail: 'device');
        carriers.relayFailure = const CarrierUnavailable('forbidden');
        rc.retry();
        expect((await next<ClientFailed>(rc, within: const Duration(seconds: 30)))?.code, 'revoked');
        expect(backend.relayRefusals, 1);
        expect(backend.fetched, 2);
        await rc.stop();
      }),
    );
  }

  /// Back after a long outage, the backoff at its longest: the relay's 403
  /// has `/grant` asked at once, not after another 30 s shown as "retrying".
  test(
    'a relay 403 has /grant asked at once, not after the backoff',
    () => runFake((_) async {
      final backend = Backend();
      // The relay refused for now: the desktop is off.
      final carriers = FakeCarriers();
      final rc = client(carriers, backend)..start();
      await Future<void>.delayed(const Duration(minutes: 10));
      expect((await next<ClientWaiting>(rc))!.retryIn, greaterThan(const Duration(seconds: 20)));

      backend.answer = () => const RcException('revoked', detail: 'device');
      carriers.relayFailure = const CarrierUnavailable('forbidden');
      final resumed = clock.now();
      rc.retry();
      expect((await next<ClientFailed>(rc))?.code, 'revoked');
      expect(clock.now().difference(resumed), lessThan(const Duration(seconds: 5)));
      await rc.stop();
    }),
  );

  /// The relay says `revoked` in the handshake rather than refusing the
  /// upgrade: the cached grant is the revoked device's all the same.
  test(
    'a relay-error revoked in the handshake drops the cached grant',
    () => runFake((_) async {
      final backend = Backend();
      // A grant from before the revoke.
      await backend.grant(fresh: false);
      final carriers = _RevokingRelay();
      final rc = client(carriers, backend)..start();
      final failed = (await next<ClientFailed>(rc))!;
      expect(failed.error, isA<RelayRejected>().having((e) => e.code, 'code', 'revoked'));
      expect(backend.dropped, 1);

      // Asked again: the backend has the last word, not the cached grant.
      backend.answer = () => const RcException('revoked', detail: 'device');
      rc.retry();
      final again = (await next<ClientFailed>(rc, where: (state) => state.error is! RelayRejected))!;
      expect(again.code, 'revoked');
      expect(backend.fetched, 2);
      expect(carriers.opened, const [RouteRelay()], reason: 'the relay is not dialled with the old grant');
      await rc.stop();
    }),
  );

  /// The desktop refusing every grant (it is signed in to another account,
  /// say) used to have the phone fetch a new one every round, until `/grant`
  /// answered 429 for every phone of the account.
  test(
    'a host that refuses every grant has a fresh one fetched once',
    () => runFake((_) async {
      final host = FakeHost(hostId, hostStatic)..acceptGrant = (_) => false;
      final backend = Backend();
      final rc = client(FakeCarriers()..relay = () => host, backend)..start();
      await Future<void>.delayed(const Duration(minutes: 20));
      expect(backend.freshRequests.where((fresh) => fresh), hasLength(1));
      expect(backend.fetched, 2);
      expect(host.helloGrants.length, greaterThan(20));
      expect(host.helloGrants.toSet(), {'grant-1', 'grant-2'});
      final waiting = rc.state as ClientWaiting;
      expect(waiting.error, isA<HelloRefused>(), reason: 'the host’s reason, not HTTP 429');
      await rc.stop();
    }),
  );

  /// The desktop closing its end is not the bearer failing: nothing is
  /// invalidated or fetched again, and the client reconnects as after any drop.
  test(
    'a host-closed relay error is only a reason to reconnect',
    () => runFake((_) async {
      final host = FakeHost(hostId, hostStatic);
      final backend = Backend();
      final carriers = FakeCarriers()..relay = () => host;
      final rc = client(carriers, backend)..start();
      final first = (await next<ClientConnected>(rc))!;
      await host.relayError('host-closed', message: '这台设备的权限已更改');
      final waiting = (await next<ClientWaiting>(rc))!;
      expect(waiting.error, isA<RelayRejected>().having((e) => e.code, 'code', 'host-closed').having((e) => e.message, 'message', '这台设备的权限已更改'));
      final again = (await next<ClientConnected>(rc))!;
      expect(identical(again, first), isFalse);
      expect(backend.unauthorized, 0);
      expect(backend.dropped, 0);
      expect(backend.fetched, 1, reason: 'the cached grant still stands');
      expect(host.helloGrants, ['grant-1', 'grant-1']);
      await rc.stop();
    }),
  );

  test(
    'a grant refused because the relay is turned off is final',
    () => runFake((_) async {
      final backend = Backend()..answer = () => const RcException('companion-disabled');
      final carriers = FakeCarriers();
      final rc = client(carriers, backend)..start();
      expect((await next<ClientFailed>(rc))!.code, 'companion-disabled');
      await Future<void>.delayed(const Duration(minutes: 10));
      expect(backend.fetched, 1);
      expect(carriers.opened, isEmpty);
      await rc.stop();
    }),
  );

  /// A refresh that could not reach the backend is no sign-out.
  test(
    'a bearer that cannot be had now is retried',
    () => runFake((_) async {
      final host = FakeHost(hostId, hostStatic);
      final backend = Backend();
      final carriers = FakeCarriers()
        ..relay = (() => host)
        ..relayFailure = const CarrierUnavailable('credentials-unavailable', cause: BackendException('unreachable'));
      final rc = client(carriers, backend)..start();
      final waiting = (await next<ClientWaiting>(rc))!;
      expect(waiting.error, isA<RcException>().having((e) => e.detail, 'detail', 'credentials-unavailable'));
      carriers.relayFailure = null;
      expect((await next<ClientConnected>(rc))!.route, const RouteRelay());
      expect(backend.unauthorized, 0);
      expect(backend.dropped, 0);
      await rc.stop();
    }),
  );

  /// Another desktop now at an address the paired one used to have answers
  /// the upgrade on the same port: that alone used to drop a working relay
  /// every minute, for a LAN handshake that then failed.
  test(
    'the relay is kept unless the pinned host answers on the LAN',
    () => runFake((_) async {
      final host = FakeHost(hostId, hostStatic);
      final otherDesktop = FakeHost(B64u.encode(Primitives.randomBytes(16)), Primitives.generateKeyPair());
      final impostor = FakeHost(hostId, Primitives.generateKeyPair());
      final carriers = FakeCarriers()
        ..blackhole = {'192.168.1.20', '192.168.1.21'}
        ..lan = ((route) => route.address == '192.168.1.20' ? otherDesktop : impostor)
        ..relay = () => host;
      final rc = client(carriers, Backend(), at: endpoint(['192.168.1.20', '192.168.1.21']))..start();
      expect((await next<ClientConnected>(rc))!.route, const RouteRelay());
      final seen = <ClientState>[];
      final watching = rc.states.changes.listen(seen.add);
      final dialled = carriers.opened.length;
      carriers.blackhole = {};
      await Future<void>.delayed(const Duration(minutes: 5));
      expect(carriers.opened.length, greaterThan(dialled), reason: 'it did look');
      expect(seen, isEmpty, reason: 'never left the relay');
      expect(host.connections, 1);

      // The paired desktop itself on the LAN is moved to.
      carriers.lan = (_) => host;
      final back = await next<ClientConnected>(rc, where: (state) => state.route is RouteLan, within: const Duration(minutes: 2));
      expect(back, isNotNull);
      // Not awaited: a cancel's future belongs to the root zone, where fake
      // time does not run.
      unawaited(watching.cancel());
      await rc.stop();
    }),
  );

  group('with the app', () {
    /// The device revoked from elsewhere (the web, another phone) while connected.
    test(
      'a revoked device stays revoked, and a retry asks the backend',
      () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
        app.carriers.relay = () => host;
        await app.start();
        await app.controller.connect(host.hostId);
        await app.controller.states.firstWhere((state) => state.connected, timeout: const Duration(minutes: 1));
        await Future<void>.delayed(const Duration(seconds: 5));
        final opens = app.carriers.opened.length;
        final grants = app.backend.log.where((line) => line == 'POST /api/companion/grant').length;
        app.backend.handler = (method, path, _) => path.endsWith('/api/companion/grant') ? (409, TestBackend.fail('设备已撤销', '{"status":"revoked"}')) : null;

        await host.relayError('revoked');
        await Future<void>.delayed(const Duration(minutes: 10));
        expect(app.controller.state.connection, isA<ClientFailed>());
        expect(app.carriers.opened.length, opens, reason: 'no reconnect');

        // The app comes back to the foreground.
        app.controller.networkChanged();
        await Future<void>.delayed(const Duration(minutes: 1));
        final failed = app.controller.state.connection as ClientFailed;
        expect(failed.error, isA<RcException>().having((e) => e.code, 'code', 'revoked'));
        expect(app.carriers.opened.length, opens, reason: 'the old grant is not tried again');
        expect(app.backend.log.where((line) => line == 'POST /api/companion/grant').length, grants + 1);
        app.controller.disconnect();
      }),
    );

    /// The refresh in front of `/grant` failing with its own 409 (a refresh
    /// race) or a proxy's 404 is no word on the device — `/grant` was never
    /// asked. It used to end in "revoked, pair again", for good.
    for (final (name, status, body) in [
      ('409', 409, '{"success":false,"code":"AUTH_REFRESH_RACE","message":"Conflict"}'),
      ('404', 404, '{"success":false,"message":"not found"}'),
    ]) {
      test(
        'a refresh that answers $name is retried, not taken for a revoke',
        () => runFake((_) async {
          final app = TestApp();
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
          await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
          app.carriers.lan = (_) => host;
          var refreshFails = true;
          app.backend.handler = (_, path, _) =>
              path.endsWith('/api/user/auth/refresh') ? (refreshFails ? (status, body) : (200, TestBackend.ok(TestBackend.loginBody(42, 'user42')))) : null;
          await app.signIn(accessExpiresAt: clock.now().millisecondsSinceEpoch - 1000);
          await app.controller.start();
          await app.controller.connect(host.hostId);
          final settled = await app.controller.states.firstWhere(
            (s) => s.connection is ClientWaiting || s.connection is ClientFailed,
            timeout: const Duration(minutes: 1),
          );
          expect(settled!.connection, isA<ClientWaiting>().having((w) => w.error, 'error', isA<RcException>().having((e) => e.code, 'code', 'grant')));
          expect(app.backend.log, isNot(contains('POST /api/companion/grant')));
          expect(app.controller.state.user, isNotNull, reason: 'still signed in');

          refreshFails = false;
          expect(await app.controller.states.firstWhere((s) => s.connected, timeout: const Duration(minutes: 2)), isNotNull);
          app.controller.disconnect();
        }),
      );
    }

    /// The host deleted while the phone was away, so the relay refuses the
    /// upgrade (404) with a grant still cached.
    test(
      'a relay 404 with a grant cached ends in "host gone"',
      () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
        app.carriers.relay = () => host;
        await app.start();
        await app.controller.connect(host.hostId);
        await app.controller.states.firstWhere((state) => state.connected, timeout: const Duration(minutes: 1));
        app.backend.handler = (method, path, _) => path.endsWith('/api/companion/grant') ? (404, TestBackend.fail('电脑不存在')) : null;
        app.carriers.relayFailure = const CarrierUnavailable('not-found', detail: 'HTTP/1.1 404 Not Found');

        await host.drop();
        final failed = await app.controller.states.firstWhere((state) => state.connection is ClientFailed, timeout: const Duration(minutes: 5));
        expect(failed, isNotNull, reason: 'not an hour of "unreachable"');
        expect(
          (failed!.connection as ClientFailed).error,
          isA<RcException>().having((e) => e.code, 'code', 'revoked').having((e) => e.detail, 'detail', 'gone'),
        );
        app.controller.disconnect();
      }),
    );

    /// A proxy in front of the backend answering its own 404 page on
    /// `/api/companion/*` (an ingress rule replaced in a deploy): the relay's
    /// upgrade and `/grant` alike. Only the backend's envelope says a pairing
    /// is gone; this one used to end a working connection in "pair again",
    /// for good, within seconds. A gateway's JSON page has a message, but
    /// no `success: false`: no envelope either.
    for (final (kind, page) in [('page', 'default backend - 404'), ('JSON page', '{"message":"no Route matched with those values"}')]) {
      test(
        'a proxy 404 $kind in front of the relay and /grant is waited out',
        () => runFake((_) async {
          final app = TestApp();
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
          await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
          app.carriers
            ..blackhole = {'192.168.1.20'}
            ..relay = () => host;
          await app.start();
          await app.controller.connect(host.hostId);
          await app.controller.states.firstWhere((state) => state.connected, timeout: const Duration(minutes: 1));
          final seen = <ClientState>[];
          final watching = app.controller.states.changes.listen((s) => seen.add(s.connection));

          app.backend.handler = (_, path, _) => path.contains('/api/companion/') ? (404, page) : null;
          app.carriers.relayFailure = const CarrierUnavailable('not-found', detail: 'HTTP/1.1 404 Not Found');
          await host.drop();
          await Future<void>.delayed(const Duration(seconds: 30));
          expect(app.backend.log, contains('POST /api/companion/grant'), reason: 'the relay\'s 404 was asked about');
          app.backend.handler = (_, _, _) => null;
          app.carriers.relayFailure = null;
          final back = await app.controller.states.firstWhere((state) => state.connected, timeout: const Duration(minutes: 2));
          // Not awaited: a cancel's future belongs to the root zone, where fake
          // time does not run.
          unawaited(watching.cancel());
          expect(back, isNotNull, reason: 'back by itself');
          expect(seen.whereType<ClientFailed>(), isEmpty);
          expect(host.helloGrants.toSet(), {'grant-token'}, reason: 'the grant in hand, kept');
          app.controller.disconnect();
        }),
      );
    }

    /// Something at the desktop's old LAN address answering 401 while the
    /// relay cannot reach the desktop. The desktop never says 401 there: the
    /// bearer is not spent, and every round used to throw it and the grant
    /// away — a refresh and a `/grant` per round, the account's 20 grants in
    /// ten minutes.
    test(
      'a LAN 401 spends neither a refresh nor a /grant',
      () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1', base: app.backend.base)]);
        app.carriers.lan = (_) => throw const CarrierUnavailable('unauthorized', detail: 'HTTP/1.1 401 Unauthorized');
        await app.start();
        await app.controller.connect(host.hostId);
        await Future<void>.delayed(const Duration(minutes: 10));
        expect(app.carriers.opened.whereType<RouteLan>().length, greaterThan(10));
        expect(app.backend.log.where((line) => line == 'POST /api/companion/grant'), hasLength(1));
        expect(app.backend.log, isNot(contains('POST /api/user/auth/refresh')));
        expect(app.controller.state.connection, isA<ClientWaiting>());
        app.controller.disconnect();
      }),
    );
  });
}
