import 'dart:async';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'app.dart';
import 'platform/device.dart';
import 'platform/stores.dart';
import 'state/appearance.dart';
import 'state/scope.dart';
import 'ui/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (device, files) = await (DeviceFacts.read(), DirectoryFileStore.open()).wait;
  final appearance = AppearanceController(SharedPreferencesAsync());
  await appearance.restore();

  final secrets = KeystoreSecretStore();
  final backend = BackendClient(
    http: http.Client(),
    secrets: secrets,
    language: () => backendLanguage(appearance.value.language, PlatformDispatcher.instance.locales),
  );
  final relayPath = _RelayPath(backend);
  final carriers = IoCarrierFactory(
    backendBase: () => backend.baseUrl,
    relayPath: relayPath.get,
    bearer: backend.accessToken,
  );
  final controller = AppController(
    backend: backend,
    carriers: carriers,
    secrets: secrets,
    files: files,
    platformName: device.platform,
    deviceModel: device.model,
    appInfo: device.appInfo,
    clientConfig: ClientConfig(connection: ConnectionConfig(app: device.appInfo)),
  );
  final links = DeepLinks();

  runApp(SkidSenseApp(
    services: AppServices(
      controller: controller,
      appearance: appearance,
      biometrics: Biometrics(),
      links: links,
      device: device,
    ),
  ));
  unawaited(controller.start());
  unawaited(links.start());
}

/// `Accept-Language` for the backend, whose messages are shown as they
/// come: the app's language, or the phone's when it follows the system.
String backendLanguage(AppLanguage language, List<Locale> system) => switch (language) {
      AppLanguage.simplifiedChinese => 'zh-CN',
      AppLanguage.traditionalChinese => 'zh-TW',
      AppLanguage.english => 'en',
      AppLanguage.system => switch (resolveLocale(system, const [])) {
          Locale(languageCode: 'zh', scriptCode: 'Hant') => 'zh-TW',
          Locale(languageCode: 'zh') => 'zh-CN',
          _ => 'en',
        },
    };

/// The relay's path from the backend's `/config`, fetched once per server
/// and only when the relay is first wanted.
class _RelayPath {
  _RelayPath(this._backend);

  final BackendClient _backend;
  String? _server;
  Future<String?>? _path;

  Future<String?> get() {
    final server = _backend.baseUrl;
    if (_path == null || _server != server) {
      _server = server;
      _path = _fetch();
    }
    return _path!;
  }

  Future<String?> _fetch() async {
    try {
      return (await _backend.companionConfig()).wsPath;
    } catch (_) {
      // Not cached: the next connection asks again.
      _path = null;
      return null;
    }
  }
}
