import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skidsense_core/skidsense_core.dart';

/// What only the platform can answer.
class DeviceFacts {
  const DeviceFacts({required this.platform, required this.model, required this.appVersion});

  /// `android` / `ios`, for `hello.app.platform` and `POST /devices`.
  final String platform;

  /// A label for `POST /devices`, e.g. "Google Pixel 9".
  final String model;
  final String appVersion;

  static Future<DeviceFacts> read() async {
    final info = DeviceInfoPlugin();
    var model = '';
    var platform = Platform.operatingSystem;
    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        model = '${android.manufacturer} ${android.model}'.trim();
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        model = ios.name.isNotEmpty ? ios.name : ios.model;
      }
    } catch (_) {}
    var version = '0.1.0';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    if (Platform.isAndroid) platform = 'android';
    if (Platform.isIOS) platform = 'ios';
    return DeviceFacts(platform: platform, model: model, appVersion: version);
  }

  AppInfo get appInfo => AppInfo(name: 'skidsense-mobile', version: appVersion, platform: platform);
}

/// Calls [onChange] whenever the network changes — Wi-Fi joined or left,
/// cellular back — so the connection retries at once instead of waiting out
/// its backoff, and a relay connection looks for the LAN.
StreamSubscription<List<ConnectivityResult>> watchNetwork(VoidCallback onChange) {
  List<ConnectivityResult>? last;
  return Connectivity().onConnectivityChanged.listen((results) {
    if (last != null && !listEquals(last, results)) onChange();
    last = results;
  });
}

/// The app lock: the system's own prompt (fingerprint, face, or the device
/// passcode). With no way to authenticate at all it lets the user in — the
/// lock guards the screen, not a key, and refusing would be a lockout.
class Biometrics {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    if (!await available()) return true;
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

/// The pairing link the desktop shows can be tapped as well as scanned.
///
/// A link is a one-shot *event*: each delivery gets a new [PairingLink.seq],
/// so a second tap of the same link is seen, and a link already acted on is
/// not replayed when the app is rebuilt (S32).
class PairingLink {
  const PairingLink(this.seq, this.text);
  final int seq;
  final String text;
}

class DeepLinks {
  DeepLinks() : _links = AppLinks();

  final AppLinks _links;
  final ValueNotifier<PairingLink?> pending = ValueNotifier(null);
  StreamSubscription<Uri>? _subscription;
  int _seq = 0;

  Future<void> start() async {
    // `uriLinkStream` delivers the launch link first as well.
    _subscription = _links.uriLinkStream.listen((uri) {
      final text = uri.toString();
      if (!text.startsWith('skidsense://')) return;
      pending.value = PairingLink(++_seq, text);
    });
  }

  /// The link has been acted on.
  void consume(PairingLink link) {
    if (identical(pending.value, link)) pending.value = null;
  }

  Future<void> dispose() async => _subscription?.cancel();
}

class PickedFile {
  const PickedFile(this.name, this.mimeType, this.bytes);
  final String name;
  final String? mimeType;
  final Uint8List bytes;
}

/// Picking a file for the composer. The bytes, not a path: the upload
/// protocol takes the content, and a picked document may have no path.
Future<PickedFile?> pickFile() async {
  final files = await FilePicker.pickFiles();
  final file = files.firstOrNull;
  if (file == null) return null;
  // The desktop takes 20 MiB at most; refuse a bigger file before reading it.
  final size = await file.length();
  if (size != null && size > Protocol.maxUpload) throw const RcException('upload-too-large');
  return PickedFile(file.name, _mimeFor(file.extension), await file.readAsBytes());
}

String? _mimeFor(String? extension) => switch (extension?.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'txt' || 'log' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      _ => null,
    };
