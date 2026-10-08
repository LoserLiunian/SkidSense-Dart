import 'dart:convert';

import 'bytes.dart';
import 'crypto_error.dart';
import 'protocol.dart';

/// The outer layer (spec §4–§5): what a carrier — a LAN socket or the relay —
/// sees. `hs1`/`hs2`/`hsr` during the handshake, then `d` frames of
/// ciphertext. Field order matches the reference so serialised frames are
/// byte-identical.
class Hs1Frame {
  const Hs1Frame({required this.v, required this.mode, required this.host, required this.e, required this.s});

  final int v;
  final String mode;
  final String host;
  final String e;
  final String s;

  Map<String, Object?> toJson() => {'t': 'hs1', 'v': v, 'mode': mode, 'host': host, 'e': e, 's': s};

  Hs1Frame copyWith({int? v, String? mode, String? host, String? e, String? s}) => Hs1Frame(
        v: v ?? this.v,
        mode: mode ?? this.mode,
        host: host ?? this.host,
        e: e ?? this.e,
        s: s ?? this.s,
      );
}

class Hs2Frame {
  const Hs2Frame({required this.e, required this.c});

  final String e;
  final String c;

  Map<String, Object?> toJson() => {'t': 'hs2', 'e': e, 'c': c};

  Hs2Frame copyWith({String? e, String? c}) => Hs2Frame(e: e ?? this.e, c: c ?? this.c);
}

class HsRejectFrame {
  const HsRejectFrame({required this.code, required this.message});

  final String code;
  final String message;

  Map<String, Object?> toJson() => {'t': 'hsr', 'code': code, 'message': message};
}

class DataFrame {
  const DataFrame({required this.n, required this.c});

  final int n;
  final String c;

  Map<String, Object?> toJson() => {'t': 'd', 'n': n, 'c': c};

  DataFrame copyWith({int? n, String? c}) => DataFrame(n: n ?? this.n, c: c ?? this.c);
}

/// A relay-level error (spec §10.2): sent by the backend, not the host, then
/// the socket closes.
class RelayErrorFrame {
  const RelayErrorFrame({required this.code, required this.message});

  final String code;
  final String message;
}

sealed class OuterFrame {
  const OuterFrame();
}

final class OuterHs1 extends OuterFrame {
  const OuterHs1(this.frame);
  final Hs1Frame frame;
}

final class OuterHs2 extends OuterFrame {
  const OuterHs2(this.frame);
  final Hs2Frame frame;
}

final class OuterReject extends OuterFrame {
  const OuterReject(this.frame);
  final HsRejectFrame frame;
}

final class OuterData extends OuterFrame {
  const OuterData(this.frame);
  final DataFrame frame;
}

final class OuterRelayError extends OuterFrame {
  const OuterRelayError(this.frame);
  final RelayErrorFrame frame;
}

abstract final class OuterFrames {
  static String encode(Map<String, Object?> frame) => jsonEncode(frame);

  /// Parse one carrier text message. Shape only — the cryptographic checks
  /// belong to whoever consumes the frame. Throws [CryptoError] on anything
  /// that is not a well-formed outer frame.
  static OuterFrame parse(String text) {
    // The limit is bytes on the wire (spec §5), not UTF-16 code units.
    if (utf8Length(text) > Protocol.maxFrame) throw CryptoError('too-large', 'frame too large');
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw CryptoError('bad-frame', 'frame is not JSON', error);
    }
    if (decoded is! Map<String, Object?>) throw CryptoError('bad-frame', 'frame is not an object');
    return parseObject(decoded);
  }

  static OuterFrame parseObject(Map<String, Object?> obj) {
    Never bad() => throw CryptoError('bad-frame', 'malformed frame');
    String? str(String key) {
      final value = obj[key];
      return value is String ? value : null;
    }

    switch (str('t')) {
      case 'hs1':
        final v = obj['v'];
        if (v is! int) bad();
        return OuterHs1(Hs1Frame(
          v: v,
          mode: str('mode') ?? bad(),
          host: str('host') ?? bad(),
          e: str('e') ?? bad(),
          s: str('s') ?? bad(),
        ));
      case 'hs2':
        return OuterHs2(Hs2Frame(e: str('e') ?? bad(), c: str('c') ?? bad()));
      case 'hsr':
        return OuterReject(HsRejectFrame(code: str('code') ?? 'handshake-failed', message: str('message') ?? ''));
      case 'd':
        final n = obj['n'];
        if (n is! int) bad();
        return OuterData(DataFrame(n: n, c: str('c') ?? bad()));
      case 'relay-error':
        return OuterRelayError(RelayErrorFrame(code: str('code') ?? 'unknown', message: str('message') ?? ''));
      default:
        bad();
    }
  }
}
