import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/src/protocol/gcm.dart';
import 'package:test/test.dart';

/// [GcmKey] is a hand-written GHASH: it must agree with the `cryptography`
/// package's reference implementation everywhere, and with the published
/// test vectors.
void main() {
  test('matches the McGrew–Viega test case 16 (AES-256, 60-byte text, AAD)', () {
    final key = hexToBytes('feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308');
    final nonce = hexToBytes('cafebabefacedbaddecaf888');
    final plaintext = hexToBytes(
      'd9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39',
    );
    final aad = hexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');
    final sealed = GcmKey(key).seal(nonce, aad, plaintext);
    expect(
      bytesToHex(sealed.sublist(0, plaintext.length)),
      '522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662',
    );
    expect(bytesToHex(sealed.sublist(plaintext.length)), '76fc6ece0f4e1768cddf8853bb2d551b');
    expect(GcmKey(key).open(nonce, aad, sealed), plaintext);
  });

  test('matches test case 13 (AES-256, empty everything)', () {
    final sealed = GcmKey(Uint8List(32)).seal(Uint8List(12), const [], const []);
    expect(bytesToHex(sealed), '530f8afbc74536b9a963b4f1c4cb738b');
  });

  test('agrees with the reference implementation on random inputs', () {
    final random = Random(7);
    final reference = DartAesGcm.with256bits();
    Uint8List bytes(int n) => Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));
    for (var round = 0; round < 300; round++) {
      final key = bytes(32);
      final nonce = bytes(12);
      final aad = bytes(random.nextInt(40));
      final plaintext = bytes(round < 50 ? round : random.nextInt(5000));
      final ours = GcmKey(key).seal(nonce, aad, plaintext);
      final theirs = reference.encryptSync(plaintext, secretKeyData: SecretKeyData(key), nonce: nonce, aad: aad);
      expect(ours, [...theirs.cipherText, ...theirs.mac.bytes], reason: 'round $round');
      expect(GcmKey(key).open(nonce, aad, ours), plaintext);
    }
  });

  test('refuses a wrong tag, a wrong AAD and a flipped bit', () {
    final key = GcmKey(Primitives.randomBytes(32));
    final nonce = Primitives.randomBytes(12);
    final sealed = key.seal(nonce, [1, 2, 3], utf8Bytes('密文'));
    expect(() => key.open(nonce, [1, 2, 4], sealed), throwsA(isA<CryptoError>()));
    for (final index in [0, sealed.length - 1]) {
      final flipped = Uint8List.fromList(sealed)..[index] ^= 0x80;
      expect(() => key.open(nonce, [1, 2, 3], flipped), throwsA(isA<CryptoError>()));
    }
  });
}
