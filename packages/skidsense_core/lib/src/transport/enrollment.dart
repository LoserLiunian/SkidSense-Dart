import '../protocol/crypto_error.dart';
import '../protocol/handshake.dart';
import '../protocol/pairing.dart';
import '../protocol/primitives.dart';
import '../protocol/protocol.dart';
import 'carrier.dart';
import 'errors.dart';
import 'inner.dart';
import 'rc_client.dart';
import 'rc_connection.dart';

/// What [Enrollment] reports as it walks the routes, for a progress line.
sealed class EnrollProgress {
  const EnrollProgress();
}

final class EnrollTrying extends EnrollProgress {
  const EnrollTrying(this.route);
  final Route route;
}

/// The first visit (spec §4, `enroll` mode): the pairing code from the QR is
/// the PSK, the backend's `rc-enroll` ticket goes in `hello`, and a `welcome`
/// means the host activated this device and recorded its key locally.
///
/// Tries the QR's LAN addresses first, then the relay (which admits a
/// pending device as long as its first frame is an enroll `hs1`). The
/// connection is closed afterwards; later visits are ordinary `connect`
/// handshakes with a grant.
abstract final class Enrollment {
  static Future<Welcome> enroll({
    required PairingPayload payload,
    required String deviceId,
    required KeyPair identity,
    required String ticket,
    required CarrierFactory carriers,
    ClientConfig config = const ClientConfig(),
    void Function(EnrollProgress progress)? onProgress,
  }) {
    if (ticket.isEmpty) throw ArgumentError.value(ticket, 'ticket', 'an enrol needs the backend ticket');
    return _reach(
      payload: payload,
      deviceId: deviceId,
      identity: identity,
      ticket: ticket,
      carriers: carriers,
      mode: HandshakeMode.enroll,
      psk: payload.code,
      config: config,
      onProgress: onProgress,
    );
  }

  /// The 409 recovery (spec §9): the phone is already paired to this host
  /// with a key the backend still lists as active, so `POST /devices` refused
  /// with the existing device id and no ticket. Fetch an `rc-access` grant
  /// for it and run an ordinary `connect` handshake — the same skeleton as
  /// [enroll], with the grant in `hello` instead of a ticket and no pairing
  /// code. A separate function so a caller holding a ticket can never take
  /// this path, nor one without a ticket the PSK one.
  static Future<Welcome> connectWithGrant({
    required PairingPayload payload,
    required String deviceId,
    required KeyPair identity,
    required String grant,
    required CarrierFactory carriers,
    ClientConfig config = const ClientConfig(),
    void Function(EnrollProgress progress)? onProgress,
  }) =>
      _reach(
        payload: payload,
        deviceId: deviceId,
        identity: identity,
        grant: grant,
        carriers: carriers,
        mode: HandshakeMode.connect,
        psk: null,
        config: config,
        onProgress: onProgress,
      );

  static Future<Welcome> _reach({
    required PairingPayload payload,
    required String deviceId,
    required KeyPair identity,
    String? grant,
    String? ticket,
    required CarrierFactory carriers,
    required HandshakeMode mode,
    required List<int>? psk,
    required ClientConfig config,
    void Function(EnrollProgress progress)? onProgress,
  }) async {
    final endpoint = HostEndpoint(
      hostId: payload.hostId,
      hostKey: payload.hostKey,
      deviceId: deviceId,
      lanAddrs: payload.lanAddrs,
      lanPort: payload.lanPort,
    );
    Object lastError = const RcException('no-route');
    // A refusal from something that spoke the protocol says more than "could
    // not connect".
    var reached = false;
    void unreachable(Object error) {
      if (!reached) lastError = error;
    }

    void refused(Object error) {
      reached = true;
      lastError = error;
    }

    for (final route in endpoint.routes()) {
      onProgress?.call(EnrollTrying(route));
      final timeout = route is RouteLan ? config.lanConnectTimeout : config.relayConnectTimeout;
      final Carrier carrier;
      try {
        carrier = await openBounded(carriers, route, CarrierTarget(payload.hostId, deviceId), timeout);
      } catch (error) {
        unreachable(error is CarrierUnavailable && error.reason == 'timeout'
            ? RcException('timeout', route: route, cause: error)
            : RcException('unreachable', route: route, cause: error));
        continue;
      }
      try {
        final initiator = Initiator(
          mode: mode,
          hostId: payload.hostId,
          hostStatic: payload.hostKey,
          clientStatic: identity,
          psk: psk,
        );
        final connection = await RcConnection.establish(
          carrier: carrier,
          route: route,
          initiator: initiator,
          grant: grant,
          ticket: ticket,
          config: config.connection,
        );
        final welcome = connection.welcome;
        await connection.close(mode == HandshakeMode.enroll ? 'enrolled' : 'reconnected');
        return welcome;
      } on HandshakeClosed catch (error) {
        // The carrier died before the welcome. This route is dead; the device is not.
        unreachable(error);
      } on HandshakeRejected catch (error) {
        // A plaintext `hsr` on a LAN address is forgeable by anything that
        // answers there, so it never settles anything on its own (C6): the
        // remaining routes still run. Only the same refusal through the relay
        // counts as the host's word, and only it stops the walk.
        if (error.permanent && route is RouteRelay) rethrow;
        refused(error);
      } on RelayRejected catch (error) {
        if (error.permanent) rethrow;
        refused(error);
      } on HelloRefused {
        // The ticket was refused: retrying elsewhere will not change that.
        rethrow;
      } on CryptoError catch (error) {
        refused(RcException(error.code, route: route, cause: error));
      } catch (error) {
        unreachable(RcException('unreachable', route: route, cause: error));
      }
    }
    throw lastError;
  }
}
