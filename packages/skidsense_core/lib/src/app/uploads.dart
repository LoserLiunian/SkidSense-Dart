import 'dart:typed_data';

import '../protocol/bytes.dart';
import '../protocol/protocol.dart';
import '../transport/errors.dart';
import '../util/json.dart';
import '../util/state_value.dart';

/// A request on the live connection that answers an object, or null.
typedef UploadCall = Future<Map<String, Object?>?> Function(String method, Map<String, Object?> params);

class Upload {
  Upload({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.bytes,
    required this.sessionKey,
    required this.connection,
  });

  final String id;
  final String name;
  final String? mimeType;
  final Uint8List bytes;

  /// The session this file was picked for; a prompt takes only its own.
  final String? sessionKey;

  /// The connection this id lives on; the desktop forgets it with the connection.
  final Object? connection;
  int sent = 0;

  int get size => bytes.length;
  bool get complete => sent >= size;
  double get progress => size == 0 ? 1 : sent / size;
}

/// An attachment the user has picked but not sent yet.
class UploadDraft {
  const UploadDraft({
    required this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.sessionKey,
    required this.progress,
  });

  final String id;
  final String name;
  final int size;
  final String? mimeType;
  final String? sessionKey;
  final double progress;
}

/// Attachments, as the desktop's `UploadStash` (`src/main/remote/uploads.ts`)
/// accepts them: `begin` with a declared size, then numbered chunks at
/// exactly consecutive offsets, then the id is handed to `turn.prompt`.
///
/// The client side of the contract, enforced before anything goes on the wire:
///
/// - one chunk is at most `uploadChunk` (384 KiB) of raw bytes;
/// - `offset` is exactly what has been sent so far — the desktop refuses a
///   gap, an overlap or a rewrite, and there is no repairing that on a live
///   upload, so **a failed chunk is never retried at another offset**: the
///   upload is aborted and started again;
/// - a file is at most `maxUpload` (20 MiB) — the drafts together too — and
///   at most 8 are open at once;
/// - an id still unfinished when a prompt is sent fails the whole turn on the
///   desktop, so an unfinished id is never handed over.
///
/// Uploads are tied to the connection they went up on (the desktop's stash
/// dies with it, S28) and to the session they were picked for (S29).
class UploadManager {
  UploadManager({required this._call, required this._connectionMarker, int Function()? chunkSize})
      : _chunkSize = chunkSize ?? (() => Protocol.uploadChunk);

  final UploadCall _call;
  final Object? Function() _connectionMarker;

  /// Raw bytes per `upload.chunk`: the protocol's 384 KiB on the LAN, less on
  /// the budgeted relay so other requests are not queued behind it.
  final int Function() _chunkSize;

  static const maxOpen = 8;

  final Map<String, Upload> _open = {};
  final StateValue<List<UploadDraft>> _drafts = StateValue<List<UploadDraft>>(const []);

  /// The drafts, a fresh list on every change.
  StateValue<List<UploadDraft>> get drafts => _drafts;

  /// An upload is still being sent: swapping the connection now would lose it.
  bool get busy => _open.values.any((upload) => upload.sent < upload.size);

  int get count => _open.length;

  void _publish() => _drafts.value = [
        for (final upload in _open.values)
          UploadDraft(
            id: upload.id,
            name: upload.name,
            size: upload.size,
            mimeType: upload.mimeType,
            sessionKey: upload.sessionKey,
            progress: upload.progress,
          ),
      ];

  /// Drop every draft whose connection died: the ids it kept mean nothing to
  /// the new one (S28).
  void dropStaleConnections() {
    final live = _connectionMarker();
    final before = _open.length;
    _open.removeWhere((_, upload) => !identical(upload.connection, live));
    if (_open.length != before) _publish();
  }

  /// Register a file and send it. The whole file is held in memory: the
  /// picker gives bytes and the desktop's cap is 20 MiB.
  Future<Upload> begin(String name, String? mimeType, List<int> bytes, {String? sessionKey}) async {
    if (_open.length >= maxOpen) throw const RcException('too-many-uploads');
    if (bytes.length > Protocol.maxUpload) throw const RcException('upload-too-large');
    final total = _open.values.fold<int>(0, (sum, upload) => sum + upload.size) + bytes.length;
    if (total > Protocol.maxUpload) throw const RcException('uploads-too-large');
    final started = await _call('upload.begin', {'name': name, 'mimeType': ?mimeType, 'size': bytes.length});
    final id = started?.str('id');
    if (id == null || id.isEmpty) throw const RcException('bad-response', detail: 'upload.begin');
    final upload = Upload(
      id: id,
      name: name,
      mimeType: mimeType,
      bytes: Uint8List.fromList(bytes),
      sessionKey: sessionKey,
      connection: _connectionMarker(),
    );
    _open[id] = upload;
    _publish();
    try {
      await _sendChunks(upload);
    } catch (_) {
      // Never leave a half-uploaded id on the desktop: it would be referenced
      // as if complete, or expire on its own later.
      await abort(upload.id);
      rethrow;
    }
    return upload;
  }

  Future<void> _sendChunks(Upload upload) async {
    var offset = upload.sent;
    while (offset < upload.size) {
      final step = _chunkSize().clamp(1, Protocol.uploadChunk);
      final end = offset + step < upload.size ? offset + step : upload.size;
      final result = await _call('upload.chunk', {
        'id': upload.id,
        'offset': offset,
        'data': B64u.encode(Uint8List.sublistView(upload.bytes, offset, end)),
      });
      final received = result?.number('received');
      if (received != null && received != end) {
        // The desktop's count disagrees with ours. The offset it wants next
        // is not the one we would send, and that cannot be repaired in place.
        throw const RcException('upload-desync');
      }
      offset = end;
      upload.sent = end;
      _publish();
    }
  }

  /// The uploads for one prompt, handed over and forgotten; give them back
  /// with [restore] if the turn is not accepted *on the same connection*.
  /// Refuses while any is unfinished. Only [sessionKey]'s own drafts are
  /// taken.
  List<Upload> take(String sessionKey) {
    final mine = _open.values.where((upload) => upload.sessionKey == null || upload.sessionKey == sessionKey).toList();
    final unfinished = mine.where((upload) => !upload.complete);
    if (unfinished.isNotEmpty) throw RcException('upload-incomplete', message: unfinished.first.name);
    for (final upload in mine) {
      _open.remove(upload.id);
    }
    _publish();
    return mine;
  }

  /// Put back what a prompt did not get accepted, so it can be sent again.
  void restore(List<Upload> uploads) {
    if (uploads.isEmpty) return;
    for (final upload in uploads) {
      _open[upload.id] = upload;
    }
    _publish();
  }

  Future<void> abort(String id) async {
    if (_open.remove(id) != null) _publish();
    try {
      await _call('upload.abort', {'id': id});
    } catch (_) {}
  }

  /// Abort everything staged for one session — leaving its composer.
  Future<void> abortAll(String sessionKey) async {
    final ids = [
      for (final upload in _open.values)
        if (upload.sessionKey == null || upload.sessionKey == sessionKey) upload.id,
    ];
    for (final id in ids) {
      _open.remove(id);
    }
    if (ids.isNotEmpty) _publish();
    for (final id in ids) {
      try {
        await _call('upload.abort', {'id': id});
      } catch (_) {}
    }
  }
}
