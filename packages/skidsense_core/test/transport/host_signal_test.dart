import 'dart:async';

import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/transport.dart';
import 'package:test/test.dart';

import '../protocol/test_responder.dart';
import '../support/fake_host.dart';
import '../support/fake_time.dart';

class CachingGrants extends Credentials {
  /// `false` the cached grant was reused, `true` a fresh one had to be fetched.
  final List<bool> freshRequests = [];
  int _calls = 0;
  String? _cached;

  @override
  Future<String> grant({required bool fresh}) async {
    final cached = _cached;
    if (cached != null && !fresh) {
      freshRequests.add(false);
      return cached;
    }
    _calls += 1;
    freshRequests.add(true);
    return _cached = 'grant-$_calls';
  }

  /// What the grant cache does with a cached one the host just invalidated (C5).
  @override
  Future<void> onDropped() async => _cached = null;
}

/// What the device does with the two signals that arrive in the clear or end
/// a connection: a `bye` that says why (C5), and an `hsr` that nothing
/// authenticated (C6).
void main() {
  final hostStatic = Primitives.generateKeyPair();
  final identity = Primitives.generateKeyPair();
  final hostId = B64u.encode(Primitives.randomBytes(16));
  const config = ClientConfig(
    lanConnectTimeout: Duration(milliseconds: 2500),
    backoffBase: Duration(seconds: 1),
    backoffMax: Duration(seconds: 8),
    callWait: Duration(seconds: 20),
  );

  RcClient client(FakeCarriers carriers, [CachingGrants? grants]) => RcClient(
        endpoint: HostEndpoint(hostId: hostId, hostKey: hostStatic.pub, deviceId: 'dev-1', lanAddrs: ['192.168.1.20'], lanPort: 47290),
        identity: identity,
        credentials: grants ?? CachingGrants(),
        carriers: carriers,
        config: config,
      );

  Future<ClientState> first<T extends ClientState>(RcClient client, {ClientState? after}) async =>
      (await client.states.firstWhere((state) => state is T && !identical(state, after), timeout: const Duration(minutes: 1)))!;

  Future<List<bool>> kickedWith(String? code) async {
    final host = FakeHost(hostId, hostStatic);
    final grants = CachingGrants();
    final rc = client(FakeCarriers()..lan = (_) => host, grants)..start();
    final firstConnection = await first<ClientConnected>(rc);
    await host.kick(code);
    await first<ClientConnected>(rc, after: firstConnection);
    await rc.stop();
    return grants.freshRequests;
  }

  group('C5: bye with a reason code', () {
    // Widening a device's scopes on the desktop kicks it so it reconnects
    // with the new ones — which only works if the reconnect asks the backend
    // for a new grant. The cached one still lists the old scopes for up to
    // an hour.
    test('a bye for changed scopes fetches a fresh grant', () => runFake((_) async {
          expect(await kickedWith('scopes-changed'), [true, true]);
        }));

    test('a bye for revocation fetches a fresh grant', () => runFake((_) async {
          expect(await kickedWith('revoked'), [true, true]);
        }));

    test('an ordinary bye keeps the cached grant', () => runFake((_) async {
          expect(await kickedWith(null), [true, false]);
          expect(await kickedWith('shutdown'), [true, false]);
        }));
  });

  group('C6: a plaintext hsr is not proof of anything', () {
    test('a plaintext refusal on the LAN still tries the relay', () => runFake((_) async {
          final impostor = FakeHost(hostId, Primitives.generateKeyPair(), rejectWith: 'unknown-device');
          final genuine = FakeHost(hostId, hostStatic);
          final rc = client(FakeCarriers()
            ..lan = ((_) => impostor)
            ..relay = () => genuine)
            ..start();
          expect(((await first<ClientConnected>(rc)) as ClientConnected).route, const RouteRelay());
          await rc.stop();
        }));

    test('the same refusal through the relay is final', () => runFake((_) async {
          final refusing = FakeHost(hostId, hostStatic, rejectWith: 'unknown-device');
          final carriers = FakeCarriers()
            ..lan = ((_) => refusing)
            ..relay = () => refusing;
          final rc = client(carriers)..start();
          expect(((await first<ClientFailed>(rc)) as ClientFailed).code, 'unknown-device');
          expect(carriers.opened, const [RouteLan('192.168.1.20', 47290), RouteRelay()]);
          await rc.stop();
        }));

    test('reconnecting an existing device tries the relay after a plaintext refusal', () => runFake((_) async {
          final impostor = FakeHost(hostId, Primitives.generateKeyPair(), rejectWith: 'unknown-device');
          final genuine = FakeHost(hostId, hostStatic);
          final link = Protocol.pairingUrlPrefix +
              B64u.encode(utf8Bytes(
                '{"v":1,"n":"$hostId","k":"${B64u.encode(hostStatic.pub)}","c":"${B64u.encode(Primitives.randomBytes(32))}","h":["192.168.1.20"],"p":47290,"s":"https://ai.surise.cn","m":"书房的 Mac"}',
              ));
          final welcome = await Enrollment.connectWithGrant(
            payload: Pairing.decode(link),
            deviceId: 'dev-1',
            identity: identity,
            grant: 'grant-1',
            carriers: FakeCarriers()
              ..lan = ((_) => impostor)
              ..relay = () => genuine,
            config: config,
          );
          expect(welcome.host.id, hostId);
          expect(genuine.connections, 1);
        }));

    // After a valid `hs2` the host has proven itself, and the desktop never
    // sends `hsr` past that point. A plaintext one arriving there is
    // somebody else's, so it is a broken connection — not the host refusing.
    test('a plaintext refusal after a valid hs2 is a connection error', () => runFake((_) async {
          final (client, server) = MemoryCarrier.pair('lan 192.168.1.20');
          unawaited(() async {
            final hs1 = (OuterFrames.parse((await server.receive())!) as OuterHs1).frame;
            final (hs2, _) = TestResponder(hostId, hostStatic, hs1).complete();
            server.send(OuterFrames.encode(hs2.toJson()));
            await server.receive(); // the sealed hello
            server.send('{"t":"hsr","code":"unknown-device","message":"x"}');
          }());
          final initiator = Initiator(
            mode: HandshakeMode.connect,
            hostId: hostId,
            hostStatic: hostStatic.pub,
            clientStatic: identity,
          );
          await expectLater(
            RcConnection.establish(carrier: client, route: const RouteLan('192.168.1.20', 47290), initiator: initiator, grant: 'grant'),
            throwsA(isA<HandshakeClosed>().having((e) => e.detail, 'detail', 'plaintext-after-handshake')),
          );
        }));
  });
}
