import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

/// How a paired phone goes offline, through the real [AppController] and
/// its real grant cache.
void main() {
  int grants(TestApp app) => app.backend.log.where((line) => line.endsWith('/api/companion/grant')).length;

  /// The desktop changed this phone's scopes and kicked it with
  /// `scopes-changed`: the reconnect must carry a grant fetched after the
  /// change, or the new scopes wait up to an hour for the cached one.
  test('a kick for changed scopes fetches a fresh grant', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        await app.connectTo(host);
        await Future<void>.delayed(const Duration(seconds: 5));
        final before = grants(app);
        final connections = host.connections;
        await host.kick('scopes-changed');
        await app.controller.states.firstWhere((s) => s.connected && host.connections > connections, timeout: const Duration(minutes: 1));
        expect(grants(app), before + 1);
        app.controller.disconnect();
      }));

  /// Revoked while connected, with the cached grant at the end of its life.
  /// The backend refuses the next grant with 409; that ends the round
  /// instead of being retried — each retry spent the account's per-user
  /// budget that the owner's other phones need.
  test('a revoked phone stops asking for grants', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        app.backend.handler = (_, path, _) => path.endsWith('/api/companion/grant') ? (200, TestBackend.grant(59)) : null;
        await app.connectTo(host);
        await Future<void>.delayed(const Duration(seconds: 5));
        app.backend.handler = (_, path, _) => path.endsWith('/api/companion/grant')
            ? (409, TestBackend.fail('该设备尚未激活或已被撤销', '{"status":"revoked"}'))
            : null;
        host.rejectConnectWith = 'unknown-device';
        final start = grants(app);
        await host.kick('revoked', reason: '这台设备已被撤销');
        await Future<void>.delayed(const Duration(minutes: 20));
        final connection = app.controller.state.connection;
        expect(connection, isA<ClientFailed>().having((f) => f.code, 'code', 'revoked'));
        expect(grants(app) - start <= 1, isTrue, reason: 'saw ${grants(app) - start} in 20 minutes');
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// A host row that is gone (404) is as final as a revoked device.
  test('a gone host row also ends the round', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        app.backend.handler = (_, path, _) => path.endsWith('/api/companion/grant') ? (404, TestBackend.fail('电脑不存在')) : null;
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1')]);
        app.carriers.lan = (_) => host;
        await app.start();
        await app.controller.connect(host.hostId);
        await Future<void>.delayed(const Duration(minutes: 20));
        expect(app.controller.state.connection, isA<ClientFailed>().having((f) => f.code, 'code', 'revoked'));
        expect(grants(app) <= 1, isTrue, reason: 'saw ${grants(app)} grant requests');
        app.controller.disconnect();
      }, limit: const Duration(hours: 1)));

  /// "Forget" revokes this phone on the backend too: the desktop otherwise
  /// kept wrapping every new history epoch to a key the user let go of.
  test('forgetting a host revokes this phone there', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        app.backend.handler = (method, path, _) =>
            method == 'DELETE' && path.endsWith('/api/companion/devices/dev-1') ? (200, TestBackend.ok('null')) : null;
        await app.connectTo(host);
        await Future<void>.delayed(const Duration(seconds: 5));
        await app.controller.forgetHost(host.hostId);
        expect(app.backend.log, contains('DELETE /api/companion/devices/dev-1'));
        expect(await app.pairedOnDisk(), isEmpty);
        expect(app.controller.state.activeHostId, isNull);
        expect(app.controller.state.notice?.kind, isNot(NoticeKind.forgetUnrevoked));
      }));

  /// Offline, the phone still forgets — and says the desktop must finish it.
  test('forgetting while the backend is down still forgets, and says so', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        app.backend.handler = (method, path, _) =>
            method == 'DELETE' && path.contains('/api/companion/devices/') ? (502, TestBackend.fail('bad gateway')) : null;
        await app.connectTo(host);
        await Future<void>.delayed(const Duration(seconds: 5));
        await app.controller.forgetHost(host.hostId);
        expect(await app.pairedOnDisk(), isEmpty);
        expect(app.controller.state.notice?.kind, NoticeKind.forgetUnrevoked);
      }));

  /// A proxy's 404 page in front of the backend — its own text, or a
  /// gateway's JSON without new-api's `success: false` — says nothing of the
  /// device: the revoke may never have arrived, and the user is told so.
  /// Only the backend's own 404 means it was already gone there.
  for (final (kind, page) in [
    ('a proxy page', 'default backend - 404'),
    ('a gateway JSON page', '{"message":"no Route matched with those values"}'),
    ("the backend's own", TestBackend.fail('设备不存在')),
  ]) {
    test('forgetting when the revoke meets a 404: $kind', () => runFake((_) async {
          final app = TestApp();
          final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
          app.backend.handler = (method, path, _) =>
              method == 'DELETE' && path.endsWith('/api/companion/devices/dev-1') ? (404, page) : null;
          await app.connectTo(host);
          await Future<void>.delayed(const Duration(seconds: 5));
          await app.controller.forgetHost(host.hostId);
          expect(app.backend.log, contains('DELETE /api/companion/devices/dev-1'));
          expect(await app.pairedOnDisk(), isEmpty);
          expect(
            app.controller.state.notice?.kind,
            kind == "the backend's own" ? isNot(NoticeKind.forgetUnrevoked) : NoticeKind.forgetUnrevoked,
          );
        }));
  }

  /// The refresh in front of the revoke answering 404 (a proxy that does not
  /// pass it on) is no "already gone there": the revoke was never sent, and
  /// the user is told the desktop must finish it.
  test('forgetting when the refresh answers 404 says the revoke did not happen', () => runFake((_) async {
        final app = TestApp();
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
        app.backend.handler = (_, path, _) => path.endsWith('/api/user/auth/refresh') ? (404, TestBackend.fail('not found')) : null;
        await app.connectTo(host);
        await Future<void>.delayed(const Duration(seconds: 5));
        await app.backendClient.invalidateAccessToken();
        await app.controller.forgetHost(host.hostId);
        expect(await app.pairedOnDisk(), isEmpty);
        expect(app.backend.log, isNot(contains('DELETE /api/companion/devices/dev-1')));
        expect(app.controller.state.notice?.kind, NoticeKind.forgetUnrevoked);
      }));

  /// The device key: a store that throws on read must never be answered with
  /// a new key, which would make every paired host see a stranger (S27).
  test('a failing secret store does not replace the device key', () => runFake((_) async {
        final app = TestApp();
        final original = await app.controller.identity();
        final again = TestApp(secrets: app.secrets, files: app.files);
        app.secrets.failReadsWith = StateError('keystore busy');
        await expectLater(again.controller.identity(), throwsA(isA<StateError>()));
        app.secrets.failReadsWith = null;
        expect((await again.controller.identity()).pub, original.pub);
      }));
}
