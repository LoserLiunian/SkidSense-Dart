import 'dart:convert';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

/// The phone's own devices panel (spec §8.5, §9): a backend refuses a whole
/// `PATCH` that names a scope it does not know, so one is never sent — and
/// which it knows comes from its `/config`, the eight from before `settings`
/// when that lists none.
void main() {
  /// Connected, with the devices read. [listed] is what `/config` says the
  /// backend knows (null: a backend from before the list) — or it fails,
  /// [configFails]; dev-2 holds [held].
  Future<(TestApp, List<Object?>)> rig({
    List<String>? listed,
    bool configFails = false,
    List<String> held = const ['sessions', 'prompt'],
  }) async {
    final patches = <Object?>[];
    final app = TestApp();
    app.backend.handler = (method, path, body) {
      if (path.endsWith('/api/companion/config')) {
        return configFails ? (502, 'Bad Gateway') : (200, TestBackend.ok(jsonEncode({'enabled': true, 'scopes': ?listed})));
      }
      if (method == 'GET' && path.endsWith('/api/companion/devices')) {
        return (200, TestBackend.ok(jsonEncode([
          {'device_id': 'dev-1', 'scopes': Scopes.byDefault, 'status': 'active'},
          {'device_id': 'dev-2', 'scopes': held, 'status': 'active'},
        ])));
      }
      if (method == 'PATCH' && path.endsWith('/api/companion/devices/dev-2')) {
        patches.add((jsonDecode(body) as Map<String, Object?>)['scopes']);
        return (200, TestBackend.ok(jsonEncode({'device_id': 'dev-2', 'status': 'active'})));
      }
      return null;
    };
    final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())
      ..handler = (method, params) async => method == 'workspaces.list' || method == 'sessions.list' ? <Object?>[] : true;
    await app.connectTo(host);
    await app.controller.loadDevices();
    return (app, patches);
  }

  test('a backend that lists no scopes knows the eight from before settings', () {
    expect(Scopes.known(null), Scopes.legacy);
    expect(Scopes.known(null), isNot(contains(Scopes.settings)));
    expect(Scopes.known(const ['sessions', 'settings']), ['sessions', 'settings']);
  });

  test('settings is never sent to a backend that does not know it', () => runFake((_) async {
        final (app, patches) = await rig();
        expect(app.controller.state.serverScopes, Scopes.legacy, reason: 'read: a backend from before the list');
        await app.controller.setDeviceScopes('dev-2', const ['sessions', 'prompt', 'settings']);
        expect(patches, [
          ['sessions', 'prompt'],
        ], reason: 'the old backend would refuse the whole request');
        app.controller.disconnect();
      }));

  test('a backend that lists settings gets it, and keeps what this build does not know', () => runFake((_) async {
        final (app, patches) = await rig(listed: [...Scopes.all, 'later']);
        expect(app.controller.state.serverScopes, [...Scopes.all, 'later']);
        await app.controller.setDeviceScopes('dev-2', const ['sessions', 'settings', 'later', 'unheard-of']);
        expect(patches, [
          ['sessions', 'settings', 'later'],
        ]);
        app.controller.disconnect();
      }));

  test('a scope the device holds is sent back, though the scopes could not be read', () => runFake((_) async {
        final (app, patches) = await rig(configFails: true, held: const ['sessions', 'settings']);
        expect(app.controller.state.serverScopes, isNull);
        await app.controller.setDeviceScopes('dev-2', const ['sessions', 'settings']);
        expect(patches, [
          ['sessions', 'settings'],
        ], reason: 'a backend that granted it knows it: leaving it out would take it away');
        app.controller.disconnect();
      }));

  test('signing out forgets which scopes the backend knew', () => runFake((_) async {
        final (app, _) = await rig(listed: Scopes.all);
        expect(app.controller.state.serverScopes, Scopes.all);
        await app.controller.logout();
        expect(app.controller.state.serverScopes, isNull);
      }));
}
