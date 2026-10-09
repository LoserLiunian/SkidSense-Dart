import 'dart:convert';
import 'dart:typed_data';

import '../api/backend_client.dart';
import '../api/backend_models.dart';
import '../model/desktop.dart';
import '../protocol/bytes.dart';
import '../protocol/crypto_error.dart';
import '../protocol/history_crypto.dart';
import '../protocol/primitives.dart';
import '../util/json.dart';
import '../util/mutex.dart';

/// Why a history entry could not be shown.
enum HistoryProblem {
  /// This device holds no key for the entry's epoch: the desktop has not
  /// wrapped that epoch for it (yet).
  noKey,

  /// The blob could not be downloaded.
  download,

  /// Not valid base64url.
  encoding,

  /// The AEAD refused: the blob belongs to another session or epoch.
  decrypt,

  /// Decrypted, but not a session.
  content,
}

/// One session from the backend's encrypted store (spec §11): a list row
/// until opened, then its decrypted row and turns — or the [problem].
class HistoryEntry {
  const HistoryEntry({
    required this.sessionKey,
    required this.epoch,
    required this.updatedAt,
    required this.size,
    this.row,
    this.turns = const [],
    this.problem,
    this.error,
  });

  final String sessionKey;
  final int epoch;

  /// Unix seconds, as the backend stores them.
  final int updatedAt;
  final int size;
  final SessionRow? row;
  final List<TurnRecord> turns;
  final HistoryProblem? problem;
  final Object? error;

  bool get opened => row != null;
}

/// The backend's encrypted history: fetch the key wraps for this device,
/// unwrap the host's history key with the device's static X25519 key, list
/// blobs, download and open them. The backend never sees plaintext; every
/// blob is bound to its host, session key and epoch by its AAD.
///
/// Read-only, and searching happens here, over decrypted text — the backend
/// cannot search what it cannot read.
class HistoryRepository {
  HistoryRepository({required this._backend, required this._identity, required this.hostId, this.deviceId});

  final BackendClient _backend;
  final KeyPair _identity;
  final String hostId;

  /// This phone's device on [hostId]: with it, an epoch opened without its
  /// key has the keys fetched again first.
  final String? deviceId;
  final Mutex _lock = Mutex();

  /// epoch → the host's history key for that epoch.
  final Map<int, Uint8List> _keys = {};

  /// sessionKey → the decrypted entry; a blob is downloaded once, never per visit.
  final Map<String, HistoryEntry> _cache = {};

  bool get keysKnown => _keys.isNotEmpty;

  /// The newest epoch this device holds a key for.
  int? get currentEpoch => _keys.isEmpty ? null : _keys.keys.reduce((a, b) => a > b ? a : b);

  /// Fetch (or refresh) this device's copies of the host's history keys.
  Future<void> refreshKeys(String deviceId) => _lock.run(() async {
        final rows = await _backend.historyKeys(hostId, deviceId);
        for (final row in rows) {
          try {
            final wrapped = B64u.decode(row.wrapped, 80);
            _keys[row.epoch] = HistoryCrypto.unwrapKey(wrapped, _identity, HistoryCrypto.wrapContext(hostId, row.epoch));
          } on CryptoError {
            // Wrapped to another device, or a different epoch's context.
            continue;
          }
        }
      });

  /// The *list* only, newest first (S25): each blob is downloaded and
  /// decrypted on open — fetching them all here put 2+N requests on the
  /// shared per-IP budget on every visit, and rate-limited the whole app.
  Future<List<HistoryEntry>> load({int since = 0}) async {
    final rows = await _backend.historySessions(hostId, since: since);
    final entries = [
      for (final row in rows)
        _cache[row.sessionKey]?.updatedAt == row.updatedAt
            ? _cache[row.sessionKey]!
            : HistoryEntry(sessionKey: row.sessionKey, epoch: row.epoch, updatedAt: row.updatedAt, size: row.size),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  /// The one call that downloads: when the user actually opens a session.
  ///
  /// The blob is opened under the epoch it says it is sealed for, not the
  /// list's. A desktop that starts a new epoch (a device revoked, a scope
  /// narrowed) seals every session again under it, keeping `updated_at`: a
  /// list loaded before that names the old epoch, whose key opens nothing.
  /// A missing key has the keys fetched again, once.
  Future<HistoryEntry> open(HistoryEntry entry) async {
    final cached = _cache[entry.sessionKey];
    if (cached != null && cached.updatedAt == entry.updatedAt) return cached;
    var refreshed = false;
    Future<bool> haveKey(int epoch) async {
      final device = deviceId;
      if (_keys.containsKey(epoch) || refreshed || device == null) return _keys.containsKey(epoch);
      refreshed = true;
      try {
        await refreshKeys(device);
      } catch (_) {}
      return _keys.containsKey(epoch);
    }

    if (!await haveKey(entry.epoch)) return _failed(entry, HistoryProblem.noKey);
    final HistoryBlobRow row;
    try {
      row = await _backend.historyBlob(hostId, entry.sessionKey);
    } catch (error) {
      return _failed(entry, HistoryProblem.download, error);
    }
    final sealed = row.epoch <= 0 || row.epoch == entry.epoch
        ? entry
        : HistoryEntry(sessionKey: entry.sessionKey, epoch: row.epoch, updatedAt: entry.updatedAt, size: entry.size);
    if (!await haveKey(sealed.epoch)) return _failed(sealed, HistoryProblem.noKey);
    final opened = openBlob(row.blob, sealed);
    if (opened.problem == null) _cache[entry.sessionKey] = opened;
    return opened;
  }

  /// Open one blob with the key for its epoch.
  HistoryEntry openBlob(String blobBase64, HistoryEntry entry) {
    final key = _keys[entry.epoch];
    if (key == null) return _failed(entry, HistoryProblem.noKey);
    final Uint8List blob;
    try {
      blob = B64u.decode(blobBase64);
    } on CryptoError catch (error) {
      return _failed(entry, HistoryProblem.encoding, error);
    }
    final Uint8List plaintext;
    try {
      plaintext = HistoryCrypto.openBlob(key, HistoryCrypto.historyAad(hostId, entry.sessionKey, entry.epoch), blob);
    } on CryptoError catch (error) {
      return _failed(entry, HistoryProblem.decrypt, error);
    }
    try {
      final json = jsonDecode(utf8.decode(plaintext));
      if (json is! Map<String, Object?>) throw const FormatException('not an object');
      return HistoryEntry(
        sessionKey: entry.sessionKey,
        epoch: entry.epoch,
        updatedAt: entry.updatedAt,
        size: blob.length,
        row: json.object('row', SessionRow.fromJson) ?? const SessionRow(key: ''),
        turns: json.objects('turns', TurnRecord.fromJson),
      );
    } catch (error) {
      return _failed(entry, HistoryProblem.content, error);
    }
  }

  static HistoryEntry _failed(HistoryEntry entry, HistoryProblem problem, [Object? error]) => HistoryEntry(
        sessionKey: entry.sessionKey,
        epoch: entry.epoch,
        updatedAt: entry.updatedAt,
        size: entry.size,
        problem: problem,
        error: error,
      );

  /// Local search over what has been opened. Case-insensitive; an unopened
  /// entry matches on its key only.
  static List<HistoryEntry> search(List<HistoryEntry> entries, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return entries;
    bool has(String? text) => text != null && text.toLowerCase().contains(needle);
    return entries.where((entry) {
      if (has(entry.row?.title) || has(entry.sessionKey)) return true;
      return entry.turns.any((turn) =>
          has(turn.prompt) ||
          has(turn.snapshot.text) ||
          has(turn.snapshot.reasoning) ||
          turn.snapshot.toolCalls.any((call) => has(call.summary) || has(call.name)));
    }).toList();
  }

  /// A one-line excerpt showing where a hit was.
  static String excerpt(HistoryEntry entry, String query) {
    final needle = query.trim();
    if (needle.isEmpty) return entry.row?.preview ?? '';
    final title = entry.row?.title;
    if (title != null && title.toLowerCase().contains(needle.toLowerCase())) return title;
    for (final turn in entry.turns) {
      for (final text in [turn.snapshot.text, turn.prompt]) {
        final index = text.toLowerCase().indexOf(needle.toLowerCase());
        if (index >= 0) return _snippet(text, index, needle.length);
      }
    }
    return entry.row?.preview ?? '';
  }

  static String _snippet(String text, int index, int length) {
    final from = index - 24 < 0 ? 0 : index - 24;
    final to = index + length + 40 > text.length ? text.length : index + length + 40;
    return '${from > 0 ? '…' : ''}${text.substring(from, to).replaceAll('\n', ' ')}${to < text.length ? '…' : ''}';
  }
}
