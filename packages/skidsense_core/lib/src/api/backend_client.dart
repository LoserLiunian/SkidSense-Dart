import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../store/stores.dart';
import '../util/json.dart';
import '../util/state_value.dart';
import 'backend_models.dart';
import 'password_envelope.dart';

/// A backend failure, with a [code] the app words and — when the server
/// explained itself — the server's own [message] (already in the language
/// asked for with `Accept-Language`).
///
/// Codes: `server` (the envelope said `success:false`; see [message]),
/// `not-signed-in`, `session-expired`, `unreachable` (no answer from
/// [base]), `http` ([status] with no message), `unparsable` (not JSON — a
/// wrong address, a proxy page), `bad-data` (JSON of the wrong shape),
/// `no-credentials` (a login answered without a token),
/// `verification-incomplete` (a second factor was asked for without a flow),
/// `verify-failed`.
class BackendException implements Exception {
  const BackendException(this.code, {this.message, this.status = 0, this.data, this.base, this.cause});

  final String code;
  final String? message;
  final int status;
  final Object? data;
  final String? base;
  final Object? cause;

  @override
  String toString() =>
      'BackendException($code${status == 0 ? '' : ', HTTP $status'}${message == null ? '' : ', “$message”'}${base == null ? '' : ', $base'})';
}

class _Raw {
  const _Raw(this.status, this.json, this.setCookies);

  final int status;
  final Map<String, Object?>? json;
  final List<String> setCookies;
}

/// The phone's new-api client: login (spec §12, mirroring the desktop's
/// `src/main/backend.ts`) and the companion API (spec §9).
///
/// Auth is a short-lived bearer plus the `new_api_refresh` cookie. There is
/// no cookie jar: that one cookie is captured from `Set-Cookie` by hand and
/// replayed on refresh with `X-Auth-Session`. Authenticated calls refresh
/// once on a 401 and retry. Redirects are not followed — a redirect to
/// another host would be a misconfigured deployment, not something to send
/// the bearer to.
class BackendClient {
  BackendClient({
    required this._http,
    required this._secrets,
    this.defaultBaseUrl = defaultBase,
    String Function()? language,
  }) : _language = language ?? (() => 'zh-CN');

  static const defaultBase = 'https://ai.surise.cn';
  static const _sessionKey = 'auth-session';
  static const _refreshCookie = 'new_api_refresh';
  static const _accessFallback = Duration(minutes: 14);

  final http.Client _http;
  final SecretStore _secrets;
  final String Function() _language;
  String defaultBaseUrl;

  final StateValue<AuthSession?> _session = StateValue<AuthSession?>(null);

  /// The signed-in session; null when signed out.
  StateValue<AuthSession?> get session => _session;

  String get baseUrl => _session.value?.baseUrl ?? defaultBaseUrl;

  Future<bool>? _refreshing;

  static int _now() => clock.now().millisecondsSinceEpoch;

  /// Read the stored session back. A store that cannot be read leaves the
  /// phone signed out rather than failing the app's start.
  Future<void> restore() async {
    try {
      final text = await _secrets.getString(_sessionKey);
      if (text == null) return;
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) _session.value = AuthSession.fromJson(json);
    } catch (_) {}
  }

  Future<void> _save(AuthSession? session) async {
    if (session == null) {
      await _secrets.delete(_sessionKey);
    } else {
      await _secrets.putString(_sessionKey, jsonEncode(session.toJson()));
    }
    _session.value = session;
  }

  // --- low level ---------------------------------------------------------------

  Future<_Raw> _raw(
    String base,
    String path, {
    String method = 'GET',
    Map<String, String?> query = const {},
    Object? body,
    String? bearer,
    String? cookie,
    String? sessionId,
  }) async {
    final root = base.trim();
    final query0 = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    final parsed = Uri.parse('${root.endsWith('/') ? root.substring(0, root.length - 1) : root}/$path');
    final uri = query0.isEmpty ? parsed : parsed.replace(queryParameters: {...parsed.queryParameters, ...query0});
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json'
      // new-api picks its message language from the user's setting, then this
      // header, then English: a refusal must arrive in the app's language.
      ..headers['Accept-Language'] = _language();
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (cookie != null) request.headers['Cookie'] = cookie;
    if (sessionId != null) request.headers['X-Auth-Session'] = sessionId;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request)).timeout(const Duration(seconds: 20));
    } catch (error) {
      throw BackendException('unreachable', base: root, cause: error);
    }
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) json = decoded;
    } catch (_) {}
    return _Raw(response.statusCode, json, response.headersSplitValues['set-cookie'] ?? const []);
  }

  static Object? _unwrap(_Raw res, String base) {
    final json = res.json;
    if (json == null) {
      throw res.status >= 400
          ? BackendException('http', status: res.status, base: base)
          : BackendException('unparsable', status: res.status, base: base);
    }
    if (json['success'] == false || res.status >= 400) {
      final message = json.str('message');
      if (message != null && message.trim().isNotEmpty) {
        throw BackendException('server', message: message, status: res.status, data: json['data'], base: base);
      }
      throw BackendException('http', status: res.status, data: json['data'], base: base);
    }
    return json['data'];
  }

  /// A current access token, refreshing first when it is missing or about to expire.
  Future<String?> accessToken() async {
    final current = _session.value;
    if (current == null) return null;
    if (current.accessToken.isNotEmpty && current.accessExpiresAt > _now() + 30000) return current.accessToken;
    return await refresh() ? _session.value?.accessToken : null;
  }

  /// Drop the access token so the next call refreshes (the relay said 401).
  Future<void> invalidateAccessToken() async {
    final current = _session.value;
    if (current != null) await _save(current.withExpiry(0));
  }

  Future<Object?> _authed(String path, {String method = 'GET', Map<String, String?> query = const {}, Object? body}) async {
    final base = _session.value?.baseUrl;
    if (base == null) throw const BackendException('not-signed-in');
    final token = await accessToken();
    if (token == null) throw const BackendException('session-expired', status: 401);
    final res = await _raw(base, path, method: method, query: query, body: body, bearer: token);
    if (res.status == 401) {
      await invalidateAccessToken();
      final again = await accessToken();
      if (again == null) throw const BackendException('session-expired', status: 401);
      return _unwrap(await _raw(base, path, method: method, query: query, body: body, bearer: again), base);
    }
    return _unwrap(res, base);
  }

  static T _decode<T>(Object? data, T Function(Map<String, Object?> json) decode) {
    if (data is! Map<String, Object?>) throw const BackendException('bad-data');
    try {
      return decode(data);
    } catch (error) {
      throw BackendException('bad-data', cause: error);
    }
  }

  static List<T> _decodeList<T>(Object? data, T Function(Map<String, Object?> json) decode) {
    if (data == null) return const [];
    if (data is! List) throw const BackendException('bad-data');
    return decodeObjects(data, decode);
  }

  // --- login (spec §12) ----------------------------------------------------------

  Future<ServerStatus> status(String base) async {
    final clean = _clean(base);
    return _decode(_unwrap(await _raw(clean, 'api/status'), clean), ServerStatus.fromJson);
  }

  static String _clean(String base) {
    var clean = base.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  Future<Map<String, String>> _passwordFields(String base, String password) async {
    final key = _unwrap(await _raw(base, 'api/user/login/encryption-key'), base);
    if (key is! Map<String, Object?> || key['enabled'] != true) return {'password': password};
    final publicKey = key.str('public_key') ?? '';
    final kid = key.str('kid') ?? '';
    if (publicKey.isEmpty || kid.isEmpty) return {'password': password};
    return {'password_encrypted': PasswordEnvelope.encrypt(password, publicKey, kid), 'encryption_key_id': kid};
  }

  /// Returns null when signed in, or the second-factor challenge. [geetest]
  /// is the JSON of GeeTest v4's `getValidate()`; [turnstile] a Turnstile token.
  Future<LoginChallenge?> login(String base, String username, String password, {String? geetest, String? turnstile}) async {
    final clean = _clean(base);
    final fields = await _passwordFields(clean, password);
    final res = await _raw(
      clean,
      'api/user/login',
      method: 'POST',
      query: {'geetest': geetest, 'turnstile': turnstile},
      body: {'username': username, ...fields},
    );
    final data = asMap(_unwrap(res, clean));
    final token = data.str('access_token');
    if (token != null && token.isNotEmpty) {
      await _storeSession(clean, data, res.setCookies);
      return null;
    }
    if (data['require_verification'] == true) {
      final flow = data.str('flow_token');
      if (flow == null) throw const BackendException('verification-incomplete');
      return LoginChallenge(flow, data.objects('methods', LoginMethod.fromJson));
    }
    throw const BackendException('no-credentials');
  }

  /// Complete a challenge with a TOTP or a backup code.
  Future<void> verifyLogin(String base, String flowToken, String code) async {
    final clean = _clean(base);
    final res = await _raw(
      clean,
      'api/user/login/verify',
      method: 'POST',
      body: {'flow_token': flowToken, 'method': '2fa', 'code': code.trim()},
    );
    final data = asMap(_unwrap(res, clean));
    if ((data.str('access_token') ?? '').isEmpty) throw const BackendException('verify-failed');
    await _storeSession(clean, data, res.setCookies);
  }

  /// Mint a fresh access token from the refresh cookie. Single-flight.
  Future<bool> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final current = _session.value;
    if (current == null) return false;
    if (current.accessExpiresAt > _now() + 30000 && current.accessToken.isNotEmpty) return true;
    final cookie = current.refreshCookie;
    if (cookie == null) return false;
    final _Raw res;
    try {
      res = await _raw(
        current.baseUrl,
        'api/user/auth/refresh',
        method: 'POST',
        cookie: '$_refreshCookie=$cookie',
        sessionId: current.sessionId,
      );
    } on BackendException {
      return false;
    }
    final json = res.json;
    if (json == null || json['success'] == false) {
      // A refused refresh token is a real logout, not a blip.
      if (res.status == 401 || res.status == 403) await _save(null);
      return false;
    }
    final data = json.obj('data');
    if (data == null || (data.str('access_token') ?? '').isEmpty) return false;
    await _storeSession(current.baseUrl, data, res.setCookies);
    return true;
  }

  Future<void> logout() async {
    final current = _session.value;
    if (current == null) return;
    try {
      await _raw(
        current.baseUrl,
        'api/user/auth/logout',
        method: 'POST',
        bearer: current.accessToken,
        cookie: current.refreshCookie == null ? null : '$_refreshCookie=${current.refreshCookie}',
        sessionId: current.sessionId,
      );
    } catch (_) {
      // A failed server-side revoke must not strand the user signed in locally.
    } finally {
      await _save(null);
    }
  }

  static final RegExp _cookiePattern = RegExp('(?:^|[;,]\\s*)$_refreshCookie=([^;,\\s]+)');

  Future<void> _storeSession(String base, Map<String, Object?> data, List<String> setCookies) async {
    final user = data.obj('user');
    final session = data.obj('session');
    final sessionId = session?.str('id') ?? session?.str('sid');
    String? cookie;
    for (final header in setCookies) {
      final match = _cookiePattern.firstMatch(header);
      if (match != null) {
        cookie = match.group(1);
        break;
      }
    }
    final previous = _session.value;
    cookie ??= previous?.refreshCookie;
    final raw = data['access_expires_at'];
    final expires = raw is num ? (raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt()) : _now() + _accessFallback.inMilliseconds;
    await _save(AuthSession(
      baseUrl: base,
      accessToken: data.str('access_token') ?? '',
      accessExpiresAt: expires,
      refreshCookie: cookie,
      sessionId: sessionId ?? previous?.sessionId,
      userId: user?.number('id') ?? previous?.userId ?? 0,
      username: user?.str('username') ?? previous?.username ?? '',
    ));
  }

  Future<UserInfo> self() async => _decode(await _authed('api/user/self'), UserInfo.fromJson);

  // --- companion (spec §9) ---------------------------------------------------------

  Future<CompanionConfig> companionConfig() async => _decode(await _authed('api/companion/config'), CompanionConfig.fromJson);

  Future<List<HostRow>> hosts() async => _decodeList(await _authed('api/companion/hosts'), HostRow.fromJson);

  Future<void> deleteHost(String hostId) => _authed('api/companion/hosts/${_segment(hostId)}', method: 'DELETE');

  /// Register this phone's static key for a host. A 409 means this exact key
  /// is already active there; [BackendException.data] then names the device.
  Future<DeviceRegistration> registerDevice(String hostId, String name, String publicKey, String platform) async => _decode(
        await _authed('api/companion/devices', method: 'POST', body: {
          'host_id': hostId,
          'name': name,
          'public_key': publicKey,
          'platform': platform,
        }),
        DeviceRegistration.fromJson,
      );

  Future<List<DeviceRow>> devices(String hostId) async =>
      _decodeList(await _authed('api/companion/devices', query: {'host_id': hostId}), DeviceRow.fromJson);

  Future<DeviceRow> updateDevice(String deviceId, {String? name, List<String>? scopes}) async => _decode(
        await _authed('api/companion/devices/${_segment(deviceId)}', method: 'PATCH', body: {
          'name': ?name,
          'scopes': ?scopes,
        }),
        DeviceRow.fromJson,
      );

  Future<void> revokeDevice(String deviceId) => _authed('api/companion/devices/${_segment(deviceId)}', method: 'DELETE');

  Future<GrantResponse> grant(String hostId, String deviceId) async => _decode(
        await _authed('api/companion/grant', method: 'POST', body: {'host_id': hostId, 'device_id': deviceId}),
        GrantResponse.fromJson,
      );

  Future<List<HistoryKeyRow>> historyKeys(String hostId, String deviceId) async => _decodeList(
        await _authed('api/companion/history/keys', query: {'host_id': hostId, 'device_id': deviceId}),
        HistoryKeyRow.fromJson,
      );

  Future<List<HistorySessionRow>> historySessions(String hostId, {int since = 0}) async => _decodeList(
        await _authed('api/companion/history/sessions', query: {'host_id': hostId, 'since': '$since'}),
        HistorySessionRow.fromJson,
      );

  Future<HistoryBlobRow> historyBlob(String hostId, String sessionKey) async => _decode(
        await _authed('api/companion/history/sessions/blob', query: {'host_id': hostId, 'session_key': sessionKey}),
        HistoryBlobRow.fromJson,
      );

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Ids are base64url (spec §9): nothing to escape, but refuse anything else.
  static String _segment(String id) {
    if (!_idPattern.hasMatch(id)) throw ArgumentError.value(id, 'id', 'not an id');
    return id;
  }
}
