import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skidsense_core/skidsense_core.dart';

/// Secrets in the platform keystore: the Android Keystore (an RSA-wrapped
/// AES key, AES-GCM data) or the iOS Keychain, this device only, readable
/// after the first unlock — the relay may need the token while the phone is
/// locked, and the device key must never travel in a backup.
///
/// Errors are *not* answered with a wipe (`resetOnError: false`): a read
/// that throws is the store failing, and the device key must survive a
/// transient failure (S27). Only [restoreIfBroken], at startup, decides the
/// store is beyond repair.
class KeystoreSecretStore implements SecretStore, BrokenStoreRestorer {
  KeystoreSecretStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(resetOnError: false, migrateOnAlgorithmChange: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device, synchronizable: false),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> get(String name) async {
    final value = await _storage.read(key: name);
    return value == null ? null : base64.decode(value);
  }

  @override
  Future<void> put(String name, List<int> value) => _storage.write(key: name, value: base64.encode(value));

  @override
  Future<void> delete(String name) => _storage.delete(key: name);

  /// Everything the store holds must decrypt. When it does not — twice, so
  /// a momentary failure is not mistaken for a migrated install — the
  /// ciphertexts are unrecoverable (a device-to-device copy carries the data
  /// but never the hardware key), and the honest move is to start over.
  @override
  Future<bool> restoreIfBroken() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _storage.readAll();
        return false;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    try {
      await _storage.deleteAll();
    } catch (_) {}
    return true;
  }
}

/// App-private files under Application Support, written whole and renamed
/// into place so a crash mid-write never leaves half a pairing list.
class DirectoryFileStore implements FileStore {
  DirectoryFileStore._(this._root);

  static Future<DirectoryFileStore> open() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/skidsense');
    await root.create(recursive: true);
    return DirectoryFileStore._(root);
  }

  final Directory _root;

  File _file(String name) {
    if (name.contains('/') || name.contains('..')) throw ArgumentError.value(name, 'name');
    return File('${_root.path}/$name');
  }

  @override
  Future<String?> read(String name) async {
    final file = _file(name);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String name, String text) async {
    final file = _file(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }
}
