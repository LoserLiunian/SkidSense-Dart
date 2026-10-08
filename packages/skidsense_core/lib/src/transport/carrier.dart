import 'dart:async';

/// Something that moves outer frames (spec §4–§5) as text messages: a LAN
/// WebSocket straight to the desktop, a relay WebSocket through the backend,
/// or an in-memory pipe in tests. Both real carriers carry byte-identical
/// frames (spec §10.2, §10.4), which is why one client speaks both.
abstract interface class Carrier {
  /// The next text message from the far end, or `null` once the carrier has
  /// closed and everything it delivered has been read. [timeout] bounds the
  /// wait with a `TimeoutException`.
  Future<String?> receive({Duration? timeout});

  /// Queue [text] for sending. Synchronous on purpose: frames go out in the
  /// order this is called, which is the order their counters were assigned.
  /// Throws `ConnectionClosed` once the carrier is closed.
  void send(String text);

  /// Close the carrier. Idempotent.
  Future<void> close([String reason = '']);

  /// A short label for logs.
  String get label;
}

/// Where a carrier goes.
sealed class HostRoute {
  const HostRoute();

  /// For logs; the app words routes itself.
  String describe();
}

final class RouteLan extends HostRoute {
  const RouteLan(this.address, this.port);

  final String address;
  final int port;

  @override
  String describe() => 'lan $address:$port';

  @override
  bool operator ==(Object other) => other is RouteLan && other.address == address && other.port == port;

  @override
  int get hashCode => Object.hash(address, port);

  @override
  String toString() => 'RouteLan($address, $port)';
}

final class RouteRelay extends HostRoute {
  const RouteRelay();

  @override
  String describe() => 'relay';

  @override
  bool operator ==(Object other) => other is RouteRelay;

  @override
  int get hashCode => 7;

  @override
  String toString() => 'RouteRelay()';
}

/// Everything a factory needs to address one host for one device.
class CarrierTarget {
  const CarrierTarget(this.hostId, this.deviceId);

  final String hostId;

  /// Null before the device is registered (never the case for a real connection).
  final String? deviceId;
}

/// Opens carriers. Throws [CarrierUnavailable] when the far end cannot be
/// reached. An implementation that does network I/O gives up within
/// [timeout] and releases what it opened; the client adds its own bound and
/// closes anything that arrives after it.
abstract interface class CarrierFactory {
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout});
}

/// The carrier could not be opened at all (refused, timed out, DNS…).
/// [reason]: `refused`, `timeout`, `no-credentials`, `no-relay`, `upgrade`
/// (the far end answered but not as a WebSocket), `too-large`, or `io`.
class CarrierUnavailable implements Exception {
  const CarrierUnavailable(this.reason, [this.detail]);

  final String reason;
  final String? detail;

  @override
  String toString() => 'CarrierUnavailable($reason${detail == null ? '' : ': $detail'})';
}

/// [CarrierFactory.open] bounded by [timeout] on the caller's side as well:
/// a carrier that opens after the caller stopped waiting is closed, never
/// leaked.
Future<Carrier> openBounded(CarrierFactory carriers, HostRoute route, CarrierTarget target, Duration timeout) {
  final completer = Completer<Carrier>();
  var done = false;
  final timer = Timer(timeout, () {
    if (done) return;
    done = true;
    completer.completeError(CarrierUnavailable('timeout', route.describe()));
  });
  Future<Carrier>.sync(() => carriers.open(route, target, timeout: timeout)).then((carrier) {
    if (done) {
      unawaited(carrier.close('late'));
      return;
    }
    done = true;
    timer.cancel();
    completer.complete(carrier);
  }, onError: (Object error, StackTrace stack) {
    if (done) return;
    done = true;
    timer.cancel();
    completer.completeError(error, stack);
  });
  return completer.future;
}
