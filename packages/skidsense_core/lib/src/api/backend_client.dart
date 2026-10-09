import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, OSError, SocketException;

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../store/stores.dart';
import '../util/json.dart';
import '../util/state_value.dart';
import 'backend_models.dart';
import 'password_envelope.dart';
import 'server_policy.dart';

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
///
/// `session-expired` means there is no session left to use: the server
/// refused the refresh cookie. A refresh that could not be settled — no
/// answer, a 5xx, a 429, a 409 — keeps its own code, and the session, and
/// is [fromRefresh].
class BackendException implements Exception {
  const BackendException(
    this.code, {
    this.message,
    this.status = 0,
    this.data,
    this.base,
    this.cause,
    this.errorCode,
    this.retryAfter,
    this.fromRefresh = false,
  });

  final String code;
  final String? message;
  final int status;
  final Object? data;
  final String? base;
  final Object? cause;

  /// The envelope's own `code` (`COMPANION_DISABLED`, `AUTH_REFRESH_RACE`, …).
  final String? errorCode;

  /// The answer's `Retry-After`, in seconds; mostly a 429's, which comes
  /// without a body. On a refresh failed with a 5xx, how long until the next
  /// one is sent (see [BackendClient._refreshPause]).
  final Duration? retryAfter;

  /// The refresh in front of the call failed, and the call was never sent:
  /// [status] and [errorCode] are the refresh endpoint's, and say nothing
  /// of what the call would have answered — a 409 or a 404 here is no
  /// device revoked or gone.
  final bool fromRefresh;

  BackendException _asRefresh([Duration? wait]) => BackendException(
        code,
        message: message,
        status: status,
        data: data,
        base: base,
        cause: cause,
        errorCode: errorCode,
        retryAfter: wait ?? retryAfter,
        fromRefresh: true,
      );

  @override
  String toString() => 'BackendException(${[
        code,
        if (fromRefresh) 'refresh',
        if (status != 0) 'HTTP $status',
        ?errorCode,
        if (message != null) '“$message”',
        if (retryAfter != null) 'retry in ${retryAfter!.inSeconds} s',
        ?base,
      ].join(', ')})';
}

class _Raw {
  const _Raw(this.status, this.json, this.setCookies, {required this.receivedAt, this.date, this.retryAfter});

  final int status;
  final Map<String, Object?>? json;
  final List<String> setCookies;

  /// When the answer came, on this phone's clock (epoch ms).
  final int receivedAt;

  /// The answer's `Date`: when it left, on the server's clock.
  final DateTime? date;
  final Duration? retryAfter;
}

/// The phone's new-api client: login (spec §12, mirroring the desktop's
/// `src/main/backend.ts`) and the companion API (spec §9).
///
/// Auth is a short-lived bearer plus the `new_api_refresh` cookie. There is
/// no cookie jar: that one cookie is captured from `Set-Cookie` by hand and
/// replayed on refresh with `X-Auth-Session` and the backend's own `Origin`
/// (logout likewise). Authenticated calls refresh
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

  /// The whole exchange: connecting, TLS, waiting for the headers, the body.
  static const _timeout = Duration(seconds: 20);

  /// The server rotates the refresh cookie before it answers, and takes the
  /// old one back — for the same new one — for 30 s; after that the old one
  /// is reuse, and reuse revokes the whole session. A refresh whose answer
  /// may have been lost is sent again at these points after the first send,
  /// the last a margin inside that window; one that passed while the send
  /// before was still out is skipped. A backend that rotated and then went
  /// down behind its proxy, as in a restart, answers 502 for ten or twenty
  /// seconds: the old cookie is taken back after it.
  static const _refreshResends = [Duration(seconds: 2), Duration(seconds: 7), Duration(seconds: 15), Duration(seconds: 24)];

  /// A refresh whose sends ended in a 5xx is not followed by another for the
  /// same session for this long, doubled for every such refresh in a row up
  /// to [_refreshPauseMax], and back to this at the first answer that settles
  /// anything (2xx, 401, 403). Whoever asks meanwhile gets that failure
  /// again, its [BackendException.retryAfter] the time left. Every send counts
  /// against the session's own refresh limit — new-api's AuthSessionRateLimit,
  /// 60 in 20 minutes, counts before the handler runs, a 500 as well: five
  /// sends and then 1, 2, 4, 5, 5 minutes' pause are some 30 in 20 minutes of
  /// a failing backend. No answer, or a 429, pauses nothing.
  static const _refreshPause = Duration(minutes: 1);
  static const _refreshPauseMax = Duration(minutes: 5);

  /// The pause before a failed keystore write is made again, doubled for
  /// every failure after it, up to the second (see [_persist]).
  static const _persistRetry = Duration(seconds: 2);
  static const _persistRetryMax = Duration(minutes: 5);

  final http.Client _http;
  final SecretStore _secrets;
  final String Function() _language;
  String defaultBaseUrl;

  final StateValue<AuthSession?> _session = StateValue<AuthSession?>(null);

  /// The signed-in session; null when signed out.
  StateValue<AuthSession?> get session => _session;

  String get baseUrl => _session.value?.baseUrl ?? defaultBaseUrl;

  Future<bool>? _refreshing;
  Future<void> _persisting = Future.value();

  /// Bumped by every [_persist]: a failed write is made again only until a
  /// later one takes over, with retries of its own.
  int _persistGeneration = 0;

  /// The last refresh that ended in a 5xx: the session it was for (server
  /// and cookie), until when the pause after it lasts, on [_elapsed], and
  /// how long that pause was (see [_refreshPause]).
  ({String base, String cookie, int until, Duration pause, BackendException error})? _refreshHeld;

  static int _now() => clock.now().millisecondsSinceEpoch;

  /// Time that only moves forward, for the refresh's resends and pauses: the
  /// platform's stopwatch — a phone's clock can be set back — or, under a
  /// clock a test put in place, that clock's.
  final Stopwatch _stopwatch = (identical(clock, const Clock()) ? Stopwatch() : clock.stopwatch())..start();

  int _elapsed() => _stopwatch.elapsedMilliseconds;

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

  /// A session goes into memory first, where every caller reads it, at once;
  /// then to the keystore. A slow write can then not keep a rotated cookie
  /// from the next refresh, and a failed one leaves it in memory until the
  /// write is made again (see [_persist]).
  ///
  /// A sign-out leaves the keystore first and memory after, the order it has
  /// always had: the app tells a sign-out it asked for from one the server
  /// forced by whether it still shows a user when [session] turns null.
  Future<void> _save(AuthSession? session) async {
    if (session == null) {
      await _persist(clear: true);
      _session.value = null;
    } else {
      _session.value = session;
      await _persist();
    }
  }

  /// One keystore write at a time, each of the latest session, so none lands
  /// last with an older one. A failed write is made again (see
  /// [_persistRetry]) until it lands or a later save takes over — not left
  /// for the next refresh some 14 minutes on: until it lands, a process
  /// killed in the background comes back with the cookie the server has
  /// rotated away, and past the 30 s replay window sending that is reuse,
  /// which revokes the whole session.
  Future<void> _persist({bool clear = false}) => _write(++_persistGeneration, clear: clear);

  Future<void> _write(int generation, {bool clear = false, Duration? waited}) => _persisting = _persisting.then((_) async {
        final latest = clear ? null : _session.value;
        try {
          if (latest == null) {
            await _secrets.delete(_sessionKey);
          } else {
            await _secrets.putString(_sessionKey, jsonEncode(latest.toJson()));
          }
        } catch (_) {
          // Again with whatever the session is by then — none, after a sign-out.
          final wait = waited == null ? _persistRetry : _shorter(waited * 2, _persistRetryMax);
          unawaited(Future<void>.delayed(wait, () => generation == _persistGeneration ? _write(generation, waited: wait) : null));
        }
      });

  static Duration _shorter(Duration a, Duration b) => a < b ? a : b;

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
    bool origin = false,
  }) async {
    final root = base.trim();
    // Before anything is sent: a token must not cross the internet in the
    // clear (see server_policy.dart).
    if (!backendAllowed(root)) throw BackendException('insecure-server', base: root);
    final query0 = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    final parsed = Uri.parse('${root.endsWith('/') ? root.substring(0, root.length - 1) : root}/$path');
    final uri = query0.isEmpty ? parsed : parsed.replace(queryParameters: {...parsed.queryParameters, ...query0});
    final abort = Completer<void>();
    final request = http.AbortableRequest(method, uri, abortTrigger: abort.future)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json'
      // new-api picks its message language from the user's setting, then this
      // header, then English: a refusal must arrive in the app's language.
      ..headers['Accept-Language'] = _language();
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (cookie != null) request.headers['Cookie'] = cookie;
    if (sessionId != null) request.headers['X-Auth-Session'] = sessionId;
    // The cookie endpoints, behind SESSION_COOKIE_SECURE, take only requests
    // that name an allowed origin; the backend's own is the one to name.
    if (origin) request.headers['Origin'] = parsed.origin;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      // One deadline over the whole exchange, and the socket torn down when
      // it passes: a server that takes the connection and never answers
      // would otherwise hold the call — and a refresh everyone waits on —
      // for as long as the platform keeps the socket.
      response = await _http.send(request).then(http.Response.fromStream).timeout(_timeout, onTimeout: () {
        abort.complete();
        throw TimeoutException('no answer', _timeout);
      });
    } catch (error) {
      throw BackendException('unreachable', base: root, cause: error);
    }
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) json = decoded;
    } catch (_) {}
    return _Raw(
      response.statusCode,
      json,
      response.headersSplitValues['set-cookie'] ?? const [],
      receivedAt: _now(),
      date: _httpDate(response.headers['date']),
      retryAfter: _seconds(response.headers['retry-after']),
    );
  }

  static DateTime? _httpDate(String? header) {
    if (header == null) return null;
    try {
      return HttpDate.parse(header);
    } catch (_) {
      return null;
    }
  }

  static Duration? _seconds(String? header) {
    final seconds = header == null ? null : int.tryParse(header.trim());
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  static Object? _unwrap(_Raw res, String base) {
    final json = res.json;
    if (json == null) {
      throw res.status >= 400
          ? BackendException('http', status: res.status, base: base, retryAfter: res.retryAfter)
          : BackendException('unparsable', status: res.status, base: base, retryAfter: res.retryAfter);
    }
    if (json['success'] == false || res.status >= 400) {
      final message = json.str('message');
      // new-api's own envelope says `success: false`. A gateway's JSON in
      // front of it — Kong's {"message":"no Route matched…"} — has a message
      // too, but speaks for nothing behind it: an HTTP status, not the
      // backend's word (a 404 from it is not "the device is gone").
      final explained = json['success'] == false && message != null && message.trim().isNotEmpty;
      throw BackendException(
        explained ? 'server' : 'http',
        message: explained ? message : null,
        status: res.status,
        data: json['data'],
        base: base,
        errorCode: json.str('code'),
        retryAfter: res.retryAfter,
      );
    }
    return json['data'];
  }

  /// A current access token, refreshing first when it is missing or about to
  /// expire. Null only when there is no session to use: signed out, or the
  /// server refused the refresh cookie. A refresh that could not be settled
  /// throws its [BackendException], and the session stays.
  Future<String?> accessToken() async {
    final current = _session.value;
    if (current == null) return null;
    if (current.accessToken.isNotEmpty && current.accessExpiresAt > _now() + 30000) return current.accessToken;
    return await refresh() ? _session.value?.accessToken : null;
  }

  /// Drop the access token so the next call refreshes (the server said 401).
  /// With [failed], only if that is still the token: one a refresh has
  /// already replaced is left alone.
  Future<void> invalidateAccessToken([String? failed]) async {
    final current = _session.value;
    if (current == null || (failed != null && current.accessToken != failed)) return;
    await _save(current.withExpiry(0));
  }

  Future<Object?> _authed(String path, {String method = 'GET', Map<String, String?> query = const {}, Object? body}) async {
    final base = _session.value?.baseUrl;
    if (base == null) throw const BackendException('not-signed-in');
    final token = await accessToken();
    if (token == null) throw const BackendException('session-expired', status: 401);
    final res = await _raw(base, path, method: method, query: query, body: body, bearer: token);
    if (res.status == 401) {
      await invalidateAccessToken(token);
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

  static String _clean(String base) => normalizeBackendBase(base);

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
      await _storeSession(clean, data, res);
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
    await _storeSession(clean, data, res);
  }

  /// Mint a fresh access token from the refresh cookie. Single-flight.
  ///
  /// True when there is a current token afterwards; false when there surely
  /// is none — signed out, or the server refused the cookie (401/403, or a
  /// 409 AUTH_SESSION_MISMATCH), which ends the session here too. A refresh
  /// that could not be settled — no answer, a 5xx, a 429, a refresh race —
  /// throws its [BackendException], marked
  /// [BackendException.fromRefresh], and keeps the session: that is a blip,
  /// not a sign-out. After a 5xx, none is sent for a while ([_refreshPause]).
  Future<bool> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final current = _session.value;
    if (current == null) return false;
    if (current.accessExpiresAt > _now() + 30000 && current.accessToken.isNotEmpty) return true;
    final cookie = current.refreshCookie;
    if (cookie == null) return false;
    // A pause is the session's it came from: not one signed in since, on
    // this server or another, nor one whose cookie has turned over.
    var held = _refreshHeld;
    if (held != null && (held.base != current.baseUrl || held.cookie != cookie)) held = _refreshHeld = null;
    if (held != null && held.until > _elapsed()) {
      throw held.error._asRefresh(Duration(milliseconds: held.until - _elapsed()));
    }
    final started = _elapsed();
    int since() => _elapsed() - started;
    // The sends are over: a 5xx pauses the next refresh, anything else is
    // just thrown.
    Never give(BackendException error, StackTrace stack) {
      if (error.status < 500) Error.throwWithStackTrace(error._asRefresh(), stack);
      final pause = held == null ? _refreshPause : _shorter(held.pause * 2, _refreshPauseMax);
      _refreshHeld = (base: current.baseUrl, cookie: cookie, until: _elapsed() + pause.inMilliseconds, pause: pause, error: error);
      Error.throwWithStackTrace(error._asRefresh(pause), stack);
    }

    var next = 0;
    for (var attempt = 0;; attempt++) {
      try {
        final refreshed = await _refreshOnce(current, cookie);
        // Settled: the next 5xx pauses as the first did.
        _refreshHeld = null;
        return refreshed;
      } on BackendException catch (error, stack) {
        // No answer, or a 5xx: the server may have rotated the cookie all the
        // same, and this phone still holds the old one (see _refreshResends).
        // Not a first send that never left ([_neverSent]): that rotated
        // nothing, and its resends only kept the caller — a computer opened
        // with the backend out of reach — waiting. A later one is sent again,
        // as the first may have got through.
        final mayHaveRotated = (error.code == 'unreachable' && (attempt > 0 || !_neverSent(error.cause))) || error.status >= 500;
        while (next < _refreshResends.length && _refreshResends[next].inMilliseconds < since()) {
          next++;
        }
        if (!mayHaveRotated || next == _refreshResends.length) give(error, stack);
        await Future<void>.delayed(Duration(milliseconds: _refreshResends[next++].inMilliseconds - since()));
        // Woken late — the app frozen, the phone asleep — this one is still
        // sent, and no later one: past the window, a cookie the server rotated
        // is reuse whenever it is sent, so holding it back saves nothing, and
        // one it did not rotate is taken now rather than after a pause.
        if (_session.value?.refreshCookie != cookie) return _session.value != null;
      }
    }
  }

  /// A failure from before a byte of the request was written, in dart:io's
  /// own words (IOClient passes them on as a [SocketException]): no address
  /// for the host, the connection not set up in time, or refused — which
  /// only a connect can be. One that was up and then failed — reset, closed,
  /// as a TUN's fake address does — may have carried it.
  static bool _neverSent(Object? cause) => switch (cause) {
        SocketException(:final message, :final osError) => message.startsWith('Failed host lookup') ||
            message.startsWith('HTTP connection timed out') ||
            message == 'Connection failed' ||
            _refused(osError),
        OSError() => _refused(cause),
        _ => false,
      };

  /// ECONNREFUSED: 61 on iOS, 111 on Android.
  static bool _refused(OSError? error) => error?.errorCode == 61 || error?.errorCode == 111;

  Future<bool> _refreshOnce(AuthSession current, String cookie) async {
    final res = await _raw(
      current.baseUrl,
      'api/user/auth/refresh',
      method: 'POST',
      cookie: '$_refreshCookie=$cookie',
      sessionId: current.sessionId,
      origin: true,
    );
    // Signed out, or in again, while this was on the way: the answer is not
    // for the session there is now.
    if (_session.value?.refreshCookie != cookie) return _session.value != null;
    // A refused refresh token is a real logout, not a blip. So is a 409
    // AUTH_SESSION_MISMATCH: the cookie belongs to another login than the
    // session id sent with it, and sent again the pair gets the same answer.
    // Any other 409 (AUTH_REFRESH_RACE) keeps the session, as on the desktop
    // (spec §12).
    if (res.status == 401 || res.status == 403 || (res.status == 409 && res.json?['code'] == 'AUTH_SESSION_MISMATCH')) {
      await _save(null);
      return false;
    }
    final data = asMap(_unwrap(res, current.baseUrl));
    if ((data.str('access_token') ?? '').isEmpty) throw BackendException('bad-data', status: res.status, base: current.baseUrl);
    await _storeSession(current.baseUrl, data, res);
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
        origin: true,
      );
    } catch (_) {
      // A failed server-side revoke must not strand the user signed in locally.
    } finally {
      await _save(null);
    }
  }

  static final RegExp _cookiePattern = RegExp('(?:^|[;,]\\s*)$_refreshCookie=([^;,\\s]+)');

  Future<void> _storeSession(String base, Map<String, Object?> data, _Raw res) async {
    final user = data.obj('user');
    final session = data.obj('session');
    final sessionId = session?.str('id') ?? session?.str('sid');
    String? cookie;
    for (final header in res.setCookies) {
      final match = _cookiePattern.firstMatch(header);
      if (match != null) {
        cookie = match.group(1);
        break;
      }
    }
    final previous = _session.value;
    cookie ??= previous?.refreshCookie;
    await _save(AuthSession(
      baseUrl: base,
      accessToken: data.str('access_token') ?? '',
      accessExpiresAt: _localExpiry(data['access_expires_at'], res),
      refreshCookie: cookie,
      sessionId: sessionId ?? previous?.sessionId,
      userId: user?.number('id') ?? previous?.userId ?? 0,
      username: user?.str('username') ?? previous?.username ?? '',
    ));
  }

  /// The token's expiry on this phone's clock. The server's figure is on its
  /// own clock: a phone running minutes fast would take every new token for
  /// expired and refresh before every call, one running slow would keep
  /// sending expired ones. What carries over is the lifetime — the expiry
  /// less the answer's `Date` — counted from when the answer came.
  static int _localExpiry(Object? raw, _Raw res) {
    if (raw is! num) return res.receivedAt + _accessFallback.inMilliseconds;
    final expires = raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt();
    final date = res.date;
    return date == null ? expires : res.receivedAt + (expires - date.millisecondsSinceEpoch);
  }

  Future<UserInfo> self() async => _decode(await _authed('api/user/self'), UserInfo.fromJson);

  // --- companion (spec §9) ---------------------------------------------------------

  Future<CompanionConfig> companionConfig() async => _decode(await _authed('api/companion/config'), CompanionConfig.fromJson);

  String? _relayPathServer;
  Future<String?>? _relayPath;

  /// The relay's path, `ws_path` from `/config`: fetched once per server, and
  /// only when the relay is first wanted. A failure, or no answer within
  /// 10 s, is not kept: it gives null (the default path) and the next
  /// connection asks again.
  Future<String?> relayPath() {
    final server = baseUrl;
    if (_relayPath == null || _relayPathServer != server) {
      _relayPathServer = server;
      _relayPath = _fetchRelayPath(server);
    }
    return _relayPath!;
  }

  Future<String?> _fetchRelayPath(String server) async {
    try {
      return (await companionConfig().timeout(const Duration(seconds: 10))).wsPath;
    } catch (_) {
      if (_relayPathServer == server) _relayPath = null;
      return null;
    }
  }

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
