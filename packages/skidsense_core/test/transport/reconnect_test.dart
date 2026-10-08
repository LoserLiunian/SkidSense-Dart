import 'dart:async';

import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/src/util/async_queue.dart';
import 'package:skidsense_core/transport.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';

class FixedGrants extends Credentials {
  @override
  Future<String> grant({required bool fresh}) async => 'grant';
}

/// A carrier on which the relay has already refused the device and closed:
/// its `relay-error` frame is waiting in the inbox, and the first send
/// throws as a closed socket does.
class ClosedByRelay implements Carrier {
  ClosedByRelay(String code) {
    _inbox
      ..add('{"t":"relay-error","code":"$code","message":"x"}')
      ..close();
  }

  final AsyncQueue<String> _inbox = AsyncQueue();

  @override
  String get label => 'relay';

  @override
  Future<String?> receive({Duration? timeout}) => _inbox.next(timeout: timeout);

  @override
  void send(String text) => throw const ConnectionClosed('peer-closed');

  @override
  Future<void> close([String reason = '']) async {}
}

class _OfflineThenUp implements CarrierFactory {
  _OfflineThenUp(this.host, this.offline);

  final FakeHost host;
  int offline;

  @override
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout}) async {
    if (offline > 0) {
      offline -= 1;
      return ClosedByRelay('host-offline');
    }
    final (client, server) = MemoryCarrier.pair(route.describe());
    host.serve(server);
    return client;
  }
}

/// What the real three-way runs found in the reference client's connect loop
/// and its requests, held here as regressions.
void main() {
  final hostStatic = Primitives.generateKeyPair();
  final identity = Primitives.generateKeyPair();
  final hostId = B64u.encode(Primitives.randomBytes(16));

  HostEndpoint endpoint(List<String> lan, [int port = 47290]) =>
      HostEndpoint(hostId: hostId, hostKey: hostStatic.pub, deviceId: 'dev-1', lanAddrs: lan, lanPort: port);

  Future<T> first<T extends ClientState>(RcClient client, [bool Function(T state)? test]) async =>
      (await client.states.firstWhere((state) => state is T && (test == null || test(state)), timeout: const Duration(minutes: 5)))!
          as T;

  /// A relay refusing the device while the desktop is offline used to end
  /// the reconnect loop for good; the phone sat on "connecting · relay" even
  /// after the desktop came back.
  test('a relay refusal on a closed socket does not end the loop', () => runFake((_) async {
        final host = FakeHost(hostId, hostStatic);
        final rc = RcClient(
          endpoint: endpoint(const [], 0),
          identity: identity,
          credentials: FixedGrants(),
          carriers: _OfflineThenUp(host, 2),
          config: const ClientConfig(backoffBase: Duration(seconds: 1), backoffMax: Duration(seconds: 4)),
        )..start();
        final waiting = await first<ClientWaiting>(rc);
        expect(waiting.error, isA<RelayRejected>().having((e) => e.code, 'code', 'host-offline'),
            reason: "the relay's own reason, not the transport's");
        expect((await first<ClientConnected>(rc)).route, const RouteRelay());
        await rc.stop();
      }));

  /// A desktop that moved to another LAN port is reached on the new one
  /// without restarting the app.
  test('a learned LAN port replaces the old one', () {
    final at = endpoint(['192.168.1.20']);
    expect(at.learn(['192.168.1.20'], 51000), isTrue);
    expect(at.routes().whereType<RouteLan>().map((route) => route.port).toSet(), {51000});
    expect(at.learn(['192.168.1.20'], 51000), isFalse, reason: 'the same port again is not news');
  });

  /// Unreachable LAN addresses cost about one timeout in all, and the relay
  /// is already on its way by then.
  test('unreachable LAN addresses do not hold the relay back', () => runFake((time) async {
        final host = FakeHost(hostId, hostStatic);
        const addresses = ['192.168.1.20', '192.168.139.3', 'fd07::1', 'fdfe::1'];
        final carriers = FakeCarriers()
          ..blackhole = addresses.toSet()
          ..relay = () => host;
        final rc = RcClient(endpoint: endpoint(addresses), identity: identity, credentials: FixedGrants(), carriers: carriers);
        final started = time.elapsed;
        rc.start();
        final state = await first<ClientConnected>(rc);
        final took = time.elapsed - started;
        expect(state.route, const RouteRelay());
        expect(took <= const Duration(seconds: 3), isTrue, reason: 'relay reached after $took');
        await rc.stop();
      }));

  /// On the relay, a desktop whose LAN address answers again is moved back
  /// to — the relay is budgeted.
  test('a relay connection moves back to the LAN when it answers', () => runFake((_) async {
        final host = FakeHost(hostId, hostStatic);
        final carriers = FakeCarriers()
          ..blackhole = {'192.168.1.20'}
          ..lan = ((_) => host)
          ..relay = () => host;
        final rc = RcClient(endpoint: endpoint(['192.168.1.20']), identity: identity, credentials: FixedGrants(), carriers: carriers)
          ..start();
        expect((await first<ClientConnected>(rc)).route, const RouteRelay());
        carriers.blackhole = {};
        final back = await first<ClientConnected>(rc, (state) => state.route is RouteLan);
        expect(back.route, isA<RouteLan>());
        await rc.stop();
      }));

  /// Over a budgeted relay a large response arrives slowly but steadily; the
  /// limit is on silence, not on the whole call.
  test('a slow but steady response is not timed out', () => runFake((_) async {
        final big = 'x' * 7000;
        final host = FakeHost(hostId, hostStatic, partSize: 1000, partDelay: const Duration(seconds: 10))
          ..handler = (_, _) => {'text': big};
        final rc = RcClient(
          endpoint: endpoint(['192.168.1.20']),
          identity: identity,
          credentials: FixedGrants(),
          carriers: FakeCarriers()..lan = (_) => host,
        )..start();
        await first<ClientConnected>(rc);
        final result = await rc.call('sessions.open') as Map<String, Object?>;
        expect(result['text'], big);
        await rc.stop();
      }));

  group('HostEndpoint', () {
    test('routes follow the order addresses were learned', () {
      final at = endpoint(['192.168.1.20']);
      expect(at.routes(), const [RouteLan('192.168.1.20', 47290), RouteRelay()]);
      at.learn(['10.0.0.5']);
      expect(at.routes(), const [RouteLan('10.0.0.5', 47290), RouteLan('192.168.1.20', 47290), RouteRelay()],
          reason: 'a learned address first, the old one kept as a fallback');
    });

    test('the same list twice is not a change, an empty one changes nothing', () {
      final at = endpoint(['192.168.1.20']);
      expect(at.learn(['192.168.1.20']), isFalse);
      expect(at.learn([]), isFalse);
      expect(at.addresses, ['192.168.1.20']);
    });

    test('the fallback list is bounded and deduplicated', () {
      final at = endpoint(['10.0.0.1']);
      for (var i = 2; i < 40; i++) {
        at.learn(['10.0.0.$i', '10.0.0.$i']);
      }
      final lan = at.routes().whereType<RouteLan>().toList();
      expect(lan.length, 16);
      expect(lan.first.address, '10.0.0.39');
    });

    test('a zero port means no LAN route, and the relay can be turned off', () {
      expect(endpoint(['192.168.1.20'], 0).routes(), const [RouteRelay()]);
      final noRelay = HostEndpoint(
        hostId: hostId,
        hostKey: hostStatic.pub,
        deviceId: 'dev-1',
        lanAddrs: ['192.168.1.20'],
        lanPort: 47290,
        relayEnabled: false,
      );
      expect(noRelay.routes(), const [RouteLan('192.168.1.20', 47290)]);
    });
  });
}
