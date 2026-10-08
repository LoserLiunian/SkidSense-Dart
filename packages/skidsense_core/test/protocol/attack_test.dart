import 'dart:convert';
import 'dart:typed_data';

import 'package:skidsense_core/protocol.dart';
import 'package:test/test.dart';

import 'test_responder.dart';

/// Every way the channel is meant to fail closed — ported from the attack
/// sections of the desktop's `scripts/verify-remote.ts`.
void main() {
  final hostStatic = Primitives.generateKeyPair();
  final clientStatic = Primitives.generateKeyPair();
  final hostId = B64u.encode(Primitives.randomBytes(16));

  String codeOf(void Function() block) {
    try {
      block();
      return '(no error)';
    } on CryptoError catch (error) {
      return error.code;
    } catch (error) {
      return error.toString();
    }
  }

  Initiator connectInitiator([List<int>? hostKey]) => Initiator(
        mode: HandshakeMode.connect,
        hostId: hostId,
        hostStatic: hostKey ?? hostStatic.pub,
        clientStatic: clientStatic,
      );

  (SessionKeys, SessionKeys) connected() {
    final client = connectInitiator();
    final (hs2, hostKeys) = TestResponder(hostId, hostStatic, client.hs1).complete();
    return (client.finish(hs2), hostKeys);
  }

  Uint8List flip(Uint8List bytes, int index) => Uint8List.fromList(bytes)..[index] ^= 1;

  group('handshake', () {
    test('agrees, and hides the device', () {
      final client = connectInitiator();
      final server = TestResponder(hostId, hostStatic, client.hs1);
      expect(server.clientStatic, clientStatic.pub);
      final (hs2, hostKeys) = server.complete();
      final clientKeys = client.finish(hs2);
      expect(clientKeys.send, hostKeys.recv);
      expect(clientKeys.recv, hostKeys.send);
      expect(clientKeys.th, hostKeys.th);
      expect(sameBytes(clientKeys.send, clientKeys.recv), isFalse, reason: 'the two directions use different keys');
      expect(jsonEncode(client.hs1.toJson()).contains(B64u.encode(clientStatic.pub)), isFalse,
          reason: 'hs1 does not show the device key');

      final again = connectInitiator();
      final againKeys = again.finish(TestResponder(hostId, hostStatic, again.hs1).complete().$1);
      expect(sameBytes(againKeys.send, clientKeys.send), isFalse, reason: 'a second handshake derives fresh keys');
    });

    test('a relay with its own static key cannot open hs1', () {
      final relayStatic = Primitives.generateKeyPair();
      expect(codeOf(() => TestResponder(hostId, relayStatic, connectInitiator().hs1)), 'handshake-failed');
    });

    test('a wrong pinned host key fails', () {
      final client = connectInitiator(Primitives.generateKeyPair().pub);
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1)), 'handshake-failed');
    });

    test('a swapped hs2 ephemeral is caught', () {
      final client = connectInitiator();
      final (genuine, _) = TestResponder(hostId, hostStatic, client.hs1).complete();
      final swapped = genuine.copyWith(e: B64u.encode(Primitives.generateKeyPair().pub));
      expect(codeOf(() => client.finish(swapped)), 'handshake-failed');
    });

    test('a forged confirmation is rejected', () {
      final client = connectInitiator();
      final (genuine, _) = TestResponder(hostId, hostStatic, client.hs1).complete();
      expect(codeOf(() => client.finish(genuine.copyWith(c: B64u.encode(Uint8List(32)..fillRange(0, 32, 7))))),
          'handshake-failed');
    });

    test('a handshake for another host is rejected', () {
      final client = connectInitiator();
      expect(codeOf(() => TestResponder(B64u.encode(Primitives.randomBytes(16)), hostStatic, client.hs1)), 'wrong-host');
    });

    test('a malformed hs1 is rejected', () {
      final client = connectInitiator();
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1.copyWith(v: 2))), 'unsupported-version');
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1.copyWith(mode: 'admin'))), 'handshake-failed');
      expect(
        codeOf(() => TestResponder(hostId, hostStatic, client.hs1.copyWith(s: B64u.encode(Uint8List(48)..fillRange(0, 48, 1))))),
        'handshake-failed',
      );
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1.copyWith(e: '${client.hs1.e}='))), 'bad-encoding');
    });

    test('low-order points are rejected', () {
      // All-zero, and points of small order (from the curve25519 small-subgroup list).
      final lowOrder = [
        Uint8List(32),
        hexToBytes('e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800'),
        hexToBytes('0100000000000000000000000000000000000000000000000000000000000000'),
      ];
      for (final point in lowOrder) {
        expect(codeOf(() => Primitives.dh(clientStatic.priv, point)), 'bad-key', reason: bytesToHex(point));
      }
      final client = connectInitiator();
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1.copyWith(e: B64u.encode(Uint8List(32))))), 'bad-key');
      // A device must not start a handshake against a low-order "host key" either…
      expect(codeOf(() => connectInitiator(Uint8List(32))), 'bad-key');
      // …nor accept one as the host's ephemeral.
      final (hs2, _) = TestResponder(hostId, hostStatic, client.hs1).complete();
      expect(codeOf(() => client.finish(hs2.copyWith(e: B64u.encode(Uint8List(32))))), 'bad-key');
    });

    test('enroll needs the right pairing code', () {
      final code = Primitives.randomBytes(32);
      final client = Initiator(
        mode: HandshakeMode.enroll,
        hostId: hostId,
        hostStatic: hostStatic.pub,
        clientStatic: clientStatic,
        psk: code,
      );
      final right = TestResponder(hostId, hostStatic, client.hs1, code);
      expect(right.mode, HandshakeMode.enroll);
      expect(right.clientStatic, clientStatic.pub);

      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1, Primitives.randomBytes(32))), 'handshake-failed');
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1)), 'bad-key');
      // The mode is bound into h0: an enroll hs1 cannot pass as connect.
      expect(codeOf(() => TestResponder(hostId, hostStatic, client.hs1.copyWith(mode: 'connect'))), 'handshake-failed');
      expect(
        codeOf(() => Initiator(
              mode: HandshakeMode.connect,
              hostId: hostId,
              hostStatic: hostStatic.pub,
              clientStatic: clientStatic,
              psk: code,
            )),
        'bad-key',
      );
      expect(
        codeOf(() => Initiator(
              mode: HandshakeMode.enroll,
              hostId: hostId,
              hostStatic: hostStatic.pub,
              clientStatic: clientStatic,
              psk: Uint8List(16),
            )),
        'bad-key',
      );
    });

    test('an enroll with the wrong code fails at the device too', () {
      // A host that somehow opened hs1 with a different code derives
      // different keys; its confirmation does not verify at the device.
      final client = Initiator(
        mode: HandshakeMode.enroll,
        hostId: hostId,
        hostStatic: hostStatic.pub,
        clientStatic: clientStatic,
        psk: Primitives.randomBytes(32),
      );
      final connectClient = connectInitiator();
      final (connectHs2, _) = TestResponder(hostId, hostStatic, connectClient.hs1).complete();
      expect(codeOf(() => client.finish(connectHs2)), 'handshake-failed');
    });
  });

  group('data frames', () {
    test('are strictly ordered', () {
      final (clientKeys, hostKeys) = connected();
      final sealer = FrameSealer(clientKeys.send);
      final opener = FrameOpener(hostKeys.recv);
      final f0 = sealer.seal('第一帧');
      final f1 = sealer.seal('second');
      final f2 = sealer.seal('third');
      expect([f0.n, f1.n, f2.n], [0, 1, 2]);
      expect(opener.open(f0), '第一帧');
      expect(opener.open(f1), 'second');
      expect(codeOf(() => opener.open(f0)), 'replayed');
      expect(codeOf(() => opener.open(f2.copyWith(n: 3))), 'out-of-order');
    });

    test('tampered frames are rejected', () {
      final (clientKeys, hostKeys) = connected();
      final sealer = FrameSealer(clientKeys.send);
      final f0 = sealer.seal('第一帧');
      sealer.seal('second');
      final f2 = sealer.seal('third');
      final raw = B64u.decode(f0.c);

      expect(codeOf(() => FrameOpener(hostKeys.recv).open(f0.copyWith(c: B64u.encode(flip(raw, 0))))), 'bad-frame');
      expect(codeOf(() => FrameOpener(hostKeys.recv).open(f0.copyWith(c: B64u.encode(flip(raw, raw.length - 1))))),
          'bad-frame');
      expect(codeOf(() => FrameOpener(hostKeys.recv).open(f0.copyWith(c: B64u.encode(raw.sublist(0, 10))))), 'bad-frame');

      // n is in the AAD as well as the nonce: relabelling frame 2 as frame 1 fails.
      final relabel = FrameOpener(hostKeys.recv)..open(f0);
      expect(codeOf(() => relabel.open(f2.copyWith(n: 1))), 'bad-frame');

      // Directions do not mix: a device frame does not open under the host's send key.
      expect(codeOf(() => FrameOpener(hostKeys.send).open(f0)), 'bad-frame');
    });

    test('a failed frame does not advance the counter', () {
      final (clientKeys, hostKeys) = connected();
      final f0 = FrameSealer(clientKeys.send).seal('x');
      final opener = FrameOpener(hostKeys.recv);
      expect(codeOf(() => opener.open(f0.copyWith(c: B64u.encode(flip(B64u.decode(f0.c), 0))))), 'bad-frame');
      expect(opener.received, 0);
    });

    test('invalid UTF-8 plaintext is rejected', () {
      final (clientKeys, hostKeys) = connected();
      // Seal raw bytes that are not UTF-8 (a lone continuation byte), bypassing FrameSealer.
      final sealed = Primitives.seal(clientKeys.send, FrameCrypto.nonce(0), FrameCrypto.aad(0), [0x41, 0x80]);
      expect(codeOf(() => FrameOpener(hostKeys.recv).open(DataFrame(n: 0, c: B64u.encode(sealed)))), 'bad-frame');
      // An encoded surrogate (CESU-8 style) is not UTF-8 either.
      final surrogate = Primitives.seal(clientKeys.send, FrameCrypto.nonce(0), FrameCrypto.aad(0), [0xED, 0xA0, 0x80]);
      expect(codeOf(() => FrameOpener(hostKeys.recv).open(DataFrame(n: 0, c: B64u.encode(surrogate)))), 'bad-frame');
    });
  });

  group('key wrap and history', () {
    test('a key wrap is bound to its recipient and epoch', () {
      final recipient = Primitives.generateKeyPair();
      final key = Primitives.randomBytes(32);
      final context = HistoryCrypto.wrapContext(hostId, 1);
      final wrapped = HistoryCrypto.wrapKey(key, recipient.pub, context);
      expect(wrapped.length, 80);
      expect(HistoryCrypto.unwrapKey(wrapped, recipient, context), key);
      expect(() => HistoryCrypto.unwrapKey(wrapped, Primitives.generateKeyPair(), context), throwsA(isA<CryptoError>()));
      expect(() => HistoryCrypto.unwrapKey(wrapped, recipient, HistoryCrypto.wrapContext(hostId, 2)),
          throwsA(isA<CryptoError>()));
      expect(() => HistoryCrypto.unwrapKey(wrapped, recipient, HistoryCrypto.wrapContext('other-host', 1)),
          throwsA(isA<CryptoError>()));
      expect(() => HistoryCrypto.unwrapKey(wrapped.sublist(0, 79), recipient, context), throwsA(isA<CryptoError>()));
    });

    test('a history blob is bound to its session', () {
      final key = Primitives.randomBytes(32);
      final aad = HistoryCrypto.historyAad(hostId, 'claude:abc', 1);
      final blob = HistoryCrypto.sealBlob(key, aad, utf8Bytes('历史'));
      expect(utf8.decode(HistoryCrypto.openBlob(key, aad, blob)), '历史');
      expect(() => HistoryCrypto.openBlob(key, HistoryCrypto.historyAad(hostId, 'claude:other', 1), blob),
          throwsA(isA<CryptoError>()));
      expect(() => HistoryCrypto.openBlob(key, HistoryCrypto.historyAad(hostId, 'claude:abc', 2), blob),
          throwsA(isA<CryptoError>()));
      final again = HistoryCrypto.sealBlob(key, aad, utf8Bytes('历史'));
      expect(sameBytes(blob.sublist(0, 12), again.sublist(0, 12)), isFalse, reason: 'nonces differ');
    });
  });

  test('base64url is strict', () {
    final bytes = Uint8List.fromList([251, 255, 0, 63]);
    final text = B64u.encode(bytes);
    expect(text, '-_8APw');
    expect(B64u.decode(text), bytes);
    expect(codeOf(() => B64u.decode('$text==')), 'bad-encoding', reason: 'padding');
    expect(codeOf(() => B64u.decode('+/8APw')), 'bad-encoding', reason: 'standard alphabet');
    expect(codeOf(() => B64u.decode('-_8AP')), 'bad-encoding', reason: 'length % 4 == 1');
    expect(codeOf(() => B64u.decode('-_8APx')), 'bad-encoding', reason: 'non-canonical trailing bits');
    expect(codeOf(() => B64u.decode('-_8A Pw')), 'bad-encoding', reason: 'whitespace');
    expect(codeOf(() => B64u.decode(text, 5)), 'bad-encoding', reason: 'wrong length');
    expect(B64u.decode(''), isEmpty);
  });

  group('pairing payload', () {
    String encodePairing(String fields) => Protocol.pairingUrlPrefix + B64u.encode(utf8Bytes(fields));

    test('decodes', () {
      final k = B64u.encode(hostStatic.pub);
      final c = B64u.encode(Primitives.randomBytes(32));
      final link = encodePairing(
        '{"v":1,"n":"$hostId","k":"$k","c":"$c","h":["192.168.1.20","10.0.0.5"],"p":47290,"s":"https://ai.surise.cn","m":"书房的 Mac"}',
      );
      final payload = Pairing.decode(link);
      expect(payload.hostId, hostId);
      expect(payload.hostKey, hostStatic.pub);
      expect(payload.lanAddrs, ['192.168.1.20', '10.0.0.5']);
      expect(payload.lanPort, 47290);
      expect(payload.machine, '书房的 Mac');
      expect(Pairing.decode(link.substring(Protocol.pairingUrlPrefix.length)), payload, reason: 'bare payload works');
      expect(Pairing.decode('  $link\n'), payload, reason: 'surrounding whitespace is ignored');
      expect(payload.fingerprint, hostFingerprint(hostStatic.pub));
    });

    test('rejects bad payloads', () {
      PairingProblem? problemOf(String text) {
        try {
          Pairing.decode(text);
          return null;
        } on PairingFormatException catch (error) {
          return error.problem;
        }
      }

      expect(problemOf('skidsense://pair/1?d=!!!'), PairingProblem.invalid);
      expect(problemOf('skidsense://pair/2?d=abc'), PairingProblem.appTooOld);
      final c = B64u.encode(Primitives.randomBytes(32));
      final shortKey = B64u.encode(Uint8List(16));
      expect(problemOf(encodePairing('{"v":1,"n":"x","k":"$shortKey","c":"$c","h":[],"p":1,"s":"s","m":"m"}')),
          PairingProblem.badHostKey);
      final k = B64u.encode(hostStatic.pub);
      expect(problemOf(encodePairing('{"v":2,"n":"x","k":"$k","c":"$c","h":[],"p":1,"s":"s","m":"m"}')),
          PairingProblem.unsupportedVersion);
      expect(problemOf(encodePairing('{"v":1,"k":"$k","c":"$c","h":[],"p":1,"s":"s","m":"m"}')), PairingProblem.invalid);
    });
  });

  test('backend URLs compare normalised', () {
    expect(normalizeBackendUrl('HTTPS://AI.surise.cn/'), normalizeBackendUrl('https://ai.surise.cn'));
    expect(normalizeBackendUrl('https://ai.surise.cn:443'), normalizeBackendUrl('https://ai.surise.cn'));
    expect(normalizeBackendUrl('http://ai.surise.cn'), isNot(normalizeBackendUrl('https://ai.surise.cn')));
    expect(normalizeBackendUrl('https://evil.example'), isNot(normalizeBackendUrl('https://ai.surise.cn')));
  });

  test('fingerprint format', () {
    expect(hostFingerprint(Primitives.randomBytes(32)), matches(RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$')));
  });
}
