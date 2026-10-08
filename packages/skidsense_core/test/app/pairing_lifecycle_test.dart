import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

/// Pairing against a real [AppController]: the plaintext-refusal repair rule
/// (spec §6.5, C6), and pairings belonging to an account (S33).
///
/// The scenario the LAN attacker wins without the rule: the phone re-scans a
/// host its key is still active on (the 409 path), and anything answering
/// the QR's LAN address claims `unknown-device`. It used to cost the phone
/// its own backend row — revoked by *itself*, before the relay was tried.
void main() {
  PairingPayload qrFor(FakeHost host, List<int> code, {String server = 'https://backend.example'}) => Pairing.decode(
        Protocol.pairingUrlPrefix +
            B64u.encode(utf8Bytes(
              '{"v":1,"n":"${host.hostId}","k":"${B64u.encode(host.hostStatic.pub)}","c":"${B64u.encode(code)}","h":["192.168.1.20"],"p":47290,"s":"$server","m":"书房的 Mac"}',
            )),
      );

  /// The backend's walk of the 409 path: 409 with the old id, then the
  /// second registration.
  void pair409(TestApp app, FakeHost host, {String oldDevice = 'dev-old', String newDevice = 'dev-new'}) {
    var registrations = 0;
    app.backend.handler = (method, path, _) {
      if (path.endsWith('/api/companion/devices') && method == 'POST') {
        registrations += 1;
        return registrations == 1
            ? (409, TestBackend.fail('已登记', '{"device_id":"$oldDevice"}'))
            : (
                200,
                TestBackend.ok(
                    '{"device":{"device_id":"$newDevice","host_id":"${host.hostId}","name":"Test Phone","platform":"android","status":"pending","created_at":1},"ticket":"ticket-1","ticket_expires_at":9999999999}')
              );
      }
      if (method == 'DELETE' && path.contains('/api/companion/devices/')) return (200, TestBackend.ok('null'));
      return null;
    };
  }

  test('a fresh pairing registers, enrols and remembers the host', () => runFake((_) async {
        final app = TestApp();
        final code = Primitives.randomBytes(32);
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())..pairingCode = code;
        app.backend.handler = (method, path, _) => path.endsWith('/api/companion/devices') && method == 'POST'
            ? (
                200,
                TestBackend.ok(
                    '{"device":{"device_id":"dev-1","host_id":"${host.hostId}","status":"pending"},"ticket":"ticket-1","ticket_expires_at":9999999999}')
              )
            : null;
        app.carriers.lan = (_) => host;
        await app.start();
        final steps = <PairStep>[];
        final paired = await app.controller.pair(qrFor(host, code), onStep: steps.add);
        expect(paired.deviceId, 'dev-1');
        expect(paired.name, '书房的 Mac');
        expect(host.enrolledKeys.single, (await app.controller.identity()).pub);
        expect((await app.pairedOnDisk()).single.hostId, host.hostId);
        expect(steps, [PairStep.registering, PairStep.handshaking, PairStep.finishing]);
      }));

  test('a QR for another backend is refused before anything is sent', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await app.start();
        await expectLater(
          app.controller.pair(qrFor(host, Primitives.randomBytes(32), server: 'https://elsewhere.example')),
          throwsA(isA<PairingError>().having((e) => e.reason, 'reason', 'wrong-backend')),
        );
        expect(app.backend.log.where((line) => line.contains('/devices')), isEmpty);
      }));

  /// A LAN address answering `unknown-device` meant nothing: the repair walks
  /// the relay first, and only the host's own word through it counts.
  test('a plaintext unknown-device on the LAN does not revoke the phone’s own row', () => runFake((_) async {
        final app = TestApp();
        final impostor = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair(), rejectWith: 'unknown-device');
        final genuine = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        pair409(app, genuine);
        app.carriers
          ..lan = ((_) => impostor)
          ..relay = () => genuine;
        await app.start();
        await app.controller.pair(qrFor(genuine, Primitives.randomBytes(32)));
        expect(app.backend.log.where((line) => line.startsWith('DELETE')), isEmpty,
            reason: 'a plaintext refusal must never reach the destructive repair (C6)');
        final paired = await app.pairedOnDisk();
        expect(paired.single.deviceId, 'dev-old', reason: 'the row the backend still lists is kept');
        expect(genuine.connections, 1);
      }));

  /// The relay saying it too *is* the stale case: then, and only then, the
  /// row is replaced.
  test('the same refusal through the relay is what earns the repair', () => runFake((_) async {
        final app = TestApp();
        final code = Primitives.randomBytes(32);
        final rejecting = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())
          ..rejectConnectWith = 'unknown-device'
          ..pairingCode = code;
        pair409(app, rejecting);
        app.carriers
          ..lan = ((_) => rejecting)
          ..relay = () => rejecting;
        await app.start();
        await app.controller.pair(qrFor(rejecting, code));
        expect(app.backend.log.where((line) => line.startsWith('DELETE')), ['DELETE /api/companion/devices/dev-old']);
        expect((await app.pairedOnDisk()).single.deviceId, 'dev-new');
      }));

  /// A relay that cannot be reached says nothing: no revocation.
  test('an unreachable relay confirms nothing and nothing is revoked', () => runFake((_) async {
        final app = TestApp();
        final impostor = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair(), rejectWith: 'unknown-device');
        final genuine = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        pair409(app, genuine);
        app.carriers
          ..lan = ((_) => impostor)
          ..relay = () => null;
        await app.start();
        Object? failure;
        try {
          await app.controller.pair(qrFor(genuine, Primitives.randomBytes(32)));
        } catch (error) {
          failure = error;
        }
        expect(failure, isNotNull, reason: 'with no truthful route the attempt fails rather than destroys');
        expect(app.backend.log.where((line) => line.startsWith('DELETE')), isEmpty);
        expect(await app.pairedOnDisk(), isEmpty);
      }));

  group('S33: pairings belong to the account that made them', () {
    test('a re-login reads back the same account’s pairings', () => runFake((_) async {
          final files = MemoryFileStore();
          final a = TestApp.pairedHost('A', Primitives.generateKeyPair(), 'dev-A', name: '电脑A');
          final b = TestApp.pairedHost('B', Primitives.generateKeyPair(), 'dev-B', name: '电脑B');
          await TestApp.writePaired(files, [a, b]);
          final app = TestApp(files: files);
          await app.start();
          expect(app.controller.state.paired.map((p) => p.hostId), ['A', 'B']);

          await app.controller.logout();
          expect(app.controller.state.paired, isEmpty, reason: 'memory is cleared');
          expect(await app.pairedOnDisk(), hasLength(2), reason: 'disk is the account’s, not the logout’s business');

          app.backend.handler = (method, path, _) =>
              path.endsWith('/api/user/login') && method == 'POST' ? (200, TestBackend.ok(TestBackend.loginBody(42, 'user42'))) : null;
          await app.controller.login('https://backend.example', 'user42', 'pass');
          expect(app.controller.state.paired.map((p) => p.hostId), ['A', 'B']);
        }));

    test('another account does not see the previous account’s hosts', () => runFake((_) async {
          final files = MemoryFileStore();
          await TestApp.writePaired(files, [TestApp.pairedHost('A', Primitives.generateKeyPair(), 'dev-A', name: '张三的电脑')]);
          final lisi = TestApp(files: files, signedInAs: 43);
          await lisi.start();
          expect(lisi.controller.state.paired, isEmpty, reason: 'user 43 must not see user 42’s computer');

          // Legacy rows (no owner) are adopted by whoever is on the same backend.
          final legacy = MemoryFileStore();
          await TestApp.writePaired(legacy, [TestApp.pairedHost('A', Primitives.generateKeyPair(), 'dev-A', userId: 0)]);
          final anyone = TestApp(files: legacy, signedInAs: 43);
          await anyone.start();
          expect(anyone.controller.state.paired, hasLength(1));
        }));

    test('saving a pairing keeps the rows another account owns', () => runFake((_) async {
          final files = MemoryFileStore();
          await TestApp.writePaired(files, [TestApp.pairedHost('A', Primitives.generateKeyPair(), 'dev-A', userId: 7)]);
          final app = TestApp(files: files);
          final code = Primitives.randomBytes(32);
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())..pairingCode = code;
          app.backend.handler = (method, path, _) => path.endsWith('/api/companion/devices') && method == 'POST'
              ? (200, TestBackend.ok('{"device":{"device_id":"dev-1"},"ticket":"ticket-1"}'))
              : null;
          app.carriers.lan = (_) => host;
          await app.start();
          await app.controller.pair(qrFor(host, code));
          final onDisk = await app.pairedOnDisk();
          expect(onDisk.map((p) => p.hostId).toSet(), {'A', host.hostId});
          expect(app.controller.state.paired.map((p) => p.hostId), [host.hostId]);
        }));
  });

  test('a cold start with a stored session lands signed in', () => runFake((_) async {
        final app = TestApp();
        await app.start();
        expect(app.controller.state.ready, isTrue);
        expect(app.controller.state.user, 'user42');
        final signedOut = TestApp(signedInAs: null);
        await signedOut.start();
        expect(signedOut.controller.state.user, isNull);
      }));
}
