import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import '../api/server_policy.dart';
import '../protocol/bytes.dart';
import '../protocol/primitives.dart';
import '../protocol/protocol.dart';
import '../util/async_queue.dart';
import 'carrier.dart';
import 'errors.dart';

/// The most bytes one inbound message may take on the wire, framing
/// included. Generous over [Protocol.maxFrame] so the protocol's own check in
/// [IoCarrier] — not this — is the rule a well-behaved host meets.
const int inboundMessageCap = Protocol.maxFrame + 256 * 1024;

/// Opens LAN (`ws://<addr>:<port>/rc/1`, spec §10.4) and relay
/// (`wss://<backend>/api/companion/ws?role=device&…`, spec §10) carriers on
/// `dart:io`.
///
/// The WebSocket upgrade is done by hand over a byte-counting socket, for
/// three guarantees `WebSocket.connect` cannot give (S30):
///
/// - no `permessage-deflate` is offered, so no inflation bomb can be
///   negotiated, and no `Origin` header is sent (both carriers refuse one);
/// - a frame whose header claims more than [inboundMessageCap] is refused
///   before a byte of it is buffered (`maxPayloadLength`);
/// - the bytes read since the last *delivered* message are counted at the
///   socket, so a peer cannot grow one message without bound out of many
///   small continuation frames — which the per-frame check alone allows, and
///   which a pre-authentication LAN peer is free to try.
class IoCarrierFactory implements CarrierFactory {
  IoCarrierFactory({
    required this.backendBase,
    required this.relayPath,
    required this.bearer,
    this.messageCap = inboundMessageCap,
    this.pingInterval = const Duration(seconds: 20),
  });

  /// The backend base URL (`https://ai.surise.cn`).
  final String? Function() backendBase;

  /// `ws_path` from `GET /config`; may fetch it the first time.
  final Future<String?> Function() relayPath;

  /// A current bearer for the relay.
  final Future<String?> Function() bearer;

  final int messageCap;

  /// WebSocket-level pings: keep NAT bindings warm and notice a dead socket.
  final Duration? pingInterval;

  @override
  Future<Carrier> open(HostRoute route, CarrierTarget target, {required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    final Uri uri;
    final headers = <String, String>{};
    switch (route) {
      case RouteLan(:final address, :final port):
        uri = lanUri(address, port);
      case RouteRelay():
        // Null is also what a refresh that could not reach the backend gives;
        // a real sign-out sends the app back to the login screen on its own.
        final token = await bearer();
        if (token == null) throw const CarrierUnavailable('no-credentials');
        final relay = relayUri(backendBase(), target, await relayPath());
        if (relay == null) throw const CarrierUnavailable('no-relay');
        uri = relay;
        headers['Authorization'] = 'Bearer $token';
    }
    final socket = await _connect(uri, _remaining(deadline));
    final counting = _CountingSocket(socket, messageCap);
    try {
      await counting.upgrade(uri, headers, _remaining(deadline));
      final ws = WebSocket.fromUpgradedSocket(
        counting,
        serverSide: false,
        compression: CompressionOptions.compressionOff,
        maxPayloadLength: messageCap,
      )..pingInterval = pingInterval;
      return IoCarrier._(ws, counting, route.describe());
    } catch (error) {
      counting.destroy();
      if (error is CarrierUnavailable) rethrow;
      throw CarrierUnavailable('upgrade', '$error');
    }
  }

  static Duration _remaining(DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static Future<Socket> _connect(Uri uri, Duration timeout) async {
    final host = uri.host;
    final port = uri.port;
    final ConnectionTask<Socket> task;
    try {
      task = uri.scheme == 'wss'
          ? await SecureSocket.startConnect(host, port)
          : await Socket.startConnect(host, port);
    } on SocketException catch (error) {
      throw CarrierUnavailable('refused', error.message);
    }
    try {
      return await task.socket.timeout(timeout, onTimeout: () {
        task.cancel();
        throw const CarrierUnavailable('timeout');
      });
    } on CarrierUnavailable {
      rethrow;
    } on HandshakeException catch (error) {
      throw CarrierUnavailable('tls', error.message);
    } on SocketException catch (error) {
      throw CarrierUnavailable('refused', error.message);
    }
  }

  static Uri lanUri(String address, int port) => Uri(scheme: 'ws', host: address, port: port, path: Protocol.lanPath);

  /// The relay URL for [target], or null when there is no backend or device id.
  static Uri? relayUri(String? base, CarrierTarget target, [String? configuredPath]) {
    final deviceId = target.deviceId;
    // The relay carries the bearer: plain `ws://` only where `http://` is
    // allowed at all (server_policy.dart).
    if (base == null || !backendAllowed(base) || deviceId == null) return null;
    final parsed = Uri.parse(base.trim());
    final path = (configuredPath != null && configuredPath.trim().isNotEmpty) ? configuredPath.trim() : '/${Protocol.relayPath}';
    var basePath = parsed.path;
    while (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    var tail = path;
    while (tail.startsWith('/')) {
      tail = tail.substring(1);
    }
    return Uri(
      scheme: parsed.scheme == 'http' ? 'ws' : 'wss',
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: '$basePath/$tail',
      queryParameters: {'role': 'device', 'host_id': target.hostId, 'device_id': deviceId},
    );
  }
}

/// A WebSocket carrier. Text frames only; a binary message, or one over
/// [Protocol.maxFrame] bytes, closes it.
class IoCarrier implements Carrier {
  IoCarrier._(this._ws, this._socket, this.label) {
    _subscription = _ws.listen(
      (message) {
        if (message is! String) {
          unawaited(close('text frames only'));
          return;
        }
        if (utf8Length(message) > Protocol.maxFrame) {
          unawaited(close('frame too large'));
          return;
        }
        _inbox.add(message);
      },
      onError: (Object _) => _inbox.close(),
      onDone: _inbox.close,
      cancelOnError: true,
    );
  }

  final WebSocket _ws;
  final _CountingSocket _socket;
  late final StreamSubscription<Object?> _subscription;
  late final AsyncQueue<String> _inbox = AsyncQueue<String>(
    highWater: 256,
    onHigh: () => _subscription.pause(),
    onLow: () => _subscription.resume(),
  );
  bool _closed = false;

  @override
  final String label;

  @override
  Future<String?> receive({Duration? timeout}) => _inbox.next(timeout: timeout);

  @override
  void send(String text) {
    if (_closed || _ws.closeCode != null) throw const ConnectionClosed('peer-closed');
    try {
      _ws.add(text);
    } catch (error) {
      throw ConnectionClosed('peer-closed', cause: error);
    }
  }

  @override
  Future<void> close([String reason = '']) async {
    if (_closed) return;
    _closed = true;
    _inbox.close();
    final shortened = reason.length > 120 ? reason.substring(0, 120) : reason;
    try {
      await _ws.close(WebSocketStatus.normalClosure, shortened).timeout(const Duration(seconds: 1));
    } catch (_) {
      _socket.destroy();
    }
  }
}

/// A socket that does the client half of the WebSocket upgrade itself, then
/// watches the frames going past and kills the connection when one message
/// would grow past the cap.
class _CountingSocket extends Stream<Uint8List> implements Socket {
  _CountingSocket(this._raw, this._cap) {
    _subscription = _raw.listen(_onData, onError: _onError, onDone: _onDone);
  }

  final Socket _raw;
  final int _cap;
  late final StreamSubscription<Uint8List> _subscription;
  late final StreamController<Uint8List> _controller = StreamController<Uint8List>(
    sync: true,
    onPause: () => _subscription.pause(),
    onResume: () => _subscription.resume(),
  );
  late final _FrameTracker _frames = _FrameTracker(_cap);

  // The upgrade response is read here before the WebSocket sees a byte.
  bool _upgraded = false;
  final BytesBuilder _head = BytesBuilder(copy: false);
  Completer<void>? _headDone;

  void _onData(Uint8List data) {
    if (_upgraded) {
      _forward(data);
      return;
    }
    _head.add(data);
    final bytes = _head.toBytes();
    final end = _headerEnd(bytes);
    if (end < 0) {
      if (bytes.length > 16 * 1024) _overflow();
      return;
    }
    _headBytes = Uint8List.sublistView(bytes, 0, end);
    _upgraded = true;
    _headDone?.complete();
    if (end < bytes.length) _forward(Uint8List.sublistView(bytes, end));
  }

  void _forward(Uint8List data) {
    if (!_frames.feed(data)) {
      _overflow();
      return;
    }
    _controller.add(data);
  }

  Uint8List? _headBytes;

  void _overflow() {
    _raw.destroy();
    if (!_upgraded) {
      _headDone?.completeError(const CarrierUnavailable('too-large'));
    } else if (!_controller.isClosed) {
      _controller.addError(const SocketException('inbound message over the cap'));
      unawaited(_controller.close());
    }
    unawaited(_subscription.cancel());
  }

  void _onError(Object error, StackTrace stack) {
    if (!_upgraded && !(_headDone?.isCompleted ?? true)) {
      _headDone!.completeError(CarrierUnavailable('io', '$error'));
    }
    if (!_controller.isClosed) _controller.addError(error, stack);
  }

  void _onDone() {
    if (!_upgraded && !(_headDone?.isCompleted ?? true)) {
      _headDone!.completeError(const CarrierUnavailable('upgrade', 'closed before the response'));
    }
    if (!_controller.isClosed) unawaited(_controller.close());
  }

  static int _headerEnd(Uint8List bytes) {
    for (var index = 3; index < bytes.length; index++) {
      if (bytes[index - 3] == 13 && bytes[index - 2] == 10 && bytes[index - 1] == 13 && bytes[index] == 10) return index + 1;
    }
    return -1;
  }

  static const _guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

  Future<void> upgrade(Uri uri, Map<String, String> headers, Duration timeout) async {
    final key = base64.encode(Primitives.randomBytes(16));
    final hostHeader = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final defaultPort = uri.scheme == 'wss' ? 443 : 80;
    final request = StringBuffer()
      ..write('GET ${uri.path.isEmpty ? '/' : uri.path}${uri.hasQuery ? '?${uri.query}' : ''} HTTP/1.1\r\n')
      ..write('Host: $hostHeader${uri.port == defaultPort ? '' : ':${uri.port}'}\r\n')
      ..write('Upgrade: websocket\r\n')
      ..write('Connection: Upgrade\r\n')
      ..write('Sec-WebSocket-Key: $key\r\n')
      ..write('Sec-WebSocket-Version: 13\r\n')
      ..write('User-Agent: skidsense-mobile\r\n');
    headers.forEach((name, value) => request.write('$name: $value\r\n'));
    request.write('\r\n');
    _headDone = Completer<void>();
    _raw.add(utf8.encode(request.toString()));
    await _headDone!.future.timeout(timeout, onTimeout: () => throw const CarrierUnavailable('timeout'));

    final lines = latin1.decode(_headBytes!).split('\r\n');
    final status = lines.first.split(' ');
    final code = status.length > 1 ? int.tryParse(status[1]) : null;
    if (code == 401) throw const CarrierUnavailable('unauthorized');
    if (code != 101) throw CarrierUnavailable('upgrade', lines.first);
    final fields = <String, String>{};
    for (final line in lines.skip(1)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      fields[line.substring(0, colon).trim().toLowerCase()] = line.substring(colon + 1).trim();
    }
    if (fields['upgrade']?.toLowerCase() != 'websocket' ||
        !(fields['connection']?.toLowerCase().contains('upgrade') ?? false)) {
      throw const CarrierUnavailable('upgrade', 'not a WebSocket upgrade');
    }
    final expected = base64.encode(const DartSha1().hashSync(utf8.encode('$key$_guid')).bytes);
    if (fields['sec-websocket-accept'] != expected) throw const CarrierUnavailable('upgrade', 'bad accept key');
    if (fields.containsKey('sec-websocket-extensions')) {
      // We offered none; a server that negotiates one anyway is not one to talk to.
      throw const CarrierUnavailable('upgrade', 'unrequested extension');
    }
  }

  // --- Stream<Uint8List> ---------------------------------------------------------

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  // --- writes reach the real socket unchanged --------------------------------------

  @override
  Encoding get encoding => _raw.encoding;

  @override
  set encoding(Encoding value) => _raw.encoding = value;

  @override
  void add(List<int> data) => _raw.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _raw.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _raw.addStream(stream);

  @override
  Future<void> flush() => _raw.flush();

  @override
  void write(Object? object) => _raw.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _raw.writeAll(objects, separator);

  @override
  void writeln([Object? object = '']) => _raw.writeln(object);

  @override
  void writeCharCode(int charCode) => _raw.writeCharCode(charCode);

  @override
  Future<void> close() => _raw.close();

  @override
  Future<void> get done => _raw.done;

  @override
  void destroy() {
    _raw.destroy();
    if (!_controller.isClosed) unawaited(_controller.close());
  }

  // --- the rest is the real socket's -------------------------------------------------

  @override
  InternetAddress get address => _raw.address;

  @override
  InternetAddress get remoteAddress => _raw.remoteAddress;

  @override
  int get port => _raw.port;

  @override
  int get remotePort => _raw.remotePort;

  @override
  bool setOption(SocketOption option, bool enabled) => _raw.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) => _raw.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _raw.setRawOption(option);
}

/// Reads WebSocket frame headers as the bytes go by (RFC 6455 §5.2) and sums
/// the payload of the message being assembled. The sum is checked against the
/// declared length of each frame, before its payload arrives, and starts over
/// after a frame with FIN. Control frames are skipped: they never join a
/// message. A passive reader: it never holds bytes, it only counts.
class _FrameTracker {
  _FrameTracker(this._cap);

  final int _cap;
  int _state = 0; // 0 first byte, 1 second byte, 2 extended length, 3 mask, 4 payload
  int _need = 0;
  int _length = 0;
  bool _fin = false;
  bool _control = false;
  bool _masked = false;
  int _payloadLeft = 0;
  int _message = 0;

  /// False when the message would pass the cap.
  bool feed(Uint8List data) {
    var index = 0;
    while (index < data.length) {
      switch (_state) {
        case 0:
          final byte = data[index++];
          _fin = byte & 0x80 != 0;
          _control = byte & 0x08 != 0;
          _state = 1;
        case 1:
          final byte = data[index++];
          _masked = byte & 0x80 != 0;
          final short = byte & 0x7f;
          if (short == 126 || short == 127) {
            _state = 2;
            _need = short == 126 ? 2 : 8;
            _length = 0;
          } else if (!_lengthKnown(short)) {
            return false;
          }
        case 2:
          _length = (_length << 8) | data[index++];
          _need -= 1;
          if (_need == 0 && !_lengthKnown(_length)) return false;
        case 3:
          index += 1;
          _need -= 1;
          if (_need == 0) _payload();
        default:
          final take = data.length - index < _payloadLeft ? data.length - index : _payloadLeft;
          index += take;
          _payloadLeft -= take;
          if (_payloadLeft == 0) _frameEnd();
      }
    }
    return true;
  }

  bool _lengthKnown(int length) {
    if (length < 0) return false;
    _payloadLeft = length;
    if (!_control) {
      _message += length;
      if (_message > _cap) return false;
    }
    if (_masked) {
      _state = 3;
      _need = 4;
    } else {
      _payload();
    }
    return true;
  }

  void _payload() {
    if (_payloadLeft == 0) {
      _frameEnd();
    } else {
      _state = 4;
    }
  }

  void _frameEnd() {
    if (!_control && _fin) _message = 0;
    _state = 0;
  }
}
