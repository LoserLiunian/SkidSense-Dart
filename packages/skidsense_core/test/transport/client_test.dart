import 'dart:async';
import 'dart:typed_data';

import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/transport.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';

class Grants extends Credentials {
  int issued = 0;
  final List<bool> freshRequests = [];

  @override
  Future<String> grant({required bool fresh}) async {
    freshRequests.add(fresh);
    issued += 1;
    return 'grant-$issued';
  }
}

/// The client end to end against an in-process fake host: handshake, hello,
/// requests (plain, parted, failing), events, pings, LAN-then-relay
/// fallback, reconnects, and the ways a connection must be torn down.
void main() {
  final hostStatic = Primitives.generateKeyPair();
  final identity = Primitives.generateKeyPair();
  final hostId = B64u.encode(Primitives.randomBytes(16));

  HostEndpoint endpoint({List<String> lan = const ['192.168.1.20'], Uint8List? hostKey}) => HostEndpoint(
        hostId: hostId,
        hostKey: hostKey ?? hostStatic.pub,
        deviceId: 'dev-1',
        lanAddrs: lan,
        lanPort: 47290,
      );

  const fastConfig = ClientConfig(
    lanConnectTimeout: Duration(milliseconds: 2500),
    backoffBase: Duration(seconds: 1),
    backoffMax: Duration(seconds: 8),
    callWait: Duration(seconds: 20),
  );

  RcClient client(FakeHost? host, {FakeCarriers? carriers, HostEndpoint? at, Grants? grants}) => RcClient(
        endpoint: at ?? endpoint(),
        identity: identity,
        credentials: grants ?? Grants(),
        carriers: carriers ?? (FakeCarriers()..lan = (_) => host),
        config: fastConfig,
      );

  FakeHost newHost() => FakeHost(hostId, hostStatic);

  Future<ClientConnected> connected(RcClient client, {ClientConnected? after}) async =>
      (await client.states.firstWhere(
        (state) => state is ClientConnected && !identical(state, after),
        timeout: const Duration(minutes: 1),
      ))! as ClientConnected;

  Future<T> stateOf<T extends ClientState>(RcClient client) async =>
      (await client.states.firstWhere((state) => state is T, timeout: const Duration(minutes: 1)))! as T;

  test('connects over the LAN and calls', () => runFake((_) async {
        final host = newHost()
          ..handler = (method, _) {
            expect(method, 'sessions.list');
            return [
              {'key': 'claude:1', 'title': '示例'},
            ];
          };
        final rc = client(host)..start();
        final state = await connected(rc);
        expect(state.route, isA<RouteLan>());
        expect(state.welcome.host.id, hostId);
        expect(state.welcome.host.name, '书房的 Mac');
        expect(state.welcome.hasScope('approve'), isTrue);
        expect(state.welcome.can('sessions.list'), isTrue);
        expect(host.helloGrants, ['grant-1']);

        final result = await rc.call('sessions.list', <String, Object?>{}) as List;
        expect((result.first as Map)['title'], '示例');
        await rc.stop();
      }));

  test('request ids are unique and concurrent calls resolve independently', () => runFake((_) async {
        final host = newHost()..handler = (method, params) => method == 'echo' ? params : method;
        final rc = client(host)..start();
        await connected(rc);
        final results = await Future.wait([for (var n = 1; n <= 20; n++) rc.call('echo', n)]);
        expect(results, [for (var n = 1; n <= 20; n++) n]);
        await rc.stop();
      }));

  test('parted responses are reassembled', () => runFake((_) async {
        final big = '示例文本' * 400;
        final host = newHost()
          ..partSize = 97
          ..handler = (_, _) => {'text': big};
        final rc = client(host)..start();
        await connected(rc);
        final result = await rc.call('fs.read') as Map<String, Object?>;
        expect(result['text'], big);
        await rc.stop();
      }));

  test("error responses carry the host's code", () => runFake((_) async {
        final host = newHost()..handler = (_, _) => throw const RemoteCallError('forbidden', '这台设备没有文件权限');
        final rc = client(host)..start();
        await connected(rc);
        await expectLater(
          rc.call('fs.list'),
          throwsA(isA<RemoteCallError>()
              .having((e) => e.code, 'code', 'forbidden')
              .having((e) => e.message, 'message', '这台设备没有文件权限')),
        );
        await rc.stop();
      }));

  test('events and pings flow', () => runFake((_) async {
        final host = newHost();
        final rc = client(host)..start();
        await connected(rc);
        final event = rc.events.first;
        await Future<void>.delayed(Duration.zero);
        host.emit('sessions.changed', <String, Object?>{});
        expect((await event.timeout(const Duration(seconds: 5))).kind, 'sessions.changed');
        host.ping(1234);
        // The pong comes back through the host's read loop.
        await until(() => host.pongs > 0, timeout: const Duration(seconds: 5));
        await rc.stop();
      }));

  test('falls back from the LAN to the relay', () => runFake((_) async {
        final host = newHost();
        final carriers = FakeCarriers()
          ..lan = ((_) => null)
          ..relay = () => host;
        final rc = client(null, carriers: carriers, at: endpoint(lan: ['192.168.1.20', '10.0.0.5']))..start();
        final state = await connected(rc);
        expect(state.route, const RouteRelay());
        expect(carriers.opened, const [RouteLan('192.168.1.20', 47290), RouteLan('10.0.0.5', 47290), RouteRelay()]);
        await rc.stop();
      }));

  test('a silent LAN address times out and the next one is used', () => runFake((_) async {
        final host = newHost();
        final carriers = FakeCarriers()
          ..blackhole = {'192.168.1.20'}
          ..lan = (route) => route.address == '10.0.0.5' ? host : null;
        final rc = client(null, carriers: carriers, at: endpoint(lan: ['192.168.1.20', '10.0.0.5']))..start();
        expect((await connected(rc)).route, const RouteLan('10.0.0.5', 47290));
        await rc.stop();
      }));

  test('an impostor on the LAN is skipped for the real host on the relay', () => runFake((_) async {
        // Something on the LAN answers at the address, holding a different key.
        final impostor = FakeHost(hostId, Primitives.generateKeyPair());
        final host = newHost();
        final carriers = FakeCarriers()
          ..lan = ((_) => impostor)
          ..relay = () => host;
        final rc = client(null, carriers: carriers)..start();
        expect((await connected(rc)).route, const RouteRelay());
        expect(impostor.connections, 0, reason: 'the impostor never got past the handshake');
        await rc.stop();
      }));

  test('the same unknown-device refusal from the LAN and the relay is permanent', () => runFake((time) async {
        final host = newHost()..rejectWith = 'unknown-device';
        final carriers = FakeCarriers()
          ..lan = ((_) => host)
          ..relay = () => host;
        final rc = client(null, carriers: carriers)..start();
        final failed = await stateOf<ClientFailed>(rc);
        expect(failed.code, 'unknown-device');
        final opened = carriers.opened.length;
        await Future<void>.delayed(const Duration(minutes: 2));
        expect(carriers.opened.length, opened, reason: 'no retries after a permanent refusal');
        await rc.stop();
      }));

  test('reconnects after a drop and resubscribes', () => runFake((_) async {
        final host = newHost();
        final rc = client(host)..start();
        final first = await connected(rc);
        await rc.subscribe('claude:1');
        expect(host.calls.where((call) => call.$1 == 'subscribe'), hasLength(1));

        await host.drop();
        await connected(rc, after: first);
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(host.connections, 2);
        expect(host.calls.where((call) => call.$1 == 'subscribe'), hasLength(2), reason: 'subscriptions survive a reconnect');
        await rc.stop();
      }));

  test("a gap in the host's counter closes the connection", () => runFake((_) async {
        final host = newHost();
        final rc = client(host)..start();
        await connected(rc);
        host
          ..skipFrame()
          ..emit('sessions.changed', <String, Object?>{});
        final waiting = await stateOf<ClientWaiting>(rc);
        expect(waiting.error, isA<ConnectionClosed>().having((e) => e.detail, 'detail', 'out-of-order'));
        await rc.stop();
      }));

  test('a tampered frame closes the connection', () => runFake((_) async {
        final host = newHost();
        final rc = client(host)..start();
        await connected(rc);
        host.sendTampered('{"t":"ev","k":"sessions.changed","p":{}}');
        final waiting = await stateOf<ClientWaiting>(rc);
        expect(waiting.error, isA<ConnectionClosed>().having((e) => e.detail, 'detail', 'bad-frame'));
        await rc.stop();
      }));

  test('a plaintext frame after the handshake closes the connection', () => runFake((_) async {
        final host = newHost();
        final rc = client(host)..start();
        await connected(rc);
        host.sendRaw('{"t":"hs2","e":"x","c":"y"}');
        await stateOf<ClientWaiting>(rc);
        await rc.stop();
      }));

  test('relay errors are honoured on the relay only', () => runFake((_) async {
        final host = newHost();
        final rc = client(null, carriers: FakeCarriers()..relay = () => host, at: endpoint(lan: []))..start();
        await connected(rc);
        await host.relayError('revoked');
        expect((await stateOf<ClientFailed>(rc)).code, 'revoked');
        await rc.stop();

        // The same frame on a LAN socket is someone pretending to be the relay.
        final lanHost = newHost();
        final lanClient = client(lanHost)..start();
        await connected(lanClient);
        await lanHost.relayError('revoked');
        final waiting = await stateOf<ClientWaiting>(lanClient);
        expect(waiting.error, isA<ConnectionClosed>().having((e) => e.detail, 'detail', 'relay-frame-on-lan'));
        await lanClient.stop();
      }));

  test('a refused grant is replaced with a fresh one', () => runFake((_) async {
        final host = newHost()..acceptGrant = (grant) => grant == 'grant-2';
        final grants = Grants();
        final rc = client(host, grants: grants)..start();
        await connected(rc);
        expect(host.helloGrants, ['grant-1', 'grant-2']);
        expect(grants.freshRequests, [false, true]);
        await rc.stop();
      }));

  test('calls fail fast when offline', () => runFake((_) async {
        final rc = client(null, carriers: FakeCarriers())..start();
        await expectLater(rc.call('sessions.list'), throwsA(isA<RcException>().having((e) => e.code, 'code', 'offline')));
        await rc.stop();
      }));

  test('requests time out', () => runFake((_) async {
        final host = newHost()..handler = (_, _) => Completer<Object?>().future;
        final rc = client(host)..start();
        await connected(rc);
        await expectLater(
          rc.call('sessions.open', null, const Duration(seconds: 5)),
          throwsA(isA<RcException>().having((e) => e.code, 'code', 'timeout')),
        );
        await rc.stop();
      }));

  String pairingLink({required Uint8List code}) {
    final payload =
        '{"v":1,"n":"$hostId","k":"${B64u.encode(hostStatic.pub)}","c":"${B64u.encode(code)}","h":["192.168.1.20"],"p":47290,"s":"https://ai.surise.cn","m":"书房的 Mac"}';
    return Protocol.pairingUrlPrefix + B64u.encode(utf8Bytes(payload));
  }

  test('enrollment uses the pairing code and the ticket', () => runFake((_) async {
        final code = Primitives.randomBytes(32);
        final host = newHost()
          ..pairingCode = code
          ..acceptTicket = (ticket) => ticket == 'ticket-1';
        final payload = Pairing.decode(pairingLink(code: code));
        final welcome = await Enrollment.enroll(
          payload: payload,
          deviceId: 'dev-1',
          identity: identity,
          ticket: 'ticket-1',
          carriers: FakeCarriers()..lan = (_) => host,
          config: fastConfig,
        );
        expect(welcome.host.id, hostId);
        expect(host.enrolledKeys, hasLength(1));
        expect(host.enrolledKeys.single, identity.pub);

        // A wrong code never gets past the host's first step.
        final wrong = Pairing.decode(pairingLink(code: Primitives.randomBytes(32)));
        await expectLater(
          Enrollment.enroll(
            payload: wrong,
            deviceId: 'dev-1',
            identity: identity,
            ticket: 'ticket-1',
            carriers: FakeCarriers()..lan = (_) => host,
            config: fastConfig,
          ),
          throwsA(isA<HandshakeRejected>()),
        );
        // A refused ticket is final.
        await expectLater(
          Enrollment.enroll(
            payload: payload,
            deviceId: 'dev-1',
            identity: identity,
            ticket: 'ticket-2',
            carriers: FakeCarriers()..lan = (_) => host,
            config: fastConfig,
          ),
          throwsA(isA<HelloRefused>()),
        );
      }));

  /// The 409 recovery (spec §9): the phone is already registered, the backend
  /// issued no ticket, and the way back in is a grant plus an ordinary
  /// `connect` handshake.
  test('an existing device reconnects with a grant instead of a ticket', () => runFake((_) async {
        final host = newHost()
          ..pairingCode = null
          ..acceptGrant = ((grant) => grant == 'grant-1')
          ..acceptTicket = (_) => false;
        final payload = Pairing.decode(pairingLink(code: Primitives.randomBytes(32)));
        final welcome = await Enrollment.connectWithGrant(
          payload: payload,
          deviceId: 'dev-1',
          identity: identity,
          grant: 'grant-1',
          carriers: FakeCarriers()..lan = (_) => host,
          config: fastConfig,
        );
        expect(welcome.host.id, hostId);
        expect(host.helloGrants, ['grant-1']);
        expect(host.enrolledKeys, isEmpty, reason: 'a reconnect enrols nothing');

        await expectLater(
          Enrollment.connectWithGrant(
            payload: payload,
            deviceId: 'dev-1',
            identity: identity,
            grant: 'grant-2',
            carriers: FakeCarriers()..lan = (_) => host,
            config: fastConfig,
          ),
          throwsA(isA<HelloRefused>()),
        );
        // The enrol path is not reachable without a ticket.
        expect(
          () => Enrollment.enroll(
            payload: payload,
            deviceId: 'dev-1',
            identity: identity,
            ticket: '',
            carriers: FakeCarriers()..lan = (_) => host,
            config: fastConfig,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }));
}
