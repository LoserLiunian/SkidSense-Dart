import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'bytes.dart';
import 'crypto_error.dart';
import 'history_crypto.dart';
import 'protocol.dart';

/// Why a pairing code could not be read. The app words each one.
enum PairingProblem {
  /// Not a pairing code at all, or a damaged one.
  invalid,

  /// A `skidsense://` link of another version: this app is too old for it.
  appTooOld,

  /// A payload whose own version is not 1.
  unsupportedVersion,

  /// The host key in the code is malformed.
  badHostKey,
}

class PairingFormatException implements Exception {
  const PairingFormatException(this.problem);

  final PairingProblem problem;

  @override
  String toString() => 'PairingFormatException(${problem.name})';
}

/// What a pairing QR code carries (spec §3). Single-letter keys on the wire
/// because QR density is the constraint.
class PairingPayload {
  const PairingPayload({
    required this.hostId,
    required this.hostKey,
    required this.code,
    required this.lanAddrs,
    required this.lanPort,
    required this.server,
    required this.machine,
  });

  final String hostId;

  /// Host static public key — pinned from here on, never learned from the network.
  final Uint8List hostKey;

  /// The 32-byte pairing code: the enroll handshake's PSK.
  final Uint8List code;

  /// LAN addresses, tried in order.
  final List<String> lanAddrs;
  final int lanPort;

  /// The backend both ends must be signed in to.
  final String server;

  /// Machine name, for display only.
  final String machine;

  String get fingerprint => hostFingerprint(hostKey);

  PairingPayload copyWith({List<String>? lanAddrs, int? lanPort}) => PairingPayload(
        hostId: hostId,
        hostKey: hostKey,
        code: code,
        lanAddrs: lanAddrs ?? this.lanAddrs,
        lanPort: lanPort ?? this.lanPort,
        server: server,
        machine: machine,
      );

  @override
  bool operator ==(Object other) =>
      other is PairingPayload &&
      hostId == other.hostId &&
      sameBytes(hostKey, other.hostKey) &&
      sameBytes(code, other.code) &&
      const ListEquality<String>().equals(lanAddrs, other.lanAddrs) &&
      lanPort == other.lanPort &&
      server == other.server &&
      machine == other.machine;

  @override
  int get hashCode => Object.hash(hostId, Object.hashAll(hostKey));
}

abstract final class Pairing {
  /// Accepts the whole `skidsense://pair/1?d=…` link or the bare base64url
  /// payload, so a code pasted by hand works as well as a scanned one.
  static PairingPayload decode(String text) {
    final trimmed = text.trim();
    final String data;
    if (trimmed.startsWith(Protocol.pairingUrlPrefix)) {
      data = trimmed.substring(Protocol.pairingUrlPrefix.length);
    } else if (trimmed.startsWith('skidsense://')) {
      throw const PairingFormatException(PairingProblem.appTooOld);
    } else {
      data = trimmed;
    }
    final Map<String, Object?> raw;
    try {
      final decoded = jsonDecode(strictUtf8(B64u.decode(data)));
      if (decoded is! Map<String, Object?>) throw const FormatException();
      raw = decoded;
    } catch (_) {
      throw const PairingFormatException(PairingProblem.invalid);
    }
    if (raw['v'] != 1) throw const PairingFormatException(PairingProblem.unsupportedVersion);
    String str(String key) {
      final value = raw[key];
      if (value is String) return value;
      throw const PairingFormatException(PairingProblem.invalid);
    }

    final Uint8List hostKey;
    try {
      hostKey = B64u.decode(str('k'), 32);
    } on CryptoError {
      throw const PairingFormatException(PairingProblem.badHostKey);
    }
    final Uint8List code;
    try {
      code = B64u.decode(str('c'), 32);
    } on CryptoError {
      throw const PairingFormatException(PairingProblem.invalid);
    }
    final hosts = raw['h'] is List ? (raw['h'] as List).whereType<String>().toList() : <String>[];
    final p = raw['p'];
    final port = p is int && p >= 1 && p <= 65535 ? p : 0;
    final hostId = str('n');
    if (hostId.isEmpty) throw const PairingFormatException(PairingProblem.invalid);
    return PairingPayload(
      hostId: hostId,
      hostKey: hostKey,
      code: code,
      lanAddrs: hosts,
      lanPort: port,
      server: str('s'),
      machine: str('m'),
    );
  }
}

/// Backend addresses are compared after normalising: scheme and host
/// lower-cased, default ports and trailing slashes dropped.
/// `https://AI.example.com/` and `https://ai.example.com` are the same
/// backend; `http://` and `https://` are not.
String normalizeBackendUrl(String url) {
  var trimmed = url.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  final schemeEnd = trimmed.indexOf('://');
  if (schemeEnd < 0) return trimmed.toLowerCase();
  final scheme = trimmed.substring(0, schemeEnd).toLowerCase();
  final rest = trimmed.substring(schemeEnd + 3);
  final slash = rest.indexOf('/');
  var authority = (slash < 0 ? rest : rest.substring(0, slash)).toLowerCase();
  final path = slash < 0 ? '' : rest.substring(slash);
  if (scheme == 'https' && authority.endsWith(':443')) authority = authority.substring(0, authority.length - 4);
  if (scheme == 'http' && authority.endsWith(':80')) authority = authority.substring(0, authority.length - 3);
  return '$scheme://$authority$path';
}
