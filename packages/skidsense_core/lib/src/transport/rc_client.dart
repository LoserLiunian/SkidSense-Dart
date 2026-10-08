import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/crypto_error.dart';
import '../protocol/handshake.dart';
import '../protocol/primitives.dart';
import '../protocol/protocol.dart';
import '../util/async_queue.dart';
import '../util/signal.dart';
import '../util/state_value.dart';
import 'carrier.dart';
import 'errors.dart';
import 'inner.dart';
import 'rc_connection.dart';

/// One paired host, as the client needs it. [hostKey] is the key pinned from
/// the QR code — never learned from the network.
///
/// The LAN address is whatever the pairing QR carried, and a router hands
/// out a new one often enough that it cannot be the only one we ever try.
/// [learn] replaces the current addresses with a fresher list from
/// `GET /hosts` while keeping the old ones as a fallback: a stale address
/// costs one short timeout, and a host that moved is then reachable again on
/// the next attempt.
class HostEndpoint {
  HostEndpoint({
    required this.hostId,
    required this.hostKey,
    required this.deviceId,
    required List<String> lanAddrs,
    required this._lanPort,
    this.relayEnabled = true,
  })  : _current = List.of(lanAddrs),
        _known = List.of(lanAddrs);

  final String hostId;
  final Uint8List hostKey;
  final String deviceId;
  final bool relayEnabled;

  /// The desktop's LAN port. Learned like the addresses: a desktop that found
  /// its usual port taken listens on another and registers it.
  int get lanPort => _lanPort;
  int _lanPort;

  List<String> _current;

  /// Addresses we have seen for this host, newest first: what to try right now.
  List<String> get addresses => List.unmodifiable(_current);

  /// Everything known, in the order to try it: the current addresses first,
  /// then whatever the QR code said.
  final List<String> _known;

  /// Take a fresher address list from the backend. Returns true when it says
  /// something new, so the caller can nudge a client that is failing.
  bool learn(List<String> addrs, [int? port]) {
    final incoming = <String>[];
    for (final address in addrs) {
      if (address.trim().isNotEmpty && !incoming.contains(address)) incoming.add(address);
    }
    if (incoming.isEmpty && (port == null || port == _lanPort)) return false;
    final changed = !_sameList(incoming, _current) || (port != null && port != _lanPort);
    if (port != null && port >= 1 && port <= 65535) _lanPort = port;
    if (incoming.isNotEmpty) {
      _current = incoming;
      for (final address in incoming.reversed) {
        _known
          ..remove(address)
          ..insert(0, address);
      }
      while (_known.length > 16) {
        _known.removeLast();
      }
    }
    return changed;
  }

  List<Route> routes() => [
        if (_lanPort >= 1 && _lanPort <= 65535)
          for (final address in _known.toSet()) RouteLan(address, _lanPort),
        if (relayEnabled) const RouteRelay(),
      ];

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Where `rc-access` grants come from (the backend, with a cache).
abstract class Credentials {
  /// An `rc-access` grant for this device and host. [fresh] skips any cache.
  Future<String> grant({required bool fresh});

  /// The relay said the bearer is no good; the next relay attempt should
  /// re-authenticate.
  Future<void> onUnauthorized() async {}

  /// The host kicked this device because the cached grant's scopes no longer
  /// stand (spec §6.5, C5).
  Future<void> onDropped() async {}
}

class ClientConfig {
  const ClientConfig({
    this.lanConnectTimeout = const Duration(milliseconds: 2500),
    this.relayConnectTimeout = const Duration(seconds: 15),
    this.backoffBase = const Duration(seconds: 1),
    this.backoffMax = const Duration(seconds: 30),
    this.callWait = const Duration(seconds: 15),
    this.relayHeadStart = const Duration(milliseconds: 700),
    this.lanProbeInterval = const Duration(seconds: 60),
    this.connection = const ConnectionConfig(),
  });

  /// Per LAN address: a desktop on this network answers well within this.
  final Duration lanConnectTimeout;
  final Duration relayConnectTimeout;
  final Duration backoffBase;
  final Duration backoffMax;

  /// How long a call waits for a connection before failing.
  final Duration callWait;

  /// How long the LAN routes get on their own before the relay is tried as
  /// well. The LAN addresses are all tried at once; a desktop that answers on
  /// the LAN does so well within this, so a phone at home never opens a
  /// relay connection.
  final Duration relayHeadStart;

  /// While on the relay, how often to look for the desktop on the LAN again.
  final Duration lanProbeInterval;

  final ConnectionConfig connection;
}

sealed class ClientState {
  const ClientState();
}

final class ClientIdle extends ClientState {
  const ClientIdle();
}

/// [via] is the route being tried, or null while the grant is fetched.
final class ClientConnecting extends ClientState {
  const ClientConnecting(this.via, this.attempt);

  final Route? via;
  final int attempt;
}

final class ClientConnected extends ClientState {
  const ClientConnected(this.welcome, this.route);

  final Welcome welcome;
  final Route route;
}

/// Will retry by itself after [retryIn].
final class ClientWaiting extends ClientState {
  const ClientWaiting(this.error, this.retryIn, this.attempt);

  final Object error;
  final Duration retryIn;
  final int attempt;
}

/// Will not retry until [RcClient.retry]: the same attempt would fail the same way.
final class ClientFailed extends ClientState {
  const ClientFailed(this.error);

  final Object error;

  String? get code => switch (error) {
        RcException(:final code) => code,
        CryptoError(:final code) => code,
        _ => null,
      };
}

sealed class _Outcome {}

final class _Up extends _Outcome {
  _Up(this.connection);
  final RcConnection connection;
}

final class _Permanent extends _Outcome {
  _Permanent(this.error);
  final Object error;
}

final class _Retry extends _Outcome {
  _Retry(this.error, {required this.freshGrant});
  final Object error;
  final bool freshGrant;
}

sealed class _Opening {}

final class _Opened extends _Opening {
  _Opened(this.route, this.carrier);
  final Route route;
  final Carrier carrier;
}

final class _OpenFailed extends _Opening {
  _OpenFailed(this.route, this.error);
  final Route route;
  final Object error;
}

final class _RelayTurn extends _Opening {}

/// The connection to one host, kept up: LAN addresses first, then the relay;
/// exponential backoff between rounds; re-subscribe after every reconnect.
/// One implementation for both carriers — the route is the only difference.
class RcClient {
  RcClient({
    required this._endpoint,
    required this._identity,
    required this._credentials,
    required this._carriers,
    this.config = const ClientConfig(),
  });

  final HostEndpoint _endpoint;
  final KeyPair _identity;
  final Credentials _credentials;
  final CarrierFactory _carriers;
  final ClientConfig config;
  final Random _random = Random();

  final StateValue<ClientState> _state = StateValue<ClientState>(const ClientIdle());
  final StreamController<RcEvent> _events = StreamController<RcEvent>.broadcast();

  ClientState get state => _state.value;
  StateValue<ClientState> get states => _state;
  Stream<RcEvent> get events => _events.stream;

  /// Called once per round when no LAN address worked and the relay is next.
  /// The host's address may have changed, and only the backend knows the new
  /// one — so this is the hook that refreshes it.
  Future<void> Function()? onLanUnreachable;

  /// Whether the connection may be swapped for a LAN one right now. The
  /// caller knows what would not survive it — an attachment half uploaded
  /// lives in the desktop's per-connection stash.
  bool Function() canSwitchRoute = () => true;

  /// Keys to follow, across reconnects.
  final Set<String> _subscriptions = {};

  /// Keys already subscribed on the connection currently up.
  Set<String> _subscribedOnCurrent = {};

  final Signal _wake = Signal();
  final Signal _lanProbe = Signal();
  int _generation = 0;
  bool _running = false;
  RcConnection? _current;

  /// The route the last connection came up on: a relay success starts the
  /// relay at once next time.
  Route? _lastGood;

  /// Set while a relay connection is being swapped for a LAN one, so the drop
  /// is not reported.
  bool _switching = false;

  String get hostId => _endpoint.hostId;

  void start() {
    if (_running) return;
    _running = true;
    final generation = ++_generation;
    unawaited(_run(generation));
  }

  /// Retry now: after a permanent failure, or to cut a backoff short (app
  /// resumed, network changed).
  void retry() {
    start();
    _wake.fire();
  }

  /// Look for the desktop on the LAN now rather than at the next interval.
  void probeLan() => _lanProbe.fire();

  Future<void> stop() async {
    _running = false;
    _generation += 1;
    _wake.fire();
    _lanProbe.fire();
    final connection = _current;
    _current = null;
    await connection?.close('client stopped');
    _state.value = const ClientIdle();
  }

  Future<void> _run(int generation) async {
    bool alive() => generation == _generation;
    var attempt = 0;
    var freshGrant = false;
    while (alive()) {
      attempt += 1;
      final outcome = await _connectOnce(generation, attempt, freshGrant);
      if (!alive()) {
        if (outcome is _Up) await outcome.connection.close('client stopped');
        return;
      }
      switch (outcome) {
        case _Up(:final connection):
          attempt = 0;
          freshGrant = false;
          _current = connection;
          final forward = connection.events.listen((event) {
            if (!_events.isClosed) _events.add(event);
          });
          // Re-subscribe before announcing the connection: a caller that
          // reacts to Connected and immediately asks for a transcript must
          // not be able to race the subscription.
          await _resubscribe(connection);
          if (!alive()) {
            unawaited(forward.cancel());
            await connection.close('client stopped');
            return;
          }
          _lastGood = connection.route;
          if (connection.isOpen) _state.value = ClientConnected(connection.welcome, connection.route);
          if (connection.route is RouteRelay) unawaited(_watchForLan(connection, generation));

          final why = await connection.closed;
          unawaited(forward.cancel());
          if (identical(_current, connection)) _current = null;
          if (!alive()) return;
          if (_switching) {
            // Our own swap to the LAN: straight into the next round, which
            // tries the LAN first.
            _switching = false;
            attempt = 0;
            continue;
          }
          // A relay refusal *after* the handshake is the relay's own
          // `relay-error` frame, which only the relay route tolerates; it
          // says the session behind the bearer is over, and is final.
          if (why is RelayRejected && why.permanent) {
            _state.value = ClientFailed(why);
            await _wake.wait();
            continue;
          }
          if (why is RelayRejected && why.code == 'unauthorized') await _credentials.onUnauthorized();
          // Kicked so the reconnect would see different scopes (C5): the
          // cached grant is the old one, so drop it.
          if (why is HostBye && why.regrant) await _credentials.onDropped();
          // A connection that was up drops: reconnect promptly, once.
          _state.value = ClientWaiting(why, config.backoffBase, 1);
          await _wake.wait(timeout: config.backoffBase);
        case _Permanent(:final error):
          _state.value = ClientFailed(error);
          await _wake.wait();
          attempt = 0;
        case _Retry(:final error, freshGrant: final fresh):
          freshGrant = fresh;
          final backoff = _backoff(attempt);
          _state.value = ClientWaiting(error, backoff, attempt);
          await _wake.wait(timeout: backoff);
      }
    }
  }

  Duration _backoff(int attempt) {
    final base = config.backoffBase.inMilliseconds;
    final capped = min(base * (1 << (attempt - 1).clamp(0, 10)), config.backoffMax.inMilliseconds);
    // ±20 % jitter so a fleet of phones does not reconnect in lockstep.
    final jitter = (capped * 0.2 * (_random.nextDouble() * 2 - 1)).round();
    return Duration(milliseconds: max(capped + jitter, base ~/ 2));
  }

  Future<_Outcome> _connectOnce(int generation, int attempt, bool freshGrant) async {
    final routes = _endpoint.routes();
    if (routes.isEmpty) return _Permanent(const RcException('no-route'));
    _state.value = ClientConnecting(null, attempt);
    final String grant;
    try {
      grant = await _credentials.grant(fresh: freshGrant);
    } on RcException catch (error) {
      if (error.code == 'revoked') return _Permanent(error);
      return _Retry(RcException('grant', cause: error), freshGrant: false);
    } catch (error) {
      return _Retry(RcException('grant', cause: error), freshGrant: false);
    }
    if (generation != _generation) return _Retry(const ConnectionClosed('closed'), freshGrant: false);

    Object lastError = const RcException('unreachable');
    var reached = false;
    void unreachable(Object error) {
      if (!reached) lastError = error;
    }

    void refused(Object error) {
      reached = true;
      lastError = error;
    }

    // Routes that failed this round — to open, or after opening — are not
    // raced again in it.
    final dead = <Route>{};
    var anyLanOpened = false;
    while (true) {
      final remaining = routes.where((route) => !dead.contains(route)).toList();
      if (remaining.isEmpty) break;
      final opened = await _openFastest(remaining, attempt, (route, error) {
        dead.add(route);
        // The relay's upgrade said 401: the bearer is spent, not the route.
        if (error is CarrierUnavailable && error.reason == 'unauthorized') unawaited(_credentials.onUnauthorized());
        unreachable(_attribute(error, route));
      });
      if (opened == null) break;
      final route = opened.route;
      if (route is RouteLan) anyLanOpened = true;
      dead.add(route);
      if (generation != _generation) {
        await opened.carrier.close('client stopped');
        return _Retry(const ConnectionClosed('closed'), freshGrant: false);
      }
      try {
        final initiator = Initiator(
          mode: HandshakeMode.connect,
          hostId: _endpoint.hostId,
          hostStatic: _endpoint.hostKey,
          clientStatic: _identity,
        );
        final connection = await RcConnection.establish(
          carrier: opened.carrier,
          route: route,
          initiator: initiator,
          grant: grant,
          config: config.connection,
        );
        return _Up(connection);
      } on HandshakeClosed catch (error) {
        // The carrier died before the welcome, or something plaintext arrived
        // after the host proved itself: this route is dead, and it says
        // nothing about the device (spec §6.5, C6).
        unreachable(error);
      } on HandshakeRejected catch (error) {
        if (error.permanent && route is RouteRelay) {
          // A *plaintext* refusal on the LAN is forgeable by anything
          // answering at that address — it must never end the round on its
          // own (C6). The relay route is TLS to the backend, which
          // identity-checks the caller's device id, so only the refusal
          // through *it* counts as the host's word.
          return _Permanent(error);
        }
        refused(error);
      } on RelayRejected catch (error) {
        if (error.permanent) return _Permanent(error);
        if (error.code == 'unauthorized') await _credentials.onUnauthorized();
        refused(error);
      } on HelloRefused catch (error) {
        // The host would not take the grant. The next round asks the backend
        // for a fresh one rather than replaying the cached one.
        return _Retry(error, freshGrant: true);
      } on CryptoError catch (error) {
        // A failed confirmation: whatever answered at this address is not the
        // host we pinned. Not fatal — another route may be.
        refused(_attribute(error, route));
      } catch (error) {
        unreachable(_attribute(error, route));
      }
    }
    if (routes.any((route) => route is RouteLan) && !anyLanOpened && !reached) {
      try {
        await onLanUnreachable?.call();
      } catch (_) {}
    }
    return _Retry(lastError, freshGrant: false);
  }

  static Object _attribute(Object error, Route route) => switch (error) {
        RcException(route: null) => RcException(error.code, detail: error.detail, message: error.message, route: route, cause: error),
        RcException() => error,
        CryptoError(:final code) => RcException(code, route: route, cause: error),
        CarrierUnavailable(:final reason) => RcException(reason == 'timeout' ? 'timeout' : 'unreachable', detail: reason, route: route, cause: error),
        TimeoutException() => RcException('timeout', route: route, cause: error),
        _ => RcException('unreachable', route: route, cause: error),
      };

  Future<Carrier> _openBounded(Route route, Duration timeout) =>
      openBounded(_carriers, route, CarrierTarget(_endpoint.hostId, _endpoint.deviceId), timeout);

  /// Open the first carrier any of [routes] can give.
  ///
  /// The LAN addresses are tried all at once — a desktop advertises every
  /// private address it has (VPN, VM bridges, IPv6) and trying them in turn,
  /// a timeout each, put ten or twenty seconds in front of the relay on every
  /// connect away from home. The relay joins after a head start, or at once
  /// when it is what worked last time, or as soon as every LAN address has
  /// failed. The first carrier to open wins; one that opens late is closed.
  Future<_Opened?> _openFastest(List<Route> routes, int attempt, void Function(Route, Object) failed) async {
    final lan = routes.whereType<RouteLan>().toList();
    final Route? relay = routes.whereType<RouteRelay>().firstOrNull;
    final outcomes = AsyncQueue<_Opening>();
    var decided = false;
    var running = 0;
    var relayStarted = false;

    void open(Route route) {
      running += 1;
      _state.value = ClientConnecting(route, attempt);
      final timeout = route is RouteLan ? config.lanConnectTimeout : config.relayConnectTimeout;
      _openBounded(route, timeout).then((carrier) {
        if (decided) {
          unawaited(carrier.close('superseded'));
        } else {
          outcomes.add(_Opened(route, carrier));
        }
      }, onError: (Object error) {
        if (!decided) outcomes.add(_OpenFailed(route, error));
      });
    }

    void openRelay() {
      if (relay == null || relayStarted) return;
      relayStarted = true;
      open(relay);
    }

    for (final route in lan) {
      open(route);
    }
    if (lan.isEmpty || _lastGood is RouteRelay) openRelay();
    final timer = !relayStarted && relay != null ? Timer(config.relayHeadStart, () => outcomes.add(_RelayTurn())) : null;

    _Opened? winner;
    while (winner == null && (running > 0 || (relay != null && !relayStarted))) {
      final next = await outcomes.next();
      switch (next) {
        case _Opened():
          running -= 1;
          winner = next;
        case _OpenFailed(:final route, :final error):
          running -= 1;
          failed(route, error);
          if (running == 0) openRelay();
        case _RelayTurn():
          openRelay();
        case null:
          break;
      }
    }
    timer?.cancel();
    decided = true;
    outcomes.close();
    // Carriers that opened after the winner but before `decided`.
    for (var late = outcomes.poll(); late != null; late = outcomes.poll()) {
      if (late is _Opened && !identical(late, winner)) unawaited(late.carrier.close('superseded'));
    }
    return winner;
  }

  /// On the relay: look for the desktop on the LAN every so often, and move
  /// there when it answers and nothing would be lost by the swap. The relay
  /// is budgeted (§10) and a round trip through it is slower.
  Future<void> _watchForLan(RcConnection connection, int generation) async {
    bool stillHere() => generation == _generation && identical(_current, connection) && connection.isOpen;
    while (stillHere()) {
      await Future.any<Object?>([_lanProbe.wait(timeout: config.lanProbeInterval), connection.closed]);
      if (!stillHere()) return;
      final lan = _endpoint.routes().whereType<RouteLan>().toList();
      if (lan.isEmpty) continue;
      final probes = await Future.wait(lan.map((route) =>
          _openBounded(route, config.lanConnectTimeout).then<Carrier?>((carrier) => carrier, onError: (Object _) => null)));
      var found = false;
      for (final carrier in probes) {
        if (carrier == null) continue;
        found = true;
        unawaited(carrier.close('probe'));
      }
      if (found && stillHere() && connection.inFlight == 0 && canSwitchRoute()) {
        _switching = true;
        _lastGood = null;
        await connection.close('switching to lan');
        return;
      }
    }
  }

  /// Subscribe every remembered key on a fresh connection. A key is sent at
  /// most once per connection, whichever of this and [subscribe] gets there
  /// first.
  Future<void> _resubscribe(RcConnection connection) async {
    _subscribedOnCurrent = {};
    for (final key in _subscriptions.toList()) {
      if (_isCurrent(connection) && _subscribedOnCurrent.add(key)) {
        try {
          await connection.request('subscribe', {'key': key});
        } catch (_) {}
      }
    }
  }

  bool _isCurrent(RcConnection connection) => identical(_current, connection) || _current == null;

  /// The live connection, waiting up to [ClientConfig.callWait] for one.
  ///
  /// Always waits on the state rather than returning [_current] when it looks
  /// usable: between a drop and the reconnect, `_current` still points at the
  /// connection that just died.
  Future<RcConnection> connection() async {
    retry();
    final connected = await _state.firstWhere((state) => state is ClientConnected, timeout: config.callWait);
    if (connected == null) {
      final failed = _state.value;
      throw RcException('offline', cause: failed is ClientFailed ? failed.error : null);
    }
    final current = _current;
    if (current != null && current.isOpen) return current;
    throw RcException('offline', route: (connected as ClientConnected).route);
  }

  /// Call a method on the host. Fails fast with [RcException] when offline.
  Future<Object?> call(String method, [Object? params, Duration? timeout]) async =>
      (await connection()).request(method, params, timeout);

  /// Follow a session's patches (or `*`); remembered across reconnects.
  Future<void> subscribe(String key) async {
    _subscriptions.add(key);
    final connection = await this.connection();
    if (_isCurrent(connection) && _subscribedOnCurrent.add(key)) {
      try {
        await connection.request('subscribe', {'key': key});
      } catch (_) {}
    }
  }

  Future<void> unsubscribe(String key) async {
    _subscriptions.remove(key);
    _subscribedOnCurrent.remove(key);
    final current = _current;
    if (current != null && current.isOpen) {
      try {
        await current.request('unsubscribe', {'key': key});
      } catch (_) {}
    }
  }

  Welcome? get welcome => switch (_state.value) {
        ClientConnected(:final welcome) => welcome,
        _ => null,
      };

  /// The route the connection is up on, or null when it is not.
  Route? get route => switch (_state.value) {
        ClientConnected(:final route) => route,
        _ => null,
      };

  /// An identity token for the connection currently up, or null. Attachments
  /// compare by identity: the desktop's upload stash dies with a connection,
  /// so a new one means staged ids are gone (S28).
  Object? get connectionMarker => _current;

  /// Release the streams, for good. [stop] first.
  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _state.close();
  }
}
