import 'dart:typed_data';

import 'bytes.dart';
import 'crypto_error.dart';
import 'primitives.dart';
import 'protocol.dart';

/// History hosting (spec §11): the host's history key `K` arrives wrapped to
/// this device's static X25519 key (ECIES), and each session is a sealed blob
/// bound to its host, session key and key epoch.
///
/// The phone only ever unwraps and opens; [wrapKey] and [sealBlob] exist so
/// the known-answer vectors can be reproduced and the round trip tested.
abstract final class HistoryCrypto {
  static const _labelWrap = '${Protocol.name} wrap';
  static final Uint8List _zeroNonce = Uint8List(12);

  /// AAD for a history-key wrap: which host, which epoch.
  static Uint8List wrapContext(String hostId, int epoch) => concat([
        utf8Bytes('${Protocol.name} history-key'),
        zeroByte,
        utf8Bytes(hostId),
        zeroByte,
        u32be(epoch),
      ]);

  /// AAD for one stored session: the backend cannot swap one session's blob
  /// in for another's.
  static Uint8List historyAad(String hostId, String sessionKey, int epoch) => concat([
        utf8Bytes('${Protocol.name} history'),
        zeroByte,
        utf8Bytes(hostId),
        zeroByte,
        utf8Bytes(sessionKey),
        zeroByte,
        u32be(epoch),
      ]);

  /// `e.pub (32) ‖ AEAD(kek, 0-nonce, context, key) (48)` — 80 bytes.
  static Uint8List wrapKey(List<int> key, List<int> recipient, List<int> context, {KeyPair? ephemeral}) {
    if (key.length != 32) throw CryptoError('bad-key', 'the wrapped key must be 32 bytes');
    final e = ephemeral ?? Primitives.generateKeyPair();
    final kek = Primitives.hkdf(Primitives.dh(e.priv, recipient), concat([e.pub, recipient]), _labelWrap);
    return concat([e.pub, Primitives.seal(kek, _zeroNonce, context, key)]);
  }

  static Uint8List unwrapKey(List<int> wrapped, KeyPair recipient, List<int> context) {
    if (wrapped.length != 80) throw CryptoError('bad-key', 'a wrapped key is 80 bytes');
    final epub = wrapped.sublist(0, 32);
    final kek = Primitives.hkdf(Primitives.dh(recipient.priv, epub), concat([epub, recipient.pub]), _labelWrap);
    return Primitives.open(kek, _zeroNonce, context, wrapped.sublist(32, 80));
  }

  /// `nonce (12, random) ‖ ciphertext ‖ tag (16)`.
  static Uint8List sealBlob(List<int> key, List<int> aad, List<int> plaintext, {List<int>? nonce}) {
    final iv = nonce ?? Primitives.randomBytes(12);
    if (iv.length != 12) throw CryptoError('bad-key', 'nonce must be 12 bytes');
    return concat([iv, Primitives.seal(key, iv, aad, plaintext)]);
  }

  static Uint8List openBlob(List<int> key, List<int> aad, List<int> blob) {
    if (blob.length < 28) throw CryptoError('bad-frame', 'ciphertext too short');
    return Primitives.open(key, blob.sublist(0, 12), aad, blob.sublist(12));
  }
}

/// A human-checkable fingerprint of a host key (spec §3): the first 8 bytes
/// of SHA-256, upper-case hex, in groups of four — `D511-0BBB-BA1D-667B`.
String hostFingerprint(List<int> publicKey) {
  final hex = bytesToHex(Primitives.sha256([publicKey]).sublist(0, 8), upper: true);
  return [for (var index = 0; index < hex.length; index += 4) hex.substring(index, index + 4)].join('-');
}
