import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/skidsense_core.dart';
import 'package:skidsense_core/src/util/json.dart';

import 'fake_host.dart';

/// A stand-in backend on a mock HTTP client, so the real [AppController]
/// can be driven end to end against [FakeHost] over in-memory carriers.
class TestBackend {
  TestBackend({this.base = 'https://backend.example'});

  final String base;

  /// `METHOD /path` of every request, in order.
  final List<String> log = [];

  /// Answers first; whatever it leaves (null) falls through to the basics.
  (int, String)? Function(String method, String path, String body) handler = (_, _, _) => null;

  static String ok(String data) => '{"success":true,"message":"","data":$data}';
  static String fail(String message, [String data = 'null']) => '{"success":false,"message":"$message","data":$data}';
  static int epochSeconds() => clock.now().millisecondsSinceEpoch ~/ 1000;
  static String grant([int ttlSeconds = 3600]) => ok('{"grant":"grant-token","expires_at":${epochSeconds() + ttlSeconds}}');
  static String loginBody(int userId, String name) =>
      '{"access_token":"tok-$userId","access_expires_at":${epochSeconds() + 900},"user":{"id":$userId,"username":"$name"},"session":{"id":"sess-$userId"}}';

  (int, String)? _basics(String path) {
    if (path.endsWith('/api/companion/hosts')) return (200, ok('[]'));
    if (path.endsWith('/api/companion/grant')) return (200, grant());
    if (path.endsWith('/api/companion/config')) return (200, ok('{"enabled":true}'));
    if (path.endsWith('/api/user/auth/logout')) return (200, ok('null'));
    if (path.endsWith('/encryption-key')) return (200, ok('{"enabled":false}'));
    return null;
  }

  BackendClient client(SecretStore secrets) => BackendClient(
        http: MockClient((request) async {
          final path = request.url.path;
          log.add('${request.method} $path');
          final (status, text) = handler(request.method, path, request.body) ?? _basics(path) ?? (404, fail('not found'));
          return http.Response(text, status, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        secrets: secrets,
        defaultBaseUrl: base,
      );
}

/// The real controller over a [TestBackend] and [FakeCarriers], with
/// in-memory stores.
class TestApp {
  TestApp({TestBackend? backend, MemorySecretStore? secrets, MemoryFileStore? files, this.signedInAs = 42})
      : backend = backend ?? TestBackend(),
        secrets = secrets ?? MemorySecretStore(),
        files = files ?? MemoryFileStore() {
    backendClient = this.backend.client(this.secrets);
    controller = AppController(
      backend: backendClient,
      carriers: carriers,
      secrets: this.secrets,
      files: this.files,
      platformName: 'android',
      deviceModel: 'Test Phone',
    );
  }

  final TestBackend backend;
  final MemorySecretStore secrets;
  final MemoryFileStore files;
  final int? signedInAs;
  final FakeCarriers carriers = FakeCarriers();
  late final BackendClient backendClient;
  late final AppController controller;

  /// Seed the stored session (what a phone signed in before a restart has).
  Future<void> signIn({int? accessExpiresAt}) async {
    final userId = signedInAs;
    if (userId == null) return;
    await secrets.putString(
      'auth-session',
      jsonEncode(AuthSession(
        baseUrl: backend.base,
        accessToken: 'tok',
        accessExpiresAt: accessExpiresAt ?? clock.now().millisecondsSinceEpoch + 3600000,
        refreshCookie: 'cookie',
        sessionId: 'sess',
        userId: userId,
        username: 'user$userId',
      ).toJson()),
    );
  }

  Future<void> start() async {
    await signIn();
    await controller.start();
  }

  Future<List<PairedHost>> pairedOnDisk() async {
    final raw = await files.read('paired-hosts.json');
    return raw == null ? const [] : decodeObjects(jsonDecode(raw), PairedHost.fromJson);
  }

  /// Pair [host] on disk, start, connect over the LAN, and wait until the
  /// connection is up.
  Future<void> connectTo(FakeHost host, {String deviceId = 'dev-1'}) async {
    await writePaired(files, [pairedHost(host.hostId, host.hostStatic, deviceId, base: backend.base)]);
    carriers.lan = (_) => host;
    await start();
    await controller.connect(host.hostId);
    await controller.states.firstWhere((state) => state.connected, timeout: const Duration(minutes: 1));
  }

  static Future<void> writePaired(MemoryFileStore files, List<PairedHost> hosts) =>
      files.write('paired-hosts.json', jsonEncode([for (final host in hosts) host.toJson()]));

  /// A stored pairing; [userId] 0 describes a record from before pairings
  /// carried their account.
  static PairedHost pairedHost(
    String hostId,
    KeyPair key,
    String deviceId, {
    String base = 'https://backend.example',
    String? name,
    int userId = 42,
  }) =>
      PairedHost(
        hostId: hostId,
        hostKey: B64u.encode(key.pub),
        deviceId: deviceId,
        name: name ?? hostId,
        machine: name ?? hostId,
        lanAddrs: const ['192.168.1.20'],
        lanPort: 47290,
        server: base,
        userId: userId,
        pairedAt: 1,
      );

  static String newHostId() => B64u.encode(Primitives.randomBytes(16));
}
