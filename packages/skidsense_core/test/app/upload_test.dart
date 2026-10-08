import 'dart:typed_data';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';

class _Grant extends Credentials {
  @override
  Future<String> grant({required bool fresh}) async => 'grant';
}

/// The upload contract from the client side, against a host that implements
/// the desktop's own rules (`src/main/remote/uploads.ts`): a declared size,
/// chunks at exactly consecutive offsets, 384 KiB raw per chunk, 20 MiB per
/// file, 8 open at once, and a `turn.prompt` that consumes the ids.
void main() {
  final hostStatic = Primitives.generateKeyPair();
  final hostId = B64u.encode(Primitives.randomBytes(16));

  Future<(RcClient, FakeHost, UploadManager)> setUp() async {
    final host = FakeHost(hostId, hostStatic)..handler = (method, _) => method;
    final client = RcClient(
      endpoint: HostEndpoint(hostId: hostId, hostKey: hostStatic.pub, deviceId: 'dev-1', lanAddrs: ['192.168.1.20'], lanPort: 47290),
      identity: Primitives.generateKeyPair(),
      credentials: _Grant(),
      carriers: FakeCarriers()..lan = (_) => host,
    )..start();
    await client.states.firstWhere((state) => state is ClientConnected, timeout: const Duration(seconds: 30));
    final uploads = UploadManager(
      call: (method, params) async {
        final answer = await client.call(method, params);
        return answer is Map<String, Object?> ? answer : null;
      },
      connectionMarker: () => client.connectionMarker,
    );
    return (client, host, uploads);
  }

  Uint8List bytes(int size) => Uint8List.fromList(List.generate(size, (i) => i % 251));

  test('a small file goes in one chunk and is consumed by the prompt', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        final upload = await uploads.begin('note.txt', 'text/plain', bytes(1000));
        expect(upload.complete, isTrue);
        expect(host.uploads[upload.id]?.received, 1000);
        expect(host.uploads[upload.id]?.bytes.toBytes(), bytes(1000));
        expect(host.calls.map((call) => call.$1), ['upload.begin', 'upload.chunk']);
        expect(uploads.take('claude:1').map((u) => u.id), [upload.id]);
        expect(uploads.count, 0, reason: 'taking the ids forgets them');
        await client.stop();
      }));

  /// A prompt the desktop does not accept leaves the uploads there (spec §7):
  /// a retry names the same ids and sends none of the bytes again.
  test('taken uploads go back when the prompt is refused', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        final upload = await uploads.begin('keep.txt', 'text/plain', bytes(10));
        final taken = uploads.take('claude:1');
        expect(uploads.count, 0);
        uploads.restore(taken);
        expect(uploads.take('claude:1').map((u) => u.id), [upload.id]);
        expect(host.calls.map((call) => call.$1), ['upload.begin', 'upload.chunk'], reason: 'nothing was sent again');
        await client.stop();
      }));

  test('a large file is sliced at the chunk limit, at contiguous offsets', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        final size = Protocol.uploadChunk * 2 + 123;
        final upload = await uploads.begin('photo.jpg', 'image/jpeg', bytes(size));
        expect(host.uploads[upload.id]?.received, size);
        final chunks = host.calls.where((call) => call.$1 == 'upload.chunk').map((call) => call.$2! as Map<String, Object?>).toList();
        expect(chunks.map((chunk) => chunk['offset']), [0, Protocol.uploadChunk, Protocol.uploadChunk * 2]);
        expect(chunks.map((chunk) => B64u.decode(chunk['data']! as String).length), [Protocol.uploadChunk, Protocol.uploadChunk, 123]);
        await client.stop();
      }));

  test('a host that disagrees about the offset kills the upload', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        host.uploadReceivedOverride = 7;
        await expectLater(
          uploads.begin('c.bin', null, bytes(500)),
          throwsA(isA<RcException>().having((e) => e.code, 'code', 'upload-desync')),
        );
        expect(host.uploads, isEmpty, reason: 'an aborted upload is not left open on the host');
        expect(uploads.take('claude:1'), isEmpty, reason: 'nothing unfinished is handed over');
        await client.stop();
      }));

  test('too many open uploads are refused', () => runFake((_) async {
        final (client, _, uploads) = await setUp();
        for (var index = 0; index < 8; index++) {
          await uploads.begin('f$index.bin', null, bytes(16));
        }
        await expectLater(
          uploads.begin('ninth.bin', null, bytes(16)),
          throwsA(isA<RcException>().having((e) => e.code, 'code', 'too-many-uploads')),
        );
        await client.stop();
      }));

  test('oversize files are refused before anything is sent', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        await expectLater(
          uploads.begin('huge.bin', null, Uint8List(Protocol.maxUpload + 1)),
          throwsA(isA<RcException>().having((e) => e.code, 'code', 'upload-too-large')),
        );
        expect(host.calls, isEmpty);
        await client.stop();
      }));

  test('abort removes the upload on both sides', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        final upload = await uploads.begin('x.bin', null, bytes(32));
        expect(host.uploads, hasLength(1));
        await uploads.abort(upload.id);
        expect(host.uploads, isEmpty);
        expect(uploads.count, 0);
        await uploads.begin('y.bin', null, bytes(32), sessionKey: 'claude:1');
        await uploads.begin('z.bin', null, bytes(32), sessionKey: 'claude:2');
        await uploads.abortAll('claude:1');
        expect(host.uploads, hasLength(1), reason: 'only that session’s');
        await client.stop();
      }));

  test('a real prompt carries the upload ids under sessionKey', () => runFake((_) async {
        final (client, host, uploads) = await setUp();
        final first = await uploads.begin('one.txt', 'text/plain', bytes(128));
        final second = await uploads.begin('two.txt', 'text/plain', bytes(Protocol.uploadChunk + 1));
        final ids = [for (final upload in uploads.take('claude:1')) upload.id];
        expect(ids, [first.id, second.id]);
        await client.call('turn.prompt', {'sessionKey': 'claude:1', 'prompt': '看这两个文件', 'uploads': ids});
        final sent = host.calls.lastWhere((call) => call.$1 == 'turn.prompt').$2! as Map<String, Object?>;
        expect(sent['uploads'], ids);
        expect(sent.containsKey('sessionKey'), isTrue);
        expect(sent.containsKey('key'), isFalse);
        await client.stop();
      }));
}
