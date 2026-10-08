import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../protocol/bytes.dart';
import '../protocol/primitives.dart';

/// new-api's optional at-rest login encryption (spec §12; the desktop's
/// `src/main/password-crypto.ts`, the client half of `common.DecryptPassword`).
///
/// A fresh 32-byte AES key is wrapped with the server's RSA public key under
/// RSA-OAEP(SHA-256, MGF1-SHA-256, label `password-v2`), and the password is
/// sealed with AES-256-GCM whose AAD is `password-v2:<kid>`. Envelope:
/// `v2.<b64 wrappedKey>.<b64 nonce>.<b64 ciphertext‖tag>` in **standard**
/// base64 with padding — Go decodes it that way.
///
/// Pure Dart, so iOS builds it too — the reference client could not, because
/// Apple's `SecRsaOaep` refuses a label.
abstract final class PasswordEnvelope {
  static const _label = 'password-v2';

  static String encrypt(String password, String publicKeyPem, String keyId, {List<int>? aesKey, List<int>? nonce}) {
    final key = aesKey ?? Primitives.randomBytes(32);
    final iv = nonce ?? Primitives.randomBytes(12);
    final cipher = OAEPEncoding.withSHA256(RSAEngine(), utf8Bytes(_label))
      ..init(true, PublicKeyParameter<RSAPublicKey>(parseRsaPublicKey(publicKeyPem)));
    final wrapped = cipher.process(Uint8List.fromList(key));
    final sealed = Primitives.seal(key, iv, utf8Bytes('$_label:$keyId'), utf8Bytes(password));
    return ['v2', B64Std.encode(wrapped), B64Std.encode(iv), B64Std.encode(sealed)].join('.');
  }

  /// An RSA public key from PEM: SubjectPublicKeyInfo (`BEGIN PUBLIC KEY`) or
  /// PKCS#1 (`BEGIN RSA PUBLIC KEY`).
  static RSAPublicKey parseRsaPublicKey(String pem) {
    final body = pem
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('-----'))
        .join();
    final der = _Der(base64.decode(body));
    var seq = der.sequence();
    if (pem.contains('BEGIN RSA PUBLIC KEY')) return RSAPublicKey(seq.integer(), seq.integer());
    // SPKI: SEQUENCE { AlgorithmIdentifier, BIT STRING { RSAPublicKey } }
    seq.skip();
    final bits = seq.bitString();
    seq = _Der(bits).sequence();
    return RSAPublicKey(seq.integer(), seq.integer());
  }
}

/// Just enough DER to read a public key.
class _Der {
  _Der(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  (int, Uint8List) _element() {
    if (_offset + 2 > _bytes.length) throw const FormatException('truncated DER');
    final tag = _bytes[_offset++];
    var length = _bytes[_offset++];
    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      if (count == 0 || count > 4) throw const FormatException('bad DER length');
      length = 0;
      for (var index = 0; index < count; index++) {
        length = (length << 8) | _bytes[_offset++];
      }
    }
    if (_offset + length > _bytes.length) throw const FormatException('truncated DER');
    final content = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return (tag, content);
  }

  _Der sequence() {
    final (tag, content) = _element();
    if (tag != 0x30) throw const FormatException('expected a SEQUENCE');
    return _Der(content);
  }

  void skip() => _element();

  BigInt integer() {
    final (tag, content) = _element();
    if (tag != 0x02) throw const FormatException('expected an INTEGER');
    var value = BigInt.zero;
    for (final byte in content) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }

  Uint8List bitString() {
    final (tag, content) = _element();
    if (tag != 0x03 || content.isEmpty || content[0] != 0) throw const FormatException('expected a BIT STRING');
    return Uint8List.sublistView(content, 1);
  }
}
