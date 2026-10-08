import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/src/util/async_queue.dart';
import 'package:skidsense_core/src/util/json.dart';
import 'package:skidsense_core/transport.dart';

import '../protocol/test_responder.dart';

/// A duplex in-memory pipe: what one end sends, the other receives.
class MemoryCarrier implements Carrier {
  MemoryCarrier._(this._outbox, this._inbox, this.label);

  final AsyncQueue<String> _outbox;
  final AsyncQueue<String> _inbox;
  @override
  final String label;
  bool closed = false;

  static (MemoryCarrier, MemoryCarrier) pair(String label) {
    final a = AsyncQueue<String>();
    final b = AsyncQueue<String>();
    return (MemoryCarrier._(a, b, label), MemoryCarrier._(b, a, 'host'));
  }

  @override
  Future<String?> receive({Duration? timeout}) => _inbox.next(timeout: timeout);

  @override
  void send(String text) {
    if (closed || _outbox.isClosed) throw const ConnectionClosed('peer-closed');
    _outbox.add(text);
  }

  @override
  Future<void> close([String reason = '']) async {
    closed = true;
    _outbox.close();
    _inbox.close();
  }
}

class FakeUpload {
  FakeUpload(this.name, this.size, this.mimeType);

  final String name;
  final int size;
  final String? mimeType;
  int received = 0;
  final BytesBuilder bytes = BytesBuilder();

  bool get complete => received == size;
}

typedef Handler = FutureOr<Object?> Function(String method, Object? params);

/// An in-process stand-in for the desktop, built from [TestResponder]: it
/// answers the handshake, checks `hello`, then serves requests from
/// [handler] and can push events, parted responses and deliberate protocol
/// violations.
class FakeHost {
  FakeHost(
    this.hostId,
    this.hostStatic, {
    this.rejectWith,
    this.partSize = 512 * 1024,
    this.partDelay = Duration.zero,
    this.scopes = const ['sessions', 'prompt', 'approve', 'files', 'git'],
  });

  final String hostId;
  final KeyPair hostStatic;

  /// The grant `hello` must carry for `connect`.
  bool Function(String? grant) acceptGrant = (grant) => grant != null;

  /// The ticket `hello` must carry for `enroll`.
  bool Function(String? ticket) acceptTicket = (ticket) => ticket != null;

  /// Pairing codes accepted in `enroll` mode.
  Uint8List? pairingCode;

  /// When set, every hs1 is answered with this `hsr`.
  String? rejectWith;

  /// When set, only `connect` hs1s are refused with it: the host forgot the
  /// key but still takes an enrol.
  String? rejectConnectWith;

  /// Responses whose JSON is longer than this are sent in parts.
  int partSize;

  /// Delay between parts: a budgeted relay draining a large response.
  Duration partDelay;

  List<String> scopes;
  List<String> methods = ['sessions.list', 'subscribe'];
  Handler handler = (method, params) => true;

  final List<(String, Object?)> calls = [];
  final List<String?> helloGrants = [];
  final List<Uint8List> enrolledKeys = [];
  int connections = 0;
  int pongs = 0;

  // Uploads, mirroring the desktop's UploadStash (src/main/remote/uploads.ts).
  final Map<String, FakeUpload> uploads = {};
  final List<List<String>> consumedUploads = [];
  int? uploadReceivedOverride;
  int maxUpload = 20 * 1024 * 1024;
  int maxOpen = 8;
  int maxChunk = 384 * 1024;

  /// How long each `upload.chunk` takes to answer: a slow link.
  Duration chunkDelay = Duration.zero;

  // Terminal.
  Future<void> Function()? beforeTuiOpenReply;
  final List<String> terminalInput = [];
  bool terminalOpen = false;

  String? searchId;

  _Live? _live;
  bool get hasLive => _live != null;

  void serve(Carrier carrier) => unawaited(_runConnection(carrier));

  Future<void> _runConnection(Carrier carrier) async {
    try {
      final hs1 = (OuterFrames.parse((await carrier.receive())!) as OuterHs1).frame;
      final refusal = rejectWith ?? (hs1.mode == 'connect' ? rejectConnectWith : null);
      if (refusal != null) {
        carrier.send(OuterFrames.encode(HsRejectFrame(code: refusal, message: 'rejected').toJson()));
        await carrier.close();
        return;
      }
      final TestResponder responder;
      try {
        responder = TestResponder(hostId, hostStatic, hs1, hs1.mode == 'enroll' ? pairingCode : null);
      } on CryptoError catch (error) {
        carrier.send(OuterFrames.encode(HsRejectFrame(code: error.code, message: error.detail).toJson()));
        await carrier.close();
        return;
      }
      final (hs2, keys) = responder.complete();
      carrier.send(OuterFrames.encode(hs2.toJson()));
      final sealer = FrameSealer(keys.send);
      final opener = FrameOpener(keys.recv);
      final hello = jsonDecode(opener.open((OuterFrames.parse((await carrier.receive())!) as OuterData).frame))
          as Map<String, Object?>;
      final ok = responder.mode == HandshakeMode.enroll ? acceptTicket(hello.str('ticket')) : acceptGrant(hello.str('grant'));
      helloGrants.add(hello.str('grant') ?? hello.str('ticket'));
      if (!ok) {
        carrier.send(OuterFrames.encode(sealer.seal(Inner.bye('凭证无效')).toJson()));
        await carrier.close();
        return;
      }
      if (responder.mode == HandshakeMode.enroll) enrolledKeys.add(responder.clientStatic);
      final live = _Live(carrier, sealer);
      _live = live;
      connections += 1;
      live.sendInner(jsonEncode({
        't': 'welcome',
        'v': 1,
        'host': {'id': hostId, 'name': '书房的 Mac', 'version': '1.2.0', 'platform': 'darwin'},
        'device': {'id': 'dev-1', 'scopes': scopes},
        'user': {'id': 42, 'name': 'liunian'},
        'methods': methods,
        'future-field': 'ignored',
      }));
      try {
        await _serveRequests(carrier, live, opener);
      } finally {
        // The desktop's stash belongs to one connection.
        uploads.clear();
      }
    } catch (_) {
      await carrier.close();
    }
  }

  Future<void> _serveRequests(Carrier carrier, _Live live, FrameOpener opener) async {
    while (true) {
      final text = await carrier.receive();
      if (text == null) break;
      final inner = jsonDecode(opener.open((OuterFrames.parse(text) as OuterData).frame)) as Map<String, Object?>;
      switch (inner.str('t')) {
        case 'req':
          final id = inner.str('id')!;
          final method = inner.str('m')!;
          calls.add((method, inner['p']));
          if (method.startsWith('upload.') || method == 'tui.open' || method == 'tui.input' || method == 'search.start') {
            unawaited(_respondUploadOrTui(live, id, method, asMap(inner['p'])));
          } else {
            unawaited(_respond(live, id, method, inner['p']));
          }
        case 'ping':
          live.sendInner(Inner.pong(inner.number('ts') ?? 0));
        case 'pong':
          pongs += 1;
        case 'bye':
          await carrier.close();
          return;
      }
    }
  }

  Future<void> _respondUploadOrTui(_Live live, String id, String method, Map<String, Object?> params) async {
    void fail(String code, String message) => live.sendInner(jsonEncode({
          't': 'res',
          'id': id,
          'ok': false,
          'e': {'code': code, 'message': message},
        }));
    void ok(Object? value) => live.sendInner(jsonEncode({'t': 'res', 'id': id, 'ok': true, 'r': value}));

    switch (method) {
      case 'upload.begin':
        final size = params.integer('size') ?? -1;
        if (uploads.length >= maxOpen) {
          fail('bad-request', '同时上传的附件太多');
        } else if (size < 0 || size > maxUpload) {
          fail('bad-request', '单个附件不能超过 20 MiB');
        } else if (uploads.values.fold<int>(0, (sum, u) => sum + u.size) + size > maxUpload) {
          fail('bad-request', '附件合计不能超过 20 MiB');
        } else {
          final uploadId = 'u${uploads.length + 1}${B64u.encode(Primitives.randomBytes(6))}';
          uploads[uploadId] = FakeUpload(params.str('name') ?? 'file', size, params.str('mimeType'));
          ok({'id': uploadId});
        }
      case 'upload.chunk':
        if (chunkDelay > Duration.zero) await Future<void>.delayed(chunkDelay);
        final uploadId = params.str('id');
        final upload = uploadId == null ? null : uploads[uploadId];
        final offset = params.integer('offset');
        if (upload == null) {
          fail('bad-request', '上传不存在或已过期');
        } else if (offset != upload.received) {
          fail('bad-request', '上传分块的偏移不连续');
        } else {
          Uint8List? data;
          try {
            data = B64u.decode(params.str('data'));
          } catch (_) {
            data = null;
          }
          if (data == null) {
            fail('bad-request', '分块内容无效');
          } else if (data.length > maxChunk) {
            fail('bad-request', '分块过大');
          } else if (upload.received + data.length > upload.size) {
            fail('bad-request', '上传的内容比声明的大');
          } else {
            upload.received += data.length;
            upload.bytes.add(data);
            ok({'received': uploadReceivedOverride ?? upload.received});
          }
        }
      case 'upload.abort':
        final uploadId = params.str('id');
        if (uploadId != null) uploads.remove(uploadId);
        ok(true);
      case 'tui.open':
        terminalOpen = true;
        // The desktop's first PTY output can be on the wire before the reply is read.
        await beforeTuiOpenReply?.call();
        ok({'ok': true, 'attached': false, 'command': 'claude'});
      case 'tui.input':
        if (!terminalOpen) {
          fail('not-found', '没有打开这个终端');
        } else {
          terminalInput.add(params.str('data') ?? '');
          ok(true);
        }
      case 'search.start':
        searchId = params.str('id');
        ok(true);
      default:
        fail('unknown-method', method);
    }
  }

  Future<void> _respond(_Live live, String id, String method, Object? params) async {
    Map<String, Object?> body;
    try {
      body = {'ok': true, 'r': await handler(method, params)};
    } on RemoteCallError catch (error) {
      body = {
        'ok': false,
        'e': {'code': error.code, 'message': error.message ?? ''},
      };
    }
    final text = jsonEncode(body);
    if (text.length <= partSize) {
      live.sendInner(jsonEncode({'t': 'res', 'id': id, ...body}));
      return;
    }
    final chunks = [for (var i = 0; i < text.length; i += partSize) text.substring(i, (i + partSize).clamp(0, text.length))];
    for (var index = 0; index < chunks.length; index++) {
      if (index > 0 && partDelay > Duration.zero) await Future<void>.delayed(partDelay);
      live.sendInner(jsonEncode({'t': 'res', 'id': id, 'part': index, 'parts': chunks.length, 'd': chunks[index]}));
    }
  }

  void emit(String kind, Object? payload) => _live!.sendInner(jsonEncode({'t': 'ev', 'k': kind, 'p': payload}));

  /// Push one `search.progress` files frame, then the done frame (as the desktop does).
  void emitSearchProgress(List<Map<String, Object?>> files, int totalMatches, {String? id}) {
    emit('search.progress', {'id': id ?? searchId ?? '?', 'kind': 'files', 'files': files, 'done': false});
    emit('search.progress', {
      'id': id ?? searchId ?? '?',
      'kind': 'done',
      'totalMatches': totalMatches,
      'truncated': false,
      'elapsedMs': 12,
      'fileCount': files.length,
    });
  }

  /// Terminal output from the host, as `tui.data`.
  void emitTerminal(String key, String data) => emit('tui.data', {'key': key, 'data': data});

  void ping(int ts) => _live!.sendInner(Inner.ping(ts));

  /// Seal a frame and throw it away: the next one arrives with a gap in the counter.
  void skipFrame() => _live!.sealer.seal('{"t":"pong","ts":0}');

  /// Send a frame whose ciphertext was altered in flight.
  void sendTampered(String text) {
    final live = _live!;
    final frame = live.sealer.seal(text);
    final bytes = B64u.decode(frame.c)..[0] ^= 1;
    live.carrier.send(OuterFrames.encode(frame.copyWith(c: B64u.encode(bytes)).toJson()));
  }

  void sendRaw(String text) => _live!.carrier.send(text);

  Future<void> relayError(String code) async {
    _live!.carrier.send('{"t":"relay-error","code":"$code","message":"x"}');
    await _live!.carrier.close();
  }

  Future<void> drop() async => _live?.carrier.close();

  /// Say a sealed `bye` with a machine-readable [code] (spec §6.5), then
  /// close — how the desktop kicks a device.
  Future<void> kick(String? code, {String reason = '这台设备的权限已更改，请重新连接'}) async {
    final live = _live;
    if (live == null) return;
    live.sendInner(jsonEncode({'t': 'bye', 'reason': reason, 'code': ?code}));
    await live.carrier.close();
  }
}

class _Live {
  _Live(this.carrier, this.sealer);

  final Carrier carrier;
  final FrameSealer sealer;

  /// A reply racing the connection's end is dropped, as the desktop's would be.
  void sendInner(String text) {
    final frame = OuterFrames.encode(sealer.seal(text).toJson());
    try {
      carrier.send(frame);
    } on ConnectionClosed {
      // The far end is gone.
    }
  }
}

/// Routes each carrier request to a fake host, or fails, per route.
class FakeCarriers implements CarrierFactory {
  final List<HostRoute> opened = [];
  FakeHost? Function(RouteLan route) lan = (_) => null;
  FakeHost? Function() relay = () => null;

  /// LAN addresses that never answer (to exercise the per-address timeout).
  Set<String> blackhole = {};

  @override
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout}) async {
    opened.add(route);
    if (route is RouteLan && blackhole.contains(route.address)) {
      // Never answers; the caller's own bound gives up on it.
      await Completer<void>().future;
    }
    final host = switch (route) {
      RouteLan() => lan(route),
      RouteRelay() => relay(),
    };
    if (host == null) throw const CarrierUnavailable('refused');
    final (client, server) = MemoryCarrier.pair(route.describe());
    host.serve(server);
    return client;
  }
}

/// A host that sends exactly what a test tells it to. Unlike [FakeHost] it
/// seals by hand (own counter), so a test can put any inner message on the
/// wire — including one a conforming sealer would refuse.
class RawHost {
  RawHost(this.hostId, this.hostStatic);

  final String hostId;
  final KeyPair hostStatic;
  final AsyncQueue<Map<String, Object?>> requests = AsyncQueue();
  late Carrier _carrier;
  late Uint8List _sendKey;
  late FrameOpener _opener;
  int _counter = 0;

  Future<void> serve(Carrier carrier) async {
    _carrier = carrier;
    final hs1 = (OuterFrames.parse((await carrier.receive())!) as OuterHs1).frame;
    final (hs2, keys) = TestResponder(hostId, hostStatic, hs1).complete();
    carrier.send(OuterFrames.encode(hs2.toJson()));
    _sendKey = keys.send;
    _opener = FrameOpener(keys.recv);
    _opener.open((OuterFrames.parse((await carrier.receive())!) as OuterData).frame); // hello
    sendInner(jsonEncode({
      't': 'welcome',
      'v': 1,
      'host': {'id': hostId, 'name': 'raw'},
      'device': {
        'id': 'dev-1',
        'scopes': ['sessions'],
      },
      'methods': <String>[],
    }));
    while (true) {
      final text = await carrier.receive();
      if (text == null) break;
      final inner = jsonDecode(_opener.open((OuterFrames.parse(text) as OuterData).frame)) as Map<String, Object?>;
      if (inner.str('t') == 'req') requests.add(inner);
    }
  }

  /// Seal [text] under the next counter value without any size check, and send it.
  void sendInner(String text) {
    final n = _counter++;
    final sealed = Primitives.seal(_sendKey, FrameCrypto.nonce(n), FrameCrypto.aad(n), utf8Bytes(text));
    _carrier.send(OuterFrames.encode(DataFrame(n: n, c: B64u.encode(sealed)).toJson()));
  }

  /// A live phone-side connection to a fresh raw host over an in-memory pipe.
  static Future<(RcConnection, RawHost)> connect({ConnectionConfig config = const ConnectionConfig()}) async {
    final hostStatic = Primitives.generateKeyPair();
    final hostId = B64u.encode(Primitives.randomBytes(16));
    final host = RawHost(hostId, hostStatic);
    final (client, server) = MemoryCarrier.pair('lan 192.168.1.20');
    unawaited(host.serve(server).catchError((Object _) {}));
    final initiator = Initiator(
      mode: HandshakeMode.connect,
      hostId: hostId,
      hostStatic: hostStatic.pub,
      clientStatic: Primitives.generateKeyPair(),
    );
    final connection = await RcConnection.establish(
      carrier: client,
      route: const RouteLan('192.168.1.20', 47290),
      initiator: initiator,
      grant: 'grant',
      config: config,
    );
    return (connection, host);
  }
}
