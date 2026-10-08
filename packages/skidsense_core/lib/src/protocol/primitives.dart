import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'bytes.dart';
import 'crypto_error.dart';
import 'gcm.dart';

/// A raw 32-byte X25519 key pair — raw so it serialises and compares.
class KeyPair {
  KeyPair(this.priv, this.pub) {
    if (priv.length != 32 || pub.length != 32) {
      throw ArgumentError('X25519 keys are 32 bytes');
    }
  }

  final Uint8List priv;
  final Uint8List pub;
}

/// The primitives of spec §2.
///
/// Everything is synchronous and pure Dart, the same on every platform and
/// API level: no provider lookup can be missing X25519 (the hole Android below
/// API 33 has, see the reference's `docs/crypto-on-old-android.md`), and
/// because sealing never yields to the event loop, a frame's counter is
/// assigned and its bytes produced in one step — the send order *is* the
/// counter order without any lock.
abstract final class Primitives {
  static final Random _random = Random.secure();
  static const DartSha256 _sha256 = DartSha256();
  static const DartHmac _hmac = DartHmac(DartSha256());
  static const DartX25519 _x25519 = DartX25519();

  static final Uint8List _basePoint = Uint8List(32)..[0] = 9;

  static Uint8List randomBytes(int size) {
    final out = Uint8List(size);
    for (var index = 0; index < size; index++) {
      out[index] = _random.nextInt(256);
    }
    return out;
  }

  static Uint8List sha256(List<List<int>> parts) =>
      Uint8List.fromList(_sha256.hashSync(concat(parts)).bytes);

  /// RFC 5869 HKDF-SHA256 with a 32-byte output and a UTF-8 [info].
  static Uint8List hkdf(List<int> ikm, List<int> salt, String info) {
    // Extract: PRK = HMAC(salt, IKM). An empty salt is a hash-length zero key.
    final prk = hmacSha256(salt.isEmpty ? Uint8List(32) : salt, ikm);
    // Expand, one block: T(1) = HMAC(PRK, info ‖ 0x01) is exactly 32 bytes.
    return hmacSha256(prk, concat([utf8Bytes(info), const [1]]));
  }

  static Uint8List hmacSha256(List<int> key, List<int> message) => Uint8List.fromList(
        _hmac.calculateMacSync(message, secretKeyData: SecretKeyData(key), nonce: const []).bytes,
      );

  /// AES-256-GCM, 12-byte nonce, the 16-byte tag appended to the ciphertext.
  static Uint8List seal(List<int> key, List<int> nonce, List<int> aad, List<int> plaintext) =>
      GcmKey(key).seal(nonce, aad, plaintext);

  static Uint8List open(List<int> key, List<int> nonce, List<int> aad, List<int> sealed) {
    if (sealed.length < 16) throw CryptoError('bad-frame', 'ciphertext too short');
    return GcmKey(key).open(nonce, aad, sealed);
  }

  static KeyPair generateKeyPair() => keyPairFromPrivate(randomBytes(32));

  /// Any 32 bytes are a valid X25519 private key: the scalar is clamped when used.
  static KeyPair keyPairFromPrivate(List<int> priv) {
    if (priv.length != 32) throw CryptoError('bad-key', 'X25519 private key must be 32 bytes');
    return KeyPair(Uint8List.fromList(priv), _scalarMult(priv, _basePoint));
  }

  /// X25519, refusing an all-zero result (spec §2).
  ///
  /// A low-order peer key forces the shared secret to zero whatever our
  /// private key is, which would make that DH term contribute nothing.
  static Uint8List dh(List<int> priv, List<int> pub) {
    if (priv.length != 32) throw CryptoError('bad-key', 'X25519 private key must be 32 bytes');
    if (pub.length != 32) throw CryptoError('bad-key', 'X25519 public key must be 32 bytes');
    final Uint8List out;
    try {
      out = _scalarMult(priv, pub);
    } catch (error) {
      throw CryptoError('bad-key', 'key agreement failed', error);
    }
    if (out.length != 32 || isAllZero(out)) throw CryptoError('bad-key', 'key agreement failed');
    return out;
  }

  static Uint8List _scalarMult(List<int> priv, List<int> point) {
    final secret = _x25519.sharedSecretSync(
      keyPairData: SimpleKeyPairData(
        priv,
        // The mixin wants a pair; the public half is never read here.
        publicKey: SimplePublicKey(Uint8List(32), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      ),
      remotePublicKey: SimplePublicKey(point, type: KeyPairType.x25519),
    );
    return Uint8List.fromList((secret as SecretKeyData).bytes);
  }
}
