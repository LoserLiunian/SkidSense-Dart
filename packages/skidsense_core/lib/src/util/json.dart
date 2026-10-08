/// Lenient readers over decoded JSON (`Map<String, Object?>` from
/// `jsonDecode`): the desktop keeps adding fields and occasionally sends a
/// number where a string was, so absent or mistyped fields read as null
/// rather than throwing.
Map<String, Object?> asMap(Object? json) => json is Map<String, Object?> ? json : const {};

extension JsonRead on Map<String, Object?> {
  String? str(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  /// A JSON integer: not a string that looks like one, not a fraction.
  int? integer(String key) {
    final value = this[key];
    return value is int ? value : null;
  }

  /// Any JSON number, truncated — for fields the desktop may send fractional.
  int? number(String key) {
    final value = this[key];
    return value is num ? value.toInt() : null;
  }

  double? decimal(String key) {
    final value = this[key];
    return value is num ? value.toDouble() : null;
  }

  bool? boolean(String key) {
    final value = this[key];
    return value is bool ? value : null;
  }

  Map<String, Object?>? obj(String key) {
    final value = this[key];
    return value is Map<String, Object?> ? value : null;
  }

  List<Object?> list(String key) {
    final value = this[key];
    return value is List ? value.cast<Object?>() : const [];
  }

  List<String> strings(String key) => list(key).whereType<String>().toList();
}
