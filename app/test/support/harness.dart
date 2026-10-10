import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_app/app.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/platform/device.dart';
import 'package:skidsense_app/state/appearance.dart';
import 'package:skidsense_app/state/scope.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/theme/app_theme.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

const testBase = 'https://ai.surise.cn';

/// Golden images depend on the fonts installed; they are made and compared
/// on macOS only.
final bool goldensSupported = Platform.isMacOS;

bool _fontsLoaded = false;

/// Roboto, the Material icons and a CJK font, so goldens show real text
/// instead of the test font's boxes.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  // `flutter test` sets FLUTTER_ROOT; otherwise the tester sits at
  // <root>/bin/cache/artifacts/engine/<platform>/flutter_tester.
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final material = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String path) async => ByteData.sublistView(await File(path).readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold', 'Light']) {
    roboto.addFont(read('$material/Roboto-$weight.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('$material/MaterialIcons-Regular.otf'))).load();
  // Bundled (OFL), so code looks the same on every macOS release.
  final mono = FontLoader('monospace');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    mono.addFont(read('test/fonts/RobotoMono-$weight.ttf'));
  }
  await mono.load();
  // Ships with macOS itself, so CI runners have it too.
  const cjk = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf';
  if (File(cjk).existsSync()) await (FontLoader('CJK')..addFont(read(cjk))).load();
}

/// An in-memory backend: answers what the screens ask for.
class FakeBackend {
  final List<HostRow> hosts = [];
  final List<Map<String, Object?>> devices = [];

  /// The scopes `/config` lists; null leaves them out, as a backend from
  /// before the list.
  List<String>? scopes;

  /// The `scopes` of every device `PATCH`, in order.
  final List<Object?> scopePatches = [];

  /// The account's API keys (`/api/token/`), newest first, as new-api lists
  /// them: the key masked.
  final List<Map<String, Object?>> tokens = [
    {'id': 12, 'name': 'Laptop', 'key': 'Xq7f**********u2Lw', 'status': 1, 'unlimited_quota': true, 'remain_quota': 0, 'used_quota': 1250000, 'expired_time': -1, 'group': ''},
    {'id': 9, 'name': 'CI runner', 'key': 'b81K**********pQ0e', 'status': 1, 'unlimited_quota': false, 'remain_quota': 2500000, 'used_quota': 400000, 'expired_time': -1, 'group': 'vip'},
    {'id': 4, 'name': 'Old test', 'key': 'Mm3c**********Zt9a', 'status': 2, 'unlimited_quota': false, 'remain_quota': 0, 'used_quota': 500000, 'expired_time': -1, 'group': ''},
  ];

  /// The groups a key may go in (`/api/user/self/groups`).
  Map<String, Object?> tokenGroups = {
    'default': {'desc': 'Default', 'ratio': 1},
    'vip': {'desc': 'Faster, pricier', 'ratio': 1.5},
  };

  /// Who `/api/user/self` says is signed in, the quotas in new-api's units
  /// (500000 to the dollar): $1,234.56 left, $86.21 spent.
  Map<String, Object?> self = {
    'id': 7,
    'username': 'liunian',
    'display_name': 'liunian',
    'group': 'default',
    'aff_code': 'Xy7k',
    'quota': 617280000,
    'used_quota': 43105000,
  };

  /// How many more requests to each path to refuse, in the server's own words.
  final Map<String, int> failures = {};

  /// No answer to anything, as with no network.
  bool offline = false;

  /// What each key creation sent.
  final List<Map<String, Object?>> createdTokens = [];

  /// The whole key `POST /api/token/:id/key` answers with (new-api keeps it
  /// without `sk-`): 48 characters, as new-api makes them — 51 with `sk-`.
  static const revealedKey = 'Xq7fJd02nRkVb5Tq9PwYc3LmHa8Ze1UsGs4Nc6Kp0Rt7u2Lw';

  static String ok(Object? data) => jsonEncode({'success': true, 'message': '', 'data': data});

  http.Client client() => MockClient((request) async {
        if (offline) throw http.ClientException('no network', request.url);
        final path = request.url.path;
        if ((failures[path] ?? 0) > 0) {
          failures[path] = failures[path]! - 1;
          return http.Response(jsonEncode({'success': false, 'message': 'Database is busy', 'data': null}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        final token = RegExp(r'^/api/token/(\d+)(/key)?$').firstMatch(path);
        if (request.method == 'POST' && path == '/api/token/') {
          final sent = jsonDecode(request.body) as Map<String, Object?>;
          createdTokens.add(sent);
          final id = tokens.fold<int>(0, (top, row) => (row['id']! as int) > top ? row['id']! as int : top) + 1;
          tokens.insert(0, {...sent, 'id': id, 'key': 'Nw4p**********k8Rd', 'status': 1, 'used_quota': 0});
          return http.Response(ok(null), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.method == 'POST' && token != null && token.group(2) != null) {
          return http.Response(ok({'key': revealedKey}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.method == 'DELETE' && token != null) {
          tokens.removeWhere((row) => '${row['id']}' == token.group(1));
          return http.Response(ok(null), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.method == 'PATCH' && path.startsWith('/api/companion/devices/')) {
          final sent = (jsonDecode(request.body) as Map<String, Object?>)['scopes'];
          scopePatches.add(sent);
          final row = devices.firstWhere((device) => path.endsWith('/${device['device_id']}'));
          if (sent != null) row['scopes'] = sent;
          return http.Response(ok(row), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        final body = switch (path) {
          '/api/status' => ok({'turnstile_check': false, 'geetest_check': false, 'system_name': 'Surise'}),
          '/api/companion/hosts' => ok([
              for (final host in hosts)
                {
                  'host_id': host.hostId,
                  'name': host.name,
                  'platform': host.platform,
                  'online': host.online,
                  'lan_addrs': host.lanAddrs,
                  'lan_port': host.lanPort,
                  'last_seen_at': host.lastSeenAt,
                },
            ]),
          '/api/companion/config' => ok({'enabled': true, 'scopes': ?scopes}),
          '/api/companion/grant' => ok({'grant': 'grant-token', 'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}),
          '/api/token/' => ok({'items': tokens, 'total': tokens.length}),
          '/api/user/self' => ok(self),
          '/api/user/self/groups' => ok(tokenGroups),
          _ when path.endsWith('/devices') => ok(devices),
          _ => jsonEncode({'success': false, 'message': 'not found', 'data': null}),
        };
        return http.Response(body, 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

class _NoCarriers implements CarrierFactory {
  @override
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout}) async =>
      throw const CarrierUnavailable('test');
}

/// The phone's unlock, answered [ok] without asking anyone; [reasons] says
/// what each ask was for.
class TestUnlock extends Biometrics {
  TestUnlock(this.ok);

  final bool ok;
  final List<String> reasons = [];

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return ok;
  }
}

/// The real controller over [FakeBackend] and in-memory stores.
class TestServices {
  TestServices({Appearance appearance = const Appearance(), CarrierFactory? carriers, Biometrics? biometrics})
      : appearance = AppearanceController(null)..value = appearance {
    controller = AppController(
      backend: BackendClient(http: backend.client(), secrets: secrets, defaultBaseUrl: testBase),
      carriers: carriers ?? _NoCarriers(),
      secrets: secrets,
      files: files,
      platformName: 'android',
      deviceModel: 'Pixel 9 Pro XL',
    );
    services = AppServices(
      controller: controller,
      appearance: this.appearance,
      biometrics: biometrics ?? Biometrics(),
      links: DeepLinks(),
      device: const DeviceFacts(platform: 'android', model: 'Pixel 9 Pro XL', appVersion: '1.0.0'),
    );
  }

  final FakeBackend backend = FakeBackend();
  final MemorySecretStore secrets = MemorySecretStore();
  final MemoryFileStore files = MemoryFileStore();
  final AppearanceController appearance;
  late final AppController controller;
  late final AppServices services;

  /// A stored session, as a phone signed in before a restart has.
  Future<void> signIn({String username = 'liunian'}) => secrets.putString(
        'auth-session',
        jsonEncode(AuthSession(
          baseUrl: testBase,
          accessToken: 'tok',
          accessExpiresAt: DateTime.now().millisecondsSinceEpoch + 3600000,
          refreshCookie: 'cookie',
          sessionId: 'sess',
          userId: 7,
          username: username,
        ).toJson()),
      );

  Future<void> pair(List<PairedHost> hosts) =>
      files.write('paired-hosts.json', jsonEncode([for (final host in hosts) host.toJson()]));
}

/// [child] in the app's own theme, localisations and scope.
Widget harness(
  TestServices services,
  Widget child, {
  DesignStyle style = DesignStyle.expressive,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) {
  final appearance = services.appearance.value = services.appearance.value.copyWith(style: style);
  final theme = AppTheme.build(style, AppTheme.scheme(appearance, brightness), fontFamilyFallback: const ['CJK']);
  return AppScope(
    services: services.services,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      builder: textScale == 1
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
      home: child,
    ),
  );
}

/// Advances the fake clock in steps: indicators loop forever, so
/// pumpAndSettle would not return.
Future<void> settle(WidgetTester tester, {int rounds = 15, Duration step = const Duration(milliseconds: 50)}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(step);
  }
}

/// Pumps until [done], or fails after [max] steps.
Future<void> pumpUntil(WidgetTester tester, bool Function() done, {int max = 400}) async {
  for (var i = 0; i < max && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'condition not reached in ${max * 50} ms of fake time');
}

/// Phone size, at the emulator's density.
void phoneSurface(WidgetTester tester, {Size size = const Size(412, 915)}) {
  tester.view.physicalSize = size * 2.625;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}
