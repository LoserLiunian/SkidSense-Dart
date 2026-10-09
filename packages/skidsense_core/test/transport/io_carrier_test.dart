import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:skidsense_core/app.dart' show BackendException;
import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/transport.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';

/// The `dart:io` carrier against real sockets on the loopback: a well-behaved
/// WebSocket server, and raw TCP servers that misbehave in the ways S30
/// guards against.
void main() {
  IoCarrierFactory factory() => IoCarrierFactory(
        backendBase: () => null,
        relayPath: () async => null,
        bearer: () async => null,
        pingInterval: null,
      );

  const target = CarrierTarget('host-1', 'dev-1');

  IoCarrierFactory relayFactory(int port, {String? path}) => IoCarrierFactory(
        backendBase: () => 'http://127.0.0.1:$port',
        relayPath: () async => path,
        bearer: () async => 'relay-token',
        pingInterval: null,
      );

  test('speaks to a WebSocket server, sending no Origin and offering no extension', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = Completer<HttpHeaders>();
    final path = Completer<String>();
    server.listen((request) async {
      seen.complete(request.headers);
      path.complete(request.uri.path);
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((message) => socket.add('echo:$message'));
    });
    addTearDown(() => server.close(force: true));

    final carrier = await factory().open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
    carrier.send('你好');
    expect(await carrier.receive(timeout: const Duration(seconds: 5)), 'echo:你好');
    final headers = await seen.future;
    expect(headers.value('origin'), isNull);
    expect(headers.value('sec-websocket-extensions'), isNull);
    expect(await path.future, Protocol.lanPath);
    await carrier.close();
  });

  test('many whole messages pass however much they add up to', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final chunk = 'x' * (1024 * 1024);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      for (var i = 0; i < 12; i++) {
        socket.add(chunk);
      }
    });
    addTearDown(() => server.close(force: true));
    final carrier = await factory().open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
    for (var i = 0; i < 12; i++) {
      expect((await carrier.receive(timeout: const Duration(seconds: 10)))!.length, chunk.length);
    }
    await carrier.close();
  });

  /// A raw server that answers the upgrade correctly, then runs [afterUpgrade].
  Future<ServerSocket> rawServer(
    FutureOr<void> Function(Socket socket) afterUpgrade, {
    String Function(String key)? response,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      // A client that hangs up on what it was sent resets the connection:
      // the point of most tests here, not a failure of the server.
      socket.done.ignore();
      final head = BytesBuilder();
      late StreamSubscription<Uint8List> sub;
      sub = socket.listen((data) async {
        head.add(data);
        final text = latin1.decode(head.toBytes());
        if (!text.contains('\r\n\r\n')) return;
        await sub.cancel();
        final key = RegExp(r'Sec-WebSocket-Key: (\S+)').firstMatch(text)!.group(1)!;
        final accept = base64.encode(const DartSha1().hashSync(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11')).bytes);
        socket.add(latin1.encode(response?.call(accept) ??
            'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: $accept\r\n\r\n'));
        try {
          await afterUpgrade(socket);
        } catch (_) {}
      }, onError: (Object _) {});
    });
    return server;
  }

  Uint8List frame({required bool fin, required int opcode, required int length, List<int>? payload}) {
    final header = BytesBuilder()..addByte((fin ? 0x80 : 0) | opcode);
    if (length < 126) {
      header.addByte(length);
    } else if (length < 65536) {
      header
        ..addByte(126)
        ..add([length >> 8, length & 0xff]);
    } else {
      header
        ..addByte(127)
        ..add(u64be(length));
    }
    if (payload != null) header.add(payload);
    return header.toBytes();
  }

  test('a message grown out of endless continuation frames is cut off', () async {
    final piece = Uint8List(64 * 1024)..fillRange(0, 64 * 1024, 0x61);
    var sent = 0;
    final server = await rawServer((socket) async {
      socket.add(frame(fin: false, opcode: 1, length: piece.length, payload: piece));
      sent += piece.length;
      for (var i = 0; i < 400; i++) {
        socket.add(frame(fin: false, opcode: 0, length: piece.length, payload: piece));
        sent += piece.length;
        await socket.flush();
      }
    });
    addTearDown(() => server.close());
    final carrier = await factory().open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
    expect(await carrier.receive(timeout: const Duration(seconds: 20)), isNull, reason: 'the carrier closed');
    expect(sent < 400 * piece.length, isTrue, reason: 'it did not wait for the whole 25 MiB');
  });

  test('a frame whose header claims too much is refused before it is read', () async {
    final server = await rawServer((socket) async {
      socket.add(frame(fin: true, opcode: 1, length: 100 * 1024 * 1024));
      socket.add(Uint8List(1024));
    });
    addTearDown(() => server.close());
    final carrier = await factory().open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
    expect(await carrier.receive(timeout: const Duration(seconds: 10)), isNull);
  });

  test('a binary message closes the carrier', () async {
    final server = await rawServer((socket) async {
      socket.add(frame(fin: true, opcode: 2, length: 3, payload: [1, 2, 3]));
    });
    addTearDown(() => server.close());
    final carrier = await factory().open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
    expect(await carrier.receive(timeout: const Duration(seconds: 10)), isNull);
  });

  Future<Object?> openFailure(ServerSocket server) async {
    try {
      final carrier = await factory().open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
      await carrier.close();
      return null;
    } catch (error) {
      return error;
    }
  }

  test('a refusal, a bad accept key or an unrequested extension is not a carrier', () async {
    final unauthorized = await rawServer((_) {}, response: (_) => 'HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\n\r\n');
    final badKey = await rawServer((_) {},
        response: (_) => 'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: AAAA\r\n\r\n');
    final deflate = await rawServer((_) {},
        response: (accept) => 'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
            'Sec-WebSocket-Accept: $accept\r\nSec-WebSocket-Extensions: permessage-deflate\r\n\r\n');
    addTearDown(() async {
      for (final server in [unauthorized, badKey, deflate]) {
        await server.close();
      }
    });
    expect(await openFailure(unauthorized), isA<CarrierUnavailable>().having((e) => e.reason, 'reason', 'unauthorized'));
    expect(await openFailure(badKey), isA<CarrierUnavailable>().having((e) => e.reason, 'reason', 'upgrade'));
    expect(await openFailure(deflate), isA<CarrierUnavailable>().having((e) => e.reason, 'reason', 'upgrade'));
  });

  /// The relay refuses before the upgrade with a plain HTTP status: a revoked
  /// device (403) and a device or host that is gone (404) used to read as
  /// "not a SkidSense endpoint", retried for up to an hour.
  test('the status a refused upgrade was answered with is told apart', () async {
    final statuses = {
      'HTTP/1.1 401 Unauthorized': 'unauthorized',
      'HTTP/1.1 403 Forbidden': 'forbidden',
      'HTTP/1.1 404 Not Found': 'not-found',
      'HTTP/1.1 429 Too Many Requests': 'rate-limited',
      'HTTP/1.1 502 Bad Gateway': 'upgrade',
      'HTTP/1.1 200 OK': 'upgrade',
    };
    for (final MapEntry(key: line, value: reason) in statuses.entries) {
      final server = await rawServer((_) {}, response: (_) => '$line\r\nContent-Length: 2\r\n\r\n{}');
      addTearDown(server.close);
      expect(await openFailure(server), isA<CarrierUnavailable>().having((e) => e.reason, 'reason', reason).having((e) => e.detail, 'detail', line),
          reason: line);
      Object? relayError;
      try {
        await relayFactory(server.port).open(const RouteRelay(), target, timeout: const Duration(seconds: 5));
      } catch (error) {
        relayError = error;
      }
      expect(relayError, isA<CarrierUnavailable>().having((e) => e.reason, 'reason', reason), reason: 'over the relay: $line');
    }
  });

  test('a bearer that cannot be had now is not a sign-out', () async {
    const offline = BackendException('unreachable');
    final failing = IoCarrierFactory(
      backendBase: () => 'https://ai.surise.cn',
      relayPath: () async => null,
      bearer: () async => throw offline,
    );
    await expectLater(
      failing.open(const RouteRelay(), target, timeout: const Duration(seconds: 5)),
      throwsA(isA<CarrierUnavailable>()
          .having((e) => e.reason, 'reason', 'credentials-unavailable')
          .having((e) => e.cause, 'cause', same(offline))),
    );
    final signedOut = IoCarrierFactory(
      backendBase: () => 'https://ai.surise.cn',
      relayPath: () async => null,
      bearer: () async => null,
    );
    await expectLater(
      signedOut.open(const RouteRelay(), target, timeout: const Duration(seconds: 5)),
      throwsA(isA<CarrierUnavailable>().having((e) => e.reason, 'reason', 'no-credentials')),
    );
  });

  /// The relay connection itself, over a real socket: what the backend sees
  /// of the upgrade, and a message each way.
  test('the relay route opens a real connection to the backend', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = Completer<HttpRequest>();
    server.listen((request) async {
      seen.complete(request);
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((message) => socket.add('relayed:$message'));
    });
    addTearDown(() => server.close(force: true));

    final carrier = await relayFactory(server.port, path: '/api/companion/ws')
        .open(const RouteRelay(), target, timeout: const Duration(seconds: 5));
    carrier.send('{"t":"hs1"}');
    expect(await carrier.receive(timeout: const Duration(seconds: 5)), 'relayed:{"t":"hs1"}');
    final request = await seen.future;
    expect(request.uri.path, '/api/companion/ws');
    expect(request.uri.queryParameters, {'role': 'device', 'host_id': 'host-1', 'device_id': 'dev-1'});
    expect(request.headers.value('authorization'), 'Bearer relay-token');
    expect(request.headers.value('host'), '127.0.0.1:${server.port}');
    expect(request.headers.value('origin'), isNull);
    await carrier.close();
  });

  /// The relay answers pings only between frames it forwards, and waits out
  /// the account's bandwidth debt before reading the next: a pong can be a
  /// minute late. `dart:io` drops a socket whose pong is one interval late.
  test('the relay carrier does not hang up on a pong that is late', () async {
    final server = await rawServer((socket) async {
      // Upgraded, then reads nothing and answers nothing.
      await Completer<void>().future;
    });
    addTearDown(server.close);
    final eager = IoCarrierFactory(
      backendBase: () => 'http://127.0.0.1:${server.port}',
      relayPath: () async => null,
      bearer: () async => 'relay-token',
      pingInterval: const Duration(milliseconds: 100),
    );
    final relay = await eager.open(const RouteRelay(), target, timeout: const Duration(seconds: 5));
    await expectLater(relay.receive(timeout: const Duration(seconds: 1)), throwsA(isA<TimeoutException>()),
        reason: 'still open after ten ping intervals');
    await relay.close();

    // The LAN keeps its pings: a desktop answers at once, and a silent one is dead.
    final lan = await eager.open(RouteLan('127.0.0.1', server.port), target, timeout: const Duration(seconds: 5));
    expect(await lan.receive(timeout: const Duration(seconds: 5)), isNull);
  });

  test('a closed port is refused', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    await expectLater(
      factory().open(RouteLan('127.0.0.1', port), target, timeout: const Duration(seconds: 5)),
      throwsA(isA<CarrierUnavailable>()),
    );
  });

  test('the client connects end to end over a real WebSocket', () async {
    final hostStatic = Primitives.generateKeyPair();
    final host = FakeHost('host-1', hostStatic)..handler = (method, _) => {'method': method};
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async => host.serve(_ServerSide(await WebSocketTransformer.upgrade(request))));
    addTearDown(() => server.close(force: true));
    final client = RcClient(
      endpoint: HostEndpoint(
        hostId: 'host-1',
        hostKey: hostStatic.pub,
        deviceId: 'dev-1',
        lanAddrs: ['127.0.0.1'],
        lanPort: server.port,
        relayEnabled: false,
      ),
      identity: Primitives.generateKeyPair(),
      credentials: _Grant(),
      carriers: factory(),
    )..start();
    final connected = await client.states.firstWhere((state) => state is ClientConnected, timeout: const Duration(seconds: 10));
    expect(connected, isA<ClientConnected>());
    expect(await client.call('sessions.list'), {'method': 'sessions.list'});
    await client.stop();
  });

  group('relay URL', () {
    test('is wss on the backend, with the device in the query', () {
      expect(
        IoCarrierFactory.relayUri('https://ai.surise.cn', target).toString(),
        'wss://ai.surise.cn:443/api/companion/ws?role=device&host_id=host-1&device_id=dev-1',
      );
    });

    /// `Uri` knows the default ports of http and https only: a wss URL built
    /// without one says port 0, which is where the relay used to dial — for
    /// the default backend, and for any https one, since `Uri.parse` drops an
    /// explicit :443.
    test('a base without a port gets the default one', () {
      expect(IoCarrierFactory.relayUri('https://ai.surise.cn', target)!.port, 443);
      expect(IoCarrierFactory.relayUri('https://ai.surise.cn:443', target)!.port, 443);
      expect(IoCarrierFactory.relayUri('HTTPS://AI.SURISE.CN/', target)!.port, 443);
      expect(IoCarrierFactory.relayUri('http://localhost', target)!.port, 80);
      expect(IoCarrierFactory.relayUri('http://192.168.1.20:80', target)!.port, 80);
      expect(IoCarrierFactory.relayUri('https://example.com:8443', target)!.port, 8443);
    });

    test('takes the configured path, a base path and a port, and ws for http', () {
      expect(
        IoCarrierFactory.relayUri('https://example.com/sub/', target, '/x/ws').toString(),
        'wss://example.com:443/sub/x/ws?role=device&host_id=host-1&device_id=dev-1',
      );
      expect(
        IoCarrierFactory.relayUri('http://10.0.0.2:3000', target).toString(),
        'ws://10.0.0.2:3000/api/companion/ws?role=device&host_id=host-1&device_id=dev-1',
      );
    });

    test('needs a backend and a device id', () {
      expect(IoCarrierFactory.relayUri(null, target), isNull);
      expect(IoCarrierFactory.relayUri('https://example.com', const CarrierTarget('h', null)), isNull);
    });

    test('a LAN IPv6 address is bracketed', () {
      expect(IoCarrierFactory.lanUri('fd07::1', 47290).toString(), 'ws://[fd07::1]:47290/rc/1');
    });
  });
}

class _Grant extends Credentials {
  @override
  Future<String> grant({required bool fresh}) async => 'grant';
}

/// The server end of a WebSocket as a [Carrier], so [FakeHost] can serve it.
class _ServerSide implements Carrier {
  _ServerSide(this._ws) {
    _ws.listen((message) => _inbox.add(message as String), onDone: _inbox.close);
  }

  final WebSocket _ws;
  final _Queue _inbox = _Queue();

  @override
  String get label => 'server';

  @override
  Future<String?> receive({Duration? timeout}) => _inbox.next();

  @override
  void send(String text) => _ws.add(text);

  @override
  Future<void> close([String reason = '']) => _ws.close();
}

class _Queue {
  final List<String> _items = [];
  Completer<String?>? _waiter;
  bool _closed = false;

  void add(String value) {
    final waiter = _waiter;
    if (waiter != null) {
      _waiter = null;
      waiter.complete(value);
    } else {
      _items.add(value);
    }
  }

  void close() {
    _closed = true;
    _waiter?.complete(null);
    _waiter = null;
  }

  Future<String?> next() {
    if (_items.isNotEmpty) return Future.value(_items.removeAt(0));
    if (_closed) return Future.value(null);
    return (_waiter = Completer<String?>()).future;
  }
}
