import 'dart:convert';

import '../util/json.dart';

class AppInfo {
  const AppInfo({required this.name, required this.version, required this.platform});

  final String name;
  final String version;

  /// `android` / `ios`.
  final String platform;
}

class WelcomeHost {
  const WelcomeHost({this.id = '', this.name = '', this.version = '', this.platform = ''});

  factory WelcomeHost.fromJson(Object? json) {
    final map = asMap(json);
    return WelcomeHost(
      id: map.str('id') ?? '',
      name: map.str('name') ?? '',
      version: map.str('version') ?? '',
      platform: map.str('platform') ?? '',
    );
  }

  final String id;
  final String name;
  final String version;
  final String platform;
}

class WelcomeDevice {
  const WelcomeDevice({this.id = '', this.scopes = const []});

  factory WelcomeDevice.fromJson(Object? json) {
    final map = asMap(json);
    return WelcomeDevice(id: map.str('id') ?? '', scopes: map.strings('scopes'));
  }

  final String id;
  final List<String> scopes;
}

class WelcomeUser {
  const WelcomeUser({this.id = 0, this.name});

  factory WelcomeUser.fromJson(Object? json) {
    final map = asMap(json);
    return WelcomeUser(id: map.integer('id') ?? 0, name: map.str('name'));
  }

  final int id;
  final String? name;
}

/// The host's answer to `hello` (spec §6.1). [methods] lists only what this
/// device may call; [device.scopes] is the effective set, already the grant
/// intersected with the host's own cap (spec §8.3).
class Welcome {
  const Welcome({
    this.v = 1,
    this.host = const WelcomeHost(),
    this.device = const WelcomeDevice(),
    this.user,
    this.methods = const [],
    this.features = const [],
  });

  factory Welcome.fromJson(Map<String, Object?> json) => Welcome(
        v: json.integer('v') ?? 1,
        host: WelcomeHost.fromJson(json['host']),
        device: WelcomeDevice.fromJson(json['device']),
        user: json['user'] is Map ? WelcomeUser.fromJson(json['user']) : null,
        methods: json.strings('methods'),
        features: json.strings('features'),
      );

  final int v;
  final WelcomeHost host;
  final WelcomeDevice device;
  final WelcomeUser? user;
  final List<String> methods;

  /// What the host can do beyond [methods] — new parameters of old methods
  /// (`Features`). Empty from a host that predates the field.
  final List<String> features;

  bool can(String method) => methods.contains(method);
  bool hasScope(String scope) => device.scopes.contains(scope);
  bool supports(String feature) => features.contains(feature);
}

/// Builders for the inner messages the device sends (spec §6).
abstract final class Inner {
  static String hello(AppInfo app, {String? grant, String? ticket}) => jsonEncode({
        't': 'hello',
        'v': [1],
        'app': {'name': app.name, 'version': app.version, 'platform': app.platform},
        // ignore: use_null_aware_elements
        if (ticket != null) 'ticket': ticket else if (grant != null) 'grant': grant,
      });

  static String request(String id, String method, Object? params) => jsonEncode({
        't': 'req',
        'id': id,
        'm': method,
        'p': ?params,
      });

  static String ping(int ts) => jsonEncode({'t': 'ping', 'ts': ts});
  static String pong(int ts) => jsonEncode({'t': 'pong', 'ts': ts});
  static String bye(String reason) => jsonEncode({'t': 'bye', 'reason': reason});
}

/// One `ev` message (spec §6.4).
class RcEvent {
  const RcEvent(this.kind, this.payload);

  final String kind;
  final Object? payload;
}
