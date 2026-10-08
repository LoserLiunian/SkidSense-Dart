import 'dart:convert';
import 'dart:typed_data';

import 'crypto_error.dart';

/// Byte-level encoding for `skidsense-rc/1` (spec §2).
///
/// Every binary field on the wire is base64url **without padding**, and
/// decoding is strict: another alphabet, padding, or a non-canonical encoding
/// (one whose unused trailing bits are not zero, so that two strings would
/// name the same bytes) is refused. The check is the reference
/// implementation's own: decode, re-encode, and require the result to equal
/// the input.
abstract final class B64u {
  static final RegExp _alphabet = RegExp(r'^[A-Za-z0-9_-]*$');

  static String encode(List<int> data) {
    final padded = base64Url.encode(data);
    final end = padded.indexOf('=');
    return end < 0 ? padded : padded.substring(0, end);
  }

  /// Strict decode; [length] when given is the exact decoded length required.
  static Uint8List decode(String? text, [int? length]) {
    if (text == null || !_alphabet.hasMatch(text) || text.length % 4 == 1) {
      throw CryptoError('bad-encoding', 'invalid base64url');
    }
    final Uint8List out;
    try {
      out = base64Url.decode(text + '=' * ((4 - text.length % 4) % 4));
    } on FormatException {
      throw CryptoError('bad-encoding', 'invalid base64url');
    }
    if (encode(out) != text) throw CryptoError('bad-encoding', 'non-canonical base64url');
    if (length != null && out.length != length) {
      throw CryptoError('bad-encoding', 'expected $length bytes, got ${out.length}');
    }
    return out;
  }
}

/// Standard base64 with padding — only for new-api's password envelope
/// (§12), which Go decodes that way.
abstract final class B64Std {
  static String encode(List<int> data) => base64.encode(data);
  static Uint8List decode(String text) => base64.decode(text);
}

Uint8List utf8Bytes(String text) => utf8.encode(text);

/// The UTF-8 length of [text], without encoding it. The protocol's limits are
/// in bytes (spec §5, §6.3); `String.length` counts UTF-16 units, and for the
/// Chinese text this app carries those differ threefold. A lone surrogate
/// counts as the three bytes of U+FFFD it would encode to.
int utf8Length(String text) {
  var total = 0;
  var index = 0;
  final length = text.length;
  while (index < length) {
    final unit = text.codeUnitAt(index);
    if (unit < 0x80) {
      total += 1;
    } else if (unit < 0x800) {
      total += 2;
    } else if (unit >= 0xD800 &&
        unit <= 0xDBFF &&
        index + 1 < length &&
        (text.codeUnitAt(index + 1) & 0xFC00) == 0xDC00) {
      total += 4;
      index += 1;
    } else {
      total += 3;
    }
    index += 1;
  }
  return total;
}

/// Strict UTF-8 decode (spec §5): a lone surrogate or an overlong form is not
/// text the far end sent, so it is refused rather than replaced with U+FFFD.
String strictUtf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw CryptoError('bad-frame', 'frame is not valid UTF-8');
  }
}

Uint8List u64be(int value) {
  if (value < 0) throw ArgumentError.value(value, 'value', 'must be non-negative');
  final out = Uint8List(8);
  ByteData.sublistView(out).setUint64(0, value);
  return out;
}

Uint8List u32be(int value) {
  if (value < 0 || value > 0xFFFFFFFF) throw ArgumentError.value(value, 'value', 'out of u32 range');
  final out = Uint8List(4);
  ByteData.sublistView(out).setUint32(0, value);
  return out;
}

Uint8List concat(List<List<int>> parts) {
  var size = 0;
  for (final part in parts) {
    size += part.length;
  }
  final out = Uint8List(size);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}

final Uint8List zeroByte = Uint8List(1);

/// Constant-time comparison: the time taken does not depend on where the
/// first difference is.
bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var index = 0; index < a.length; index++) {
    diff |= a[index] ^ b[index];
  }
  return diff == 0;
}

bool isAllZero(List<int> bytes) {
  var acc = 0;
  for (final byte in bytes) {
    acc |= byte;
  }
  return acc == 0;
}

Uint8List hexToBytes(String hex) {
  if (hex.length.isOdd) throw ArgumentError.value(hex, 'hex', 'odd length');
  final out = Uint8List(hex.length ~/ 2);
  for (var index = 0; index < out.length; index++) {
    out[index] = int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16);
  }
  return out;
}

String bytesToHex(List<int> bytes, {bool upper = false}) {
  final digits = upper ? '0123456789ABCDEF' : '0123456789abcdef';
  final out = StringBuffer();
  for (final byte in bytes) {
    out
      ..write(digits[(byte >> 4) & 0x0F])
      ..write(digits[byte & 0x0F]);
  }
  return out.toString();
}
