import 'dart:typed_data';

import '../../protocol.dart';

/// The host half of the handshake, test-only: a port of the reference
/// `respond()` so tests can run a full handshake in-process and stand up a
/// fake host. The app never acts as a host, so this stays out of `lib/`.
class TestResponder {
  factory TestResponder(String hostId, KeyPair hostStatic, Hs1Frame hs1, [List<int>? psk]) {
    if (hs1.v != 1) throw CryptoError('unsupported-version');
    final mode = HandshakeMode.fromWire(hs1.mode) ?? (throw CryptoError('handshake-failed', 'bad mode'));
    if (hs1.host != hostId) throw CryptoError('wrong-host');
    final checkedPsk = Handshake.checkPsk(mode, psk);
    final h0 = Handshake.handshakeHash(mode, hostId);
    final clientEphemeral = B64u.decode(hs1.e, 32);
    final sealedStatic = B64u.decode(hs1.s, 48);
    final es = Primitives.dh(hostStatic.priv, clientEphemeral);
    final k1 = Handshake.staticKey(es, checkedPsk, h0);
    final Uint8List clientStatic;
    try {
      clientStatic = Handshake.openStatic(k1, h0, clientEphemeral, sealedStatic);
    } on CryptoError {
      throw CryptoError('handshake-failed');
    }
    if (clientStatic.length != 32) throw CryptoError('handshake-failed');
    return TestResponder._(hostStatic, mode, clientEphemeral, clientStatic, checkedPsk, h0, sealedStatic, es);
  }

  TestResponder._(
    this._hostStatic,
    this.mode,
    this.clientEphemeral,
    this.clientStatic,
    this._psk,
    this._h0,
    this._sealedStatic,
    this._es,
  );

  final KeyPair _hostStatic;
  final HandshakeMode mode;
  final Uint8List clientEphemeral;
  final Uint8List clientStatic;
  final Uint8List _psk;
  final Uint8List _h0;
  final Uint8List _sealedStatic;
  final Uint8List _es;

  (Hs2Frame, SessionKeys) complete([KeyPair? ephemeral]) {
    final eh = ephemeral ?? Primitives.generateKeyPair();
    final derived = Handshake.derive(
      es: _es,
      ss: Primitives.dh(_hostStatic.priv, clientStatic),
      ee: Primitives.dh(eh.priv, clientEphemeral),
      se: Primitives.dh(eh.priv, clientStatic),
      psk: _psk,
      h0: _h0,
      clientEphemeral: clientEphemeral,
      sealedStatic: _sealedStatic,
      hostEphemeral: eh.pub,
    );
    return (
      Hs2Frame(e: B64u.encode(eh.pub), c: B64u.encode(derived.confirm)),
      SessionKeys(send: derived.s2c, recv: derived.c2s, th: derived.th),
    );
  }
}
