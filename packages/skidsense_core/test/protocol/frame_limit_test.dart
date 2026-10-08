import 'package:skidsense_core/protocol.dart';
import 'package:test/test.dart';

/// The per-frame and per-key limits (spec §5), from both ends. The receiving
/// side refuses a frame past the limit itself, as the desktop does, rather
/// than trusting the peer to stop at 2^32 frames.
void main() {
  final key = Primitives.randomBytes(32);

  /// A frame at counter [n], built the way the protocol defines one — which
  /// no conforming sealer emits past the limit.
  DataFrame forge(int n, String text) => DataFrame(
        n: n,
        c: B64u.encode(Primitives.seal(key, FrameCrypto.nonce(n), FrameCrypto.aad(n), utf8Bytes(text))),
      );

  test('the sealer refuses a message over one frame', () {
    final sealer = FrameSealer(key);
    expect(
      () => sealer.seal('好' * (Protocol.maxPlaintext ~/ 3 + 1)),
      throwsA(isA<CryptoError>().having((e) => e.code, 'code', 'too-large')),
    );
    expect(sealer.sent, 0, reason: 'a refused seal spends no counter value');
  });

  test('the opener refuses a peer past the per-key frame limit', () {
    final opener = FrameOpener(key)..startAt(Protocol.maxFramesPerKey - 1);
    expect(opener.open(forge(Protocol.maxFramesPerKey - 1, 'last')), 'last', reason: 'the forged frame is well formed');
    expect(
      () => opener.open(forge(Protocol.maxFramesPerKey, 'over')),
      throwsA(isA<CryptoError>().having((e) => e.code, 'code', 'rekey')),
    );
  });

  test('the opener refuses a plaintext over one frame', () {
    expect(
      () => FrameOpener(key).open(forge(0, 'x' * (Protocol.maxPlaintext + 1))),
      throwsA(isA<CryptoError>().having((e) => e.code, 'code', 'too-large')),
    );
  });

  test('the outer frame limit is counted in bytes', () {
    String hsr(String fill) => '{"t":"hsr","code":"x","message":"$fill"}';
    final envelope = hsr('').length;
    final exactAscii = hsr('a' * (Protocol.maxFrame - envelope));
    expect(utf8Length(exactAscii), Protocol.maxFrame);
    expect(OuterFrames.parse(exactAscii), isA<OuterReject>(), reason: 'exactly maxFrame bytes is a frame');
    expect(
      () => OuterFrames.parse(hsr('a' * (Protocol.maxFrame - envelope + 1))),
      throwsA(isA<CryptoError>().having((e) => e.code, 'code', 'too-large')),
    );

    final cjk = hsr('好' * ((Protocol.maxFrame - envelope) ~/ 3 + 1));
    expect(cjk.length < Protocol.maxFrame, isTrue, reason: 'fewer code units than the limit…');
    expect(utf8Length(cjk) > Protocol.maxFrame, isTrue, reason: '…but more bytes');
    expect(() => OuterFrames.parse(cjk), throwsA(isA<CryptoError>().having((e) => e.code, 'code', 'too-large')));
  });

  test('utf8Length counts bytes, not code units', () {
    expect(utf8Length('a'), 1);
    expect(utf8Length('é'), 2);
    expect(utf8Length('好'), 3);
    expect(utf8Length('😀'), 4);
    expect(utf8Length('\uD83D'), 3, reason: 'a lone surrogate counts as U+FFFD');
    const text = 'a好😀é，混合 text 与 emoji 🎉';
    expect(utf8Length(text), utf8Bytes(text).length);
  });
}
