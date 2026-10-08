import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SecretKeyData;
// The AES block function itself is the package's (table-driven and fast);
// only GHASH is ours. The version is pinned exactly in pubspec.yaml because
// this reaches into an implementation file.
// ignore: implementation_imports
import 'package:cryptography/src/dart/aes_impl.dart' show aesEncryptBlock, aesExpandKeyForEncrypting;

import 'bytes.dart';
import 'crypto_error.dart';

/// AES-256-GCM with a 12-byte nonce and a 16-byte tag (NIST SP 800-38D),
/// prepared once per key.
///
/// It exists for speed. The `cryptography` package's GCM computes GHASH one
/// bit at a time — about 70 ms per MiB, nine tenths of the cost of opening a
/// frame — and the protocol moves megabyte frames (a transcript, a file).
/// This one multiplies in GF(2^128) four bits at a time against a table of
/// the sixteen multiples of H (Shoup's method, as in mbedTLS's `gcm.c`).
/// The tests hold it to the package's implementation on random inputs and to
/// the published test vectors.
///
/// 64-bit integer arithmetic throughout: native Dart only, which is every
/// platform this app ships on.
class GcmKey {
  GcmKey(List<int> key) : _expanded = _expand(key) {
    final h = Uint8List(16);
    _encryptBlock(Uint8List(16), h);
    _buildTable(h);
  }

  final Uint32List _expanded;
  final Uint64List _hh = Uint64List(16);
  final Uint64List _hl = Uint64List(16);

  // Scratch for one AES block: the AES function takes and gives Uint32 words
  // that are native-endian views of the byte block.
  final Uint8List _inBlock = Uint8List(16);
  late final Uint32List _inWords = Uint32List.view(_inBlock.buffer);
  final Uint32List _outWords = Uint32List(4);
  late final Uint8List _outBlock = Uint8List.view(_outWords.buffer);

  static Uint32List _expand(List<int> key) {
    if (key.length != 32) throw CryptoError('bad-key', 'AES key must be 32 bytes');
    return aesExpandKeyForEncrypting(SecretKeyData(Uint8List.fromList(key)));
  }

  void _encryptBlock(Uint8List input, Uint8List output) {
    _inBlock.setAll(0, input);
    aesEncryptBlock(_outWords, 0, _inWords, 0, _expanded);
    output.setAll(0, _outBlock);
  }

  static const List<int> _last4 = [
    0x0000, 0x1c20, 0x3840, 0x2460, 0x7080, 0x6ca0, 0x48c0, 0x54e0, //
    0xe100, 0xfd20, 0xd940, 0xc560, 0x9180, 0x8da0, 0xa9c0, 0xb5e0,
  ];

  /// `HH[i] ‖ HL[i] = i·H`, i read as a field element whose high-order bit is
  /// the lowest power of the polynomial — mbedTLS's `gcm_gen_table`.
  void _buildTable(Uint8List h) {
    final view = ByteData.sublistView(h);
    var vh = view.getUint64(0);
    var vl = view.getUint64(8);
    _hh[8] = vh;
    _hl[8] = vl;
    for (var i = 4; i > 0; i >>= 1) {
      final t = (vl & 1) * 0xe1000000;
      vl = (vh << 63) | (vl >>> 1);
      vh = (vh >>> 1) ^ (t << 32);
      _hh[i] = vh;
      _hl[i] = vl;
    }
    for (var i = 2; i <= 8; i *= 2) {
      final vhi = _hh[i];
      final vli = _hl[i];
      for (var j = 1; j < i; j++) {
        _hh[i + j] = vhi ^ _hh[j];
        _hl[i + j] = vli ^ _hl[j];
      }
    }
  }

  // The running GHASH state, as two 64-bit halves.
  int _zh = 0;
  int _zl = 0;

  /// `Y = (Y ⊕ X)·H` for one 16-byte block X given as two big-endian halves.
  void _ghashBlock(int xh, int xl) {
    xh ^= _zh;
    xl ^= _zl;
    var lo = xl & 0xf;
    var zh = _hh[lo];
    var zl = _hl[lo];
    for (var i = 15; i >= 0; i--) {
      final byte = i >= 8 ? (xl >>> ((15 - i) * 8)) & 0xff : (xh >>> ((7 - i) * 8)) & 0xff;
      lo = byte & 0xf;
      final hi = byte >>> 4;
      if (i != 15) {
        final rem = zl & 0xf;
        zl = (zh << 60) | (zl >>> 4);
        zh = zh >>> 4;
        zh ^= _last4[rem] << 48;
        zh ^= _hh[lo];
        zl ^= _hl[lo];
      }
      final rem = zl & 0xf;
      zl = (zh << 60) | (zl >>> 4);
      zh = zh >>> 4;
      zh ^= _last4[rem] << 48;
      zh ^= _hh[hi];
      zl ^= _hl[hi];
    }
    _zh = zh;
    _zl = zl;
  }

  void _ghashBytes(List<int> data, int start, int end) {
    final block = Uint8List(16);
    final view = ByteData.sublistView(block);
    var offset = start;
    while (offset + 16 <= end) {
      for (var j = 0; j < 16; j++) {
        block[j] = data[offset + j];
      }
      _ghashBlock(view.getUint64(0), view.getUint64(8));
      offset += 16;
    }
    if (offset < end) {
      block.fillRange(0, 16, 0);
      for (var j = 0; offset + j < end; j++) {
        block[j] = data[offset + j];
      }
      _ghashBlock(view.getUint64(0), view.getUint64(8));
    }
  }

  Uint8List _tag(Uint8List j0, List<int> aad, List<int> cipherText, int cipherLength) {
    _zh = 0;
    _zl = 0;
    _ghashBytes(aad, 0, aad.length);
    _ghashBytes(cipherText, 0, cipherLength);
    _ghashBlock(aad.length * 8, cipherLength * 8);
    final s = Uint8List(16);
    ByteData.sublistView(s)
      ..setUint64(0, _zh)
      ..setUint64(8, _zl);
    final ek = Uint8List(16);
    _encryptBlock(j0, ek);
    for (var j = 0; j < 16; j++) {
      s[j] ^= ek[j];
    }
    return s;
  }

  static Uint8List _j0(List<int> nonce) {
    if (nonce.length != 12) throw CryptoError('bad-key', 'nonce must be 12 bytes');
    return Uint8List(16)
      ..setAll(0, nonce)
      ..[15] = 1;
  }

  /// CTR from `inc32(J0)`, XORed into [out] in place.
  void _ctr(Uint8List j0, List<int> input, Uint8List out, int length) {
    final counter = Uint8List.fromList(j0);
    final counterView = ByteData.sublistView(counter);
    final stream = Uint8List(16);
    for (var offset = 0; offset < length; offset += 16) {
      counterView.setUint32(12, (counterView.getUint32(12) + 1) & 0xFFFFFFFF);
      _encryptBlock(counter, stream);
      final n = length - offset < 16 ? length - offset : 16;
      for (var j = 0; j < n; j++) {
        out[offset + j] = input[offset + j] ^ stream[j];
      }
    }
  }

  /// `ciphertext ‖ tag`.
  Uint8List seal(List<int> nonce, List<int> aad, List<int> plaintext) {
    final j0 = _j0(nonce);
    final out = Uint8List(plaintext.length + 16);
    _ctr(j0, plaintext, out, plaintext.length);
    out.setAll(plaintext.length, _tag(j0, aad, out, plaintext.length));
    return out;
  }

  /// The plaintext, or a `bad-frame` [CryptoError] when the tag does not verify.
  Uint8List open(List<int> nonce, List<int> aad, List<int> sealed) {
    if (sealed.length < 16) throw CryptoError('bad-frame', 'ciphertext too short');
    final j0 = _j0(nonce);
    final length = sealed.length - 16;
    final expected = _tag(j0, aad, sealed, length);
    if (!sameBytes(expected, sealed.sublist(length))) throw CryptoError('bad-frame', 'decryption failed');
    final out = Uint8List(length);
    _ctr(j0, sealed, out, length);
    return out;
  }
}
