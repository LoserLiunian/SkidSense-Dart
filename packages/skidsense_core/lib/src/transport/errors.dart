import 'carrier.dart';

/// Everything that can go wrong talking to a host.
///
/// [code] says what kind of failure it is and is what the app words for the
/// user; [detail] is a more specific machine-readable cause where one exists
/// (a crypto code such as `out-of-order`, a relay or `hsr` code); [message]
/// is text the *far end* wrote, shown as-is when present (the desktop's own
/// sentence in an `ok:false`, a `bye` reason).
class RcException implements Exception {
  const RcException(this.code, {this.detail, this.message, this.route, this.cause, this.retryAfter});

  final String code;
  final String? detail;
  final String? message;

  /// The route this happened on, when one was involved.
  final HostRoute? route;
  final Object? cause;

  /// How long the far end said to wait before asking again (a 429's
  /// `Retry-After`), when it said.
  final Duration? retryAfter;

  @override
  String toString() {
    final parts = [
      code,
      if (detail != null) detail,
      if (route != null) route!.describe(),
      if (message != null) '“$message”',
    ];
    return '$runtimeType(${parts.join(', ')})';
  }
}

/// The host answered `ok:false` (spec §6.2): [code] is the host's,
/// [message] its sentence.
class RemoteCallError extends RcException {
  const RemoteCallError(super.code, String message) : super(message: message);
}

/// The host refused the handshake with `hsr` (spec §4.6). [code] is the `hsr` code.
class HandshakeRejected extends RcException {
  const HandshakeRejected(super.code, {super.message, super.route});

  /// Codes that will not change by retrying the same thing.
  bool get permanent => const {'unknown-device', 'disabled', 'unsupported-version', 'enroll-closed'}.contains(code);
}

/// The relay itself refused (spec §10.2), before or instead of the host.
/// `unauthorized` says the bearer is no good; `host-closed` is the desktop
/// ending this session, [message] its reason when it gave one — nothing
/// about the bearer or the grant, so nothing is invalidated and the client
/// reconnects.
class RelayRejected extends RcException {
  const RelayRejected(super.code, {super.message, super.route});

  bool get permanent => code == 'revoked';
}

/// The desktop ended the connection and said why (spec §6.5, C5). A kick
/// whose grant scopes no longer stand must make the reconnect ask the backend
/// for a new grant: the cached `rc-access` still lists the old ones for up to
/// an hour, so reconnecting with it brings back exactly what the kick was
/// meant to change.
class HostBye extends RcException {
  const HostBye(this.byeCode, {String? reason}) : super('bye', detail: byeCode, message: reason);

  final String? byeCode;

  bool get regrant => byeCode == 'scopes-changed' || byeCode == 'revoked';
}

/// The connection ended: carrier closed, protocol violation, timeout, our own
/// close. [detail] names which (`peer-closed`, `idle`, `handshake-timeout`,
/// `closed`, `relay-frame-on-lan`, `not-data`, `unparsable`, or the crypto
/// code of a frame that failed: `out-of-order`, `bad-frame`, …).
class ConnectionClosed extends RcException {
  const ConnectionClosed(String detail, {super.route, super.cause}) : super('closed', detail: detail);
}

/// The connection ended *while the handshake between `hs2` and `welcome` was
/// still in doubt*: the carrier dropped mid-hello, or a plaintext frame
/// arrived after the host had proven its key. Distinct from both a refusal
/// ([HandshakeRejected]) and an established connection dying: this route is
/// dead, and the device is not (spec §6.5, C6).
class HandshakeClosed extends ConnectionClosed {
  const HandshakeClosed(super.detail, {super.route, super.cause});
}

/// `bye` in answer to `hello`: the grant or ticket was not accepted.
class HelloRefused extends RcException {
  const HelloRefused(String? reason) : super('hello-refused', message: reason);
}
