import 'dart:convert';
import 'dart:typed_data';

/// Secrets at rest: the device's static X25519 private key, the login
/// tokens, cached grants. The app backs this with the platform's keystore
/// (Android Keystore / iOS Keychain, this-device-only).
///
/// A read that *throws* is not a missing value: it is the store failing
/// (transiently, or for good after a device migration that carried the data
/// but not the hardware key). Callers that would generate something new on
/// `null` — the device key — must not do so on a throw (S27).
abstract interface class SecretStore {
  Future<Uint8List?> get(String name);
  Future<void> put(String name, List<int> value);
  Future<void> delete(String name);
}

/// What a store whose master key stopped decrypting offers its owner (S27): a
/// device-to-device migration carries the blobs but never the hardware key,
/// so the old ciphertexts are unrecoverable — the only honest move is to wipe
/// and start over rather than fail every read forever. Returns true when it
/// did that and the caller should treat the session as gone.
abstract interface class BrokenStoreRestorer {
  Future<bool> restoreIfBroken();
}

/// Non-secret app-private files (paired hosts, the install id).
abstract interface class FileStore {
  Future<String?> read(String name);
  Future<void> write(String name, String text);
  Future<void> delete(String name);
}

extension SecretStrings on SecretStore {
  Future<String?> getString(String name) async {
    final bytes = await get(name);
    return bytes == null ? null : utf8.decode(bytes);
  }

  Future<void> putString(String name, String value) => put(name, utf8.encode(value));
}

/// For tests and previews. Not persistent.
class MemorySecretStore implements SecretStore {
  final Map<String, Uint8List> _values = {};

  /// When set, every read throws it — a keystore failing.
  Object? failReadsWith;

  @override
  Future<Uint8List?> get(String name) async {
    final failure = failReadsWith;
    if (failure != null) throw failure;
    final value = _values[name];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> put(String name, List<int> value) async => _values[name] = Uint8List.fromList(value);

  @override
  Future<void> delete(String name) async => _values.remove(name);
}

class MemoryFileStore implements FileStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String name) async => _values[name];

  @override
  Future<void> write(String name, String text) async => _values[name] = text;

  @override
  Future<void> delete(String name) async => _values.remove(name);
}
