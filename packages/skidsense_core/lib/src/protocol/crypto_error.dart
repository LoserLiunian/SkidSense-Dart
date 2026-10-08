/// A protocol or cryptographic failure.
///
/// [code] is machine-readable and matches the desktop reference's codes
/// (`bad-encoding`, `bad-key`, `bad-frame`, `handshake-failed`, `replayed`,
/// `out-of-order`, `rekey`, `too-large`…). [detail] is an English sentence for
/// logs and tests; what the user reads is chosen by the app from [code], so
/// this layer stays free of any one language.
class CryptoError implements Exception {
  CryptoError(this.code, [this.detail = '', this.cause]);

  final String code;
  final String detail;
  final Object? cause;

  @override
  String toString() => 'CryptoError($code${detail.isEmpty ? '' : ': $detail'})';
}
