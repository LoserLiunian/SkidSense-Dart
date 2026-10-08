import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/src/api/password_envelope.dart';
import 'package:test/test.dart';

/// The login password envelope (spec §12). The wire format was cross-checked
/// once against OpenSSL 3 (`pkeyutl -decrypt` with `rsa_oaep_label`); these
/// tests pin it with an RSA key made here and opened by hand below.
void main() {
  final keyPair = () {
    final random = FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));
    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), random));
    return generator.generateKeyPair();
  }();
  final publicKey = keyPair.publicKey;
  final privateKey = keyPair.privateKey;

  Uint8List der(int tag, List<int> content) {
    final length = content.length;
    final header = length < 0x80
        ? [tag, length]
        : length < 0x100
            ? [tag, 0x81, length]
            : [tag, 0x82, length >> 8, length & 0xff];
    return Uint8List.fromList([...header, ...content]);
  }

  Uint8List derInt(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    var bytes = hexToBytes(hex);
    if (bytes[0] & 0x80 != 0) bytes = Uint8List.fromList([0, ...bytes]);
    return der(0x02, bytes);
  }

  String pem(String label, List<int> body) {
    final text = base64.encode(body);
    final lines = [for (var i = 0; i < text.length; i += 64) text.substring(i, min(i + 64, text.length))];
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }

  final pkcs1 = der(0x30, [...derInt(publicKey.modulus!), ...derInt(publicKey.publicExponent!)]);
  final rsaEncryptionOid = hexToBytes('06092a864886f70d0101010500');
  final spki = der(0x30, [...der(0x30, rsaEncryptionOid), ...der(0x03, [0, ...pkcs1])]);
  final spkiPem = pem('PUBLIC KEY', spki);

  String decryptV2(String envelope, {String label = 'password-v2', String kid = 'kid-7'}) {
    final parts = envelope.split('.');
    expect(parts, hasLength(4));
    expect(parts[0], 'v2');
    final oaep = OAEPEncoding.withSHA256(RSAEngine(), utf8Bytes(label))
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final aesKey = oaep.process(base64.decode(parts[1]));
    expect(aesKey, hasLength(32));
    return utf8.decode(Primitives.open(aesKey, base64.decode(parts[2]), utf8Bytes('password-v2:$kid'), base64.decode(parts[3])));
  }

  test('the envelope opens with the v2 label', () {
    expect(decryptV2(PasswordEnvelope.encrypt('s3cret-密码', spkiPem, 'kid-7')), 's3cret-密码');
  });

  test('a PKCS#1 key works as well as SubjectPublicKeyInfo', () {
    final envelope = PasswordEnvelope.encrypt('pw', pem('RSA PUBLIC KEY', pkcs1), 'kid-7');
    expect(decryptV2(envelope), 'pw');
  });

  test('a wrong label or kid does not open', () {
    final envelope = PasswordEnvelope.encrypt('x', spkiPem, 'kid-7');
    expect(() => decryptV2(envelope, label: 'password-v1'), throwsA(anything), reason: 'the label is part of OAEP');
    expect(() => decryptV2(envelope, kid: 'kid-8'), throwsA(isA<CryptoError>()), reason: 'the kid is in the AAD');
  });

  test('every envelope carries a fresh key and nonce', () {
    final a = PasswordEnvelope.encrypt('same', spkiPem, 'kid-7').split('.');
    final b = PasswordEnvelope.encrypt('same', spkiPem, 'kid-7').split('.');
    expect(a[1], isNot(b[1]));
    expect(a[2], isNot(b[2]));
    expect(a[3], isNot(b[3]));
  });

  test('the envelope is standard base64, not url-safe, with the reference layout', () {
    final password = '${'a' * 600}汉字';
    final envelope = PasswordEnvelope.encrypt(password, spkiPem, 'kid-7');
    expect(envelope.contains('-') || envelope.contains('_'), isFalse);
    expect(decryptV2(envelope), password);
    final parts = PasswordEnvelope.encrypt('pw', spkiPem, 'kid').split('.');
    expect(base64.decode(parts[1]), hasLength(256), reason: '2048-bit RSA wraps the key in 256 bytes');
    expect(base64.decode(parts[2]), hasLength(12));
    expect(base64.decode(parts[3]), hasLength(2 + 16), reason: 'ciphertext plus a 16-byte tag');
  });
}
