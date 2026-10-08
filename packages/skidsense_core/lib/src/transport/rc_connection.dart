import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';

import '../protocol/bytes.dart';
import '../protocol/crypto_error.dart';
import '../protocol/frames.dart';
import '../protocol/handshake.dart';
import '../protocol/outer_frames.dart';
import '../protocol/protocol.dart';
import '../util/json.dart';
import 'carrier.dart';
import 'errors.dart';
import 'inner.dart';

/// Tunables, overridable in tests.
class ConnectionConfig {
  const ConnectionConfig({
    this.handshakeTimeout = Protocol.handshakeTimeout,
    this.requestTimeout = const Duration(seconds: 30),
    this.requestCeiling = const Duration(minutes: 15),
    this.pingInterval = const Duration(seconds: 25),
    this.idleTimeout = const Duration(seconds: 70),
    this.app = const AppInfo(name: 'skidsense-mobile', version: '0.1.0', platform: 'android'),
  });

  final Duration handshakeTimeout;

  /// How long a request may go without the line delivering anything at all.
  final Duration requestTimeout;

  /// However lively the line, a request is given up after this.
  final Duration requestCeiling;

  /// How often the device pings when the line is quiet.
  final Duration pingInterval;

  /// No frame at all for this long means the line is dead.
  final Duration idleTimeout;

  final AppInfo app;
}

class _Pending {
  final Completer<Object?> result = Completer<Object?>()..future.ignore();
  List<String?>? parts;
  int bytes = 0;
}

/// One established, authenticated conversation with a host over one carrier:
/// the handshake (§4), `hello`/`welcome` (§6.1), then requests, parted
/// responses, events and pings until either side closes.
///
/// Any violation — a frame out of order, a byte that does not authenticate,
/// a frame that is not a `d` frame after the handshake — closes the
/// connection. Nothing is retried here; reconnecting is `RcClient`'s job, and
/// it always runs a fresh handshake, so a fresh key.
class RcConnection {
  RcConnection._(this._carrier, this._sealer, this._opener, this.welcome, this.route, this._config)
      : _lastReceivedAt = clock.now();

  final Carrier _carrier;
  final FrameSealer _sealer;
  final FrameOpener _opener;
  final Welcome welcome;
  final HostRoute route;
  final ConnectionConfig _config;

  int _nextId = 1;
  final Map<String, _Pending> _pending = {};
  DateTime _lastReceivedAt;
  Timer? _keepAlive;

  /// Responses and events received so far. A request's timeout is on
  /// *silence*, not on the whole call: over the budgeted relay a large
  /// response arrives slowly but steadily, and a request queued behind one is
  /// waiting on a line that is plainly working.
  int _progress = 0;

  final StreamController<RcEvent> _events = StreamController<RcEvent>.broadcast();
  final Completer<RcException> _closed = Completer<RcException>();
  RcException? _closeError;

  /// Requests still waiting for their answer.
  int get inFlight => _pending.length;

  Stream<RcEvent> get events => _events.stream;

  /// Completes with why the connection ended.
  Future<RcException> get closed => _closed.future;

  bool get isOpen => _closeError == null;

  /// Run the handshake and `hello` on [carrier]. On success the connection's
  /// read loop is running; on failure the carrier is closed and the error
  /// says why ([HandshakeRejected], [RelayRejected], [HelloRefused],
  /// [CryptoError] for a failed confirmation, or [HandshakeClosed]).
  static Future<RcConnection> establish({
    required Carrier carrier,
    required HostRoute route,
    required Initiator initiator,
    String? grant,
    String? ticket,
    ConnectionConfig config = const ConnectionConfig(),
  }) async {
    var timedOut = false;
    final handshake = _handshake(carrier, route, initiator, grant, ticket, config);
    try {
      return await handshake.timeout(config.handshakeTimeout, onTimeout: () {
        timedOut = true;
        throw HandshakeClosed('handshake-timeout', route: route);
      });
    } on HandshakeRejected {
      await carrier.close('handshake rejected');
      rethrow;
    } on RelayRejected {
      await carrier.close('relay rejected');
      rethrow;
    } on HandshakeClosed {
      await carrier.close(timedOut ? 'handshake timeout' : 'handshake failed');
      rethrow;
    } on ConnectionClosed catch (error) {
      await carrier.close('handshake failed');
      throw HandshakeClosed(error.detail ?? 'closed', route: route, cause: error);
    } catch (_) {
      await carrier.close('handshake failed');
      rethrow;
    }
  }

  static Future<RcConnection> _handshake(
    Carrier carrier,
    HostRoute route,
    Initiator initiator,
    String? grant,
    String? ticket,
    ConnectionConfig config,
  ) async {
    try {
      carrier.send(OuterFrames.encode(initiator.hs1.toJson()));
    } on ConnectionClosed {
      // The relay refuses (the desktop is offline, say) by writing its reason
      // and closing: by the time we send, the reason is waiting in the inbox.
      // Saying it beats saying "the socket closed".
      throw await _queuedRelayError(carrier, route) ?? HandshakeClosed('peer-closed', route: route);
    }
    final Hs2Frame hs2;
    switch (await _receiveOuter(carrier, route)) {
      case OuterHs2(:final frame):
        hs2 = frame;
      case OuterReject(:final frame):
        throw HandshakeRejected(frame.code, message: frame.message, route: route);
      case OuterData() || OuterHs1():
        throw HandshakeRejected('handshake-failed', route: route);
      case OuterRelayError():
        throw StateError('unreachable: _receiveOuter throws on relay-error');
    }
    final keys = initiator.finish(hs2);
    final sealer = FrameSealer(keys.send);
    final opener = FrameOpener(keys.recv);
    try {
      carrier.send(OuterFrames.encode(sealer.seal(Inner.hello(config.app, grant: grant, ticket: ticket)).toJson()));
    } on ConnectionClosed {
      throw HandshakeClosed('peer-closed', route: route);
    }

    final String first;
    switch (await _receiveOuter(carrier, route)) {
      case OuterData(:final frame):
        first = opener.open(frame);
      // A plaintext `hsr` after a valid `hs2` is somebody else's: the host has
      // proven its key and the desktop never rejects past this point, so this
      // is a broken connection, not the host refusing the device (C6).
      case OuterReject():
        throw HandshakeClosed('plaintext-after-handshake', route: route);
      case OuterHs1() || OuterHs2():
        throw HandshakeRejected('handshake-failed', route: route);
      case OuterRelayError():
        throw StateError('unreachable: _receiveOuter throws on relay-error');
    }
    final message = _parseInner(first);
    switch (message.str('t')) {
      case 'welcome':
        final welcome = Welcome.fromJson(message);
        if (welcome.host.id.isNotEmpty && welcome.host.id != initiator.hostId) {
          throw HandshakeRejected('wrong-host', route: route);
        }
        return RcConnection._(carrier, sealer, opener, welcome, route, config).._start();
      case 'bye':
        throw HelloRefused(message.str('reason'));
      default:
        throw HandshakeRejected('handshake-failed', route: route);
    }
  }

  static Future<OuterFrame> _receiveOuter(Carrier carrier, HostRoute route) async {
    final text = await carrier.receive();
    if (text == null) throw HandshakeClosed('peer-closed', route: route);
    final frame = OuterFrames.parse(text);
    if (frame is OuterRelayError) {
      // Only the relay speaks this. On a LAN socket it is someone pretending,
      // and is treated as the violation it is.
      if (route is! RouteRelay) throw HandshakeClosed('relay-frame-on-lan', route: route);
      throw RelayRejected(frame.frame.code, message: frame.frame.message, route: route);
    }
    return frame;
  }

  /// A `relay-error` the relay sent before it closed, if one is waiting (or
  /// arrives at once).
  static Future<RelayRejected?> _queuedRelayError(Carrier carrier, HostRoute route) async {
    if (route is! RouteRelay) return null;
    try {
      final text = await carrier.receive(timeout: const Duration(milliseconds: 500));
      if (text == null) return null;
      final frame = OuterFrames.parse(text);
      return frame is OuterRelayError ? RelayRejected(frame.frame.code, message: frame.frame.message, route: route) : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _parseInner(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw ConnectionClosed('unparsable', cause: error);
    }
    if (decoded is! Map<String, Object?>) throw const ConnectionClosed('unparsable');
    return decoded;
  }

  void _start() {
    unawaited(_readLoop());
    _keepAlive = Timer.periodic(_config.pingInterval, (_) => _tick());
  }

  Future<void> _readLoop() async {
    try {
      while (isOpen) {
        final text = await _carrier.receive();
        if (!isOpen) return;
        if (text == null) throw ConnectionClosed('peer-closed', route: route);
        _lastReceivedAt = clock.now();
        final frame = OuterFrames.parse(text);
        final String plaintext;
        switch (frame) {
          case OuterData(:final frame):
            plaintext = _opener.open(frame);
          case OuterRelayError(:final frame):
            if (route is! RouteRelay) throw ConnectionClosed('relay-frame-on-lan', route: route);
            throw RelayRejected(frame.code, message: frame.message, route: route);
          default:
            throw ConnectionClosed('not-data', route: route);
        }
        _dispatch(_parseInner(plaintext));
      }
    } on RcException catch (error) {
      await _shutdown(error);
    } on CryptoError catch (error) {
      await _shutdown(ConnectionClosed(error.code, route: route, cause: error));
    } catch (error) {
      await _shutdown(ConnectionClosed('error', route: route, cause: error));
    }
  }

  void _dispatch(Map<String, Object?> message) {
    switch (message.str('t')) {
      case 'res':
        _progress += 1;
        _onResponse(message);
      case 'ev':
        _progress += 1;
        final kind = message.str('k');
        if (kind == null) return;
        if (!_events.isClosed) _events.add(RcEvent(kind, message['p'] ?? const <String, Object?>{}));
      case 'ping':
        _sendInner(Inner.pong(message.number('ts') ?? 0));
      case 'pong':
        break;
      // `code` is optional (spec §6.5, C5): a desktop from before it sends
      // only the reason, which is then all there is to show.
      case 'bye':
        throw HostBye(message.str('code'), reason: message.str('reason'));
      default:
        // An unknown inner type from a newer host is ignored, not fatal.
        break;
    }
  }

  /// `part`/`parts` must be JSON integers (spec §6.3, C3): -1 for anything else.
  static int _jsonInt(Map<String, Object?> message, String key) {
    final value = message[key];
    return value is int ? value : -1;
  }

  void _onResponse(Map<String, Object?> message) {
    final id = message.str('id');
    if (id == null) return;
    final entry = _pending[id];
    if (entry == null) return;
    // The field's *presence* marks a parted response, so a malformed `parts`
    // is still a parted response — a broken one (C3).
    if (message.containsKey('parts')) {
      final total = _jsonInt(message, 'parts');
      final part = _jsonInt(message, 'part');
      final data = message.str('d');
      // The count is checked before it sizes anything.
      if (total < 1 || total > Protocol.maxResponseParts) {
        _fail(id, entry, const RcException('bad-response', detail: 'parts'));
        return;
      }
      final buffer = entry.parts ??= List<String?>.filled(total, null);
      if (buffer.length != total || part < 0 || part >= total || data == null) {
        _fail(id, entry, const RcException('bad-response', detail: 'slice'));
        return;
      }
      if (buffer[part] != null) {
        _fail(id, entry, const RcException('bad-response', detail: 'repeated-slice'));
        return;
      }
      entry.bytes += utf8Length(data);
      if (entry.bytes > Protocol.maxResponse) {
        _fail(id, entry, const RcException('too-large', detail: 'response'));
        return;
      }
      buffer[part] = data;
      if (buffer.any((slice) => slice == null)) return;
      _pending.remove(id);
      final Object? whole;
      try {
        whole = jsonDecode(buffer.join());
      } on FormatException {
        entry.result.completeError(const RcException('bad-response', detail: 'unparsable'));
        return;
      }
      if (whole is! Map<String, Object?>) {
        entry.result.completeError(const RcException('bad-response', detail: 'unparsable'));
        return;
      }
      _resolve(entry, whole);
      return;
    }
    _pending.remove(id);
    _resolve(entry, message);
  }

  void _fail(String id, _Pending entry, RcException error) {
    _pending.remove(id);
    entry.result.completeError(error);
  }

  static void _resolve(_Pending entry, Map<String, Object?> body) {
    if (body['ok'] == true) {
      entry.result.complete(body['r']);
    } else {
      final error = body.obj('e');
      entry.result.completeError(RemoteCallError(error?.str('code') ?? 'internal', error?.str('message') ?? ''));
    }
  }

  void _tick() {
    if (!isOpen) return;
    final idle = clock.now().difference(_lastReceivedAt);
    if (idle >= _config.idleTimeout) {
      unawaited(_shutdown(ConnectionClosed('idle', route: route)));
      return;
    }
    if (idle >= _config.pingInterval) {
      try {
        _sendInner(Inner.ping(clock.now().millisecondsSinceEpoch));
      } catch (_) {}
    }
  }

  /// Seal and queue one inner message. Synchronous end to end, so the
  /// counter order is the send order without a lock.
  void _sendInner(String text) {
    final error = _closeError;
    if (error != null) throw error;
    if (utf8Length(text) > Protocol.maxPlaintext) throw const RcException('too-large', detail: 'request');
    final DataFrame frame;
    try {
      frame = _sealer.seal(text);
    } on CryptoError catch (error) {
      throw RcException(error.code, cause: error);
    }
    _carrier.send(OuterFrames.encode(frame.toJson()));
  }

  /// Send `req` and wait for its `res` (reassembled when in parts). Throws
  /// [RemoteCallError] for `ok:false`, [ConnectionClosed] if the line drops,
  /// `RcException('timeout')` after [timeout] of silence.
  Future<Object?> request(String method, [Object? params, Duration? timeout]) async {
    final error = _closeError;
    if (error != null) throw error;
    final wait = timeout ?? _config.requestTimeout;
    final id = 'q${_nextId++}';
    final entry = _Pending();
    _pending[id] = entry;
    try {
      _sendInner(Inner.request(id, method, params));
      var waited = Duration.zero;
      while (true) {
        final seen = _progress;
        try {
          return await entry.result.future.timeout(wait);
        } on TimeoutException {
          waited += wait;
          if (_progress == seen || waited >= _config.requestCeiling) {
            throw RcException('timeout', detail: method, route: route);
          }
        }
      }
    } finally {
      _pending.remove(id);
    }
  }

  /// Say goodbye and close.
  Future<void> close([String reason = 'client closed']) async {
    if (_closeError != null) return;
    try {
      _sendInner(Inner.bye(reason));
    } catch (_) {}
    await _shutdown(ConnectionClosed('closed', route: route));
  }

  Future<void> _shutdown(RcException error) async {
    if (_closeError != null) return;
    _closeError = error;
    _keepAlive?.cancel();
    final failed = _pending.values.toList();
    _pending.clear();
    for (final entry in failed) {
      if (!entry.result.isCompleted) entry.result.completeError(error);
    }
    try {
      await _carrier.close(error.toString());
    } catch (_) {}
    if (!_closed.isCompleted) _closed.complete(error);
    await _events.close();
  }
}
