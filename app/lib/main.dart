import 'dart:async';
import 'dart:io' show HttpClient;
import 'dart:ui';

import 'package:http/io_client.dart';
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
    // The client bounds each whole exchange at 20 s; this gives up sooner on
    // an address that never takes the connection (the platform's own limit
    // is about two minutes of SYN retries).
    http: IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 10)),
    secrets: secrets,
    language: () => backendLanguage(appearance.value.language, PlatformDispatcher.instance.locales),
  );
  final carriers = IoCarrierFactory(
    backendBase: () => backend.baseUrl,
    relayPath: backend.relayPath,
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
