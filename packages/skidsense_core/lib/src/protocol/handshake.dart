import 'dart:typed_data';

import 'bytes.dart';
import 'crypto_error.dart';
import 'outer_frames.dart';
import 'primitives.dart';
import 'protocol.dart';

/// The device side of the `skidsense-rc/1` handshake (spec §4).
///
/// Modelled on Noise IK, not an implementation of it: the device already
/// holds the host's static key (pinned from the pairing QR, never learned
/// from the network), and four DH terms go into one HKDF over the transcript
/// hash —
///
///     es = DH(e_c, S_h)   only the real host can compute this
///     ss = DH(S_c, S_h)   binds the two long-term identities
///     ee = DH(e_c, e_h)   forward secrecy
///     se = DH(S_c, e_h)   authenticates the device
///
/// so a relay that swaps either ephemeral key derives keys neither end does,
/// and cannot produce the host's confirmation tag.
abstract final class Handshake {
  static const labelStatic = '${Protocol.name} static';
  static const labelC2s = '${Protocol.name} c2s';
  static const labelS2c = '${Protocol.name} s2c';
  static const labelConfirm = '${Protocol.name} confirm';

  static final Uint8List _zeroNonce = Uint8List(12);

  /// `h0`: binds the protocol, the mode and the intended host into everything after.
  static Uint8List handshakeHash(HandshakeMode mode, String hostId) => Primitives.sha256([
        utf8Bytes(Protocol.name),
        zeroByte,
        utf8Bytes(mode.wire),
        zeroByte,
        utf8Bytes(hostId),
      ]);

  /// `enroll` needs the 32-byte pairing code; `connect` takes none.
  static Uint8List checkPsk(HandshakeMode mode, List<int>? psk) {
    switch (mode) {
      case HandshakeMode.enroll:
        if (psk == null || psk.length != 32) throw CryptoError('bad-key', 'the pairing code must be 32 bytes');
        return Uint8List.fromList(psk);
      case HandshakeMode.connect:
        if (psk != null && psk.isNotEmpty) throw CryptoError('bad-key', 'connect mode takes no pairing code');
        return Uint8List(0);
    }
  }

  static Derived derive({
    required List<int> es,
    required List<int> ss,
    required List<int> ee,
    required List<int> se,
    required List<int> psk,
    required List<int> h0,
    required List<int> clientEphemeral,
    required List<int> sealedStatic,
    required List<int> hostEphemeral,
  }) {
    final ikm = concat([es, ss, ee, se, psk]);
    final th = Primitives.sha256([h0, clientEphemeral, sealedStatic, hostEphemeral]);
    final confirmKey = Primitives.hkdf(ikm, th, labelConfirm);
    return Derived(
      c2s: Primitives.hkdf(ikm, th, labelC2s),
      s2c: Primitives.hkdf(ikm, th, labelS2c),
      confirm: Primitives.hmacSha256(confirmKey, th),
      th: th,
    );
  }

  static Uint8List sealStatic(List<int> k1, List<int> h0, List<int> clientEphemeral, List<int> clientStaticPub) =>
      Primitives.seal(k1, _zeroNonce, concat([h0, clientEphemeral]), clientStaticPub);

  static Uint8List openStatic(List<int> k1, List<int> h0, List<int> clientEphemeral, List<int> sealed) =>
      Primitives.open(k1, _zeroNonce, concat([h0, clientEphemeral]), sealed);

  static Uint8List staticKey(List<int> es, List<int> psk, List<int> h0) =>
      Primitives.hkdf(concat([es, psk]), h0, labelStatic);
}

class Derived {
  const Derived({required this.c2s, required this.s2c, required this.confirm, required this.th});

  final Uint8List c2s;
  final Uint8List s2c;
  final Uint8List confirm;
  final Uint8List th;
}

/// The keys one end of a finished handshake uses.
class SessionKeys {
  const SessionKeys({required this.send, required this.recv, required this.th});

  final Uint8List send;
  final Uint8List recv;
  final Uint8List th;
}

/// The device half: [hs1] to send, then [finish] turns the host's `hs2` into
/// session keys — or throws `handshake-failed` when the confirmation does
/// not match, i.e. the far end does not hold the pinned host key.
///
/// [ephemeral] is for the known-answer vectors only; production passes nothing.
class Initiator {
  factory Initiator({
    required HandshakeMode mode,
    required String hostId,
    required List<int> hostStatic,
    required KeyPair clientStatic,
    List<int>? psk,
    KeyPair? ephemeral,
  }) {
    final checkedPsk = Handshake.checkPsk(mode, psk);
    final h0 = Handshake.handshakeHash(mode, hostId);
    final e = ephemeral ?? Primitives.generateKeyPair();
    if (hostStatic.length != 32) throw CryptoError('bad-key', 'the host key must be 32 bytes');
    final es = Primitives.dh(e.priv, hostStatic);
    final k1 = Handshake.staticKey(es, checkedPsk, h0);
    final sealedStatic = Handshake.sealStatic(k1, h0, e.pub, clientStatic.pub);
    final hs1 = Hs1Frame(
      v: Protocol.version,
      mode: mode.wire,
      host: hostId,
      e: B64u.encode(e.pub),
      s: B64u.encode(sealedStatic),
    );
    return Initiator._(mode, hostId, Uint8List.fromList(hostStatic), clientStatic, checkedPsk, h0, e, es, sealedStatic, hs1);
  }

  Initiator._(
    this.mode,
    this.hostId,
    this._hostStatic,
    this._clientStatic,
    this._psk,
    this._h0,
    this._e,
    this._es,
    this._sealedStatic,
    this.hs1,
  );

  final HandshakeMode mode;
  final String hostId;
  final Uint8List _hostStatic;
  final KeyPair _clientStatic;
  final Uint8List _psk;
  final Uint8List _h0;
  final KeyPair _e;
  final Uint8List _es;
  final Uint8List _sealedStatic;
  final Hs1Frame hs1;

  SessionKeys finish(Hs2Frame hs2) {
    final eh = B64u.decode(hs2.e, 32);
    final confirm = B64u.decode(hs2.c, 32);
    final derived = Handshake.derive(
      es: _es,
      ss: Primitives.dh(_clientStatic.priv, _hostStatic),
      ee: Primitives.dh(_e.priv, eh),
      se: Primitives.dh(_clientStatic.priv, eh),
      psk: _psk,
      h0: _h0,
      clientEphemeral: _e.pub,
      sealedStatic: _sealedStatic,
      hostEphemeral: eh,
    );
    // This is what proves the far end holds the host's private key: `es` on
    // its side needs it. Without the check a relay could answer with any
    // ephemeral key and the failure would only show up as garbage later.
    if (!sameBytes(confirm, derived.confirm)) {
      throw CryptoError('handshake-failed', 'host confirmation does not match the pinned key');
    }
    return SessionKeys(send: derived.c2s, recv: derived.s2c, th: derived.th);
  }
}
