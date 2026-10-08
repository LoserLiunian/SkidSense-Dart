import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:skidsense_core/protocol.dart';
import 'package:test/test.dart';

import 'test_responder.dart';

/// Known-answer vectors (spec §15), copied verbatim from the desktop repo's
/// `scripts/fixtures/remote-vectors.json`: from `input`, reproduce `output`
/// byte for byte, then run the outputs backwards — open the frames, unwrap
/// the key, open the blob, verify the grant.
void main() {
  final root = jsonDecode(File('test/fixtures/remote-vectors.json').readAsStringSync()) as Map<String, Object?>;
  final input = root['input']! as Map<String, Object?>;
  final output = root['output']! as Map<String, Object?>;
  Map<String, Object?> obj(Map<String, Object?> from, String key) => from[key]! as Map<String, Object?>;
  String str(Map<String, Object?> from, String key) => from[key]! as String;

  final hostId = str(input, 'hostId');
  final hostStatic = Primitives.keyPairFromPrivate(hexToBytes(str(input, 'hostStaticPriv')));
  final clientStatic = Primitives.keyPairFromPrivate(hexToBytes(str(input, 'clientStaticPriv')));
  final clientEphemeral = Primitives.keyPairFromPrivate(hexToBytes(str(input, 'clientEphemeralPriv')));
  final hostEphemeral = Primitives.keyPairFromPrivate(hexToBytes(str(input, 'hostEphemeralPriv')));
  final psk = hexToBytes(str(input, 'psk'));

  test('the vector file is this protocol', () {
    expect(root['protocol'], Protocol.name);
  });

  test('public keys from private keys', () {
    expect(B64u.encode(hostStatic.pub), str(output, 'hostStaticPub'));
    expect(B64u.encode(clientStatic.pub), str(output, 'clientStaticPub'));
    expect(B64u.encode(clientEphemeral.pub), str(output, 'clientEphemeralPub'));
    expect(B64u.encode(hostEphemeral.pub), str(output, 'hostEphemeralPub'));
  });

  test('handshake hashes', () {
    expect(B64u.encode(Handshake.handshakeHash(HandshakeMode.enroll, hostId)), str(output, 'h0Enroll'));
    expect(B64u.encode(Handshake.handshakeHash(HandshakeMode.connect, hostId)), str(output, 'h0Connect'));
  });

  void checkHandshake(HandshakeMode mode, String key) {
    final expected = obj(output, key);
    final usePsk = mode == HandshakeMode.enroll ? psk : null;

    final client = Initiator(
      mode: mode,
      hostId: hostId,
      hostStatic: hostStatic.pub,
      clientStatic: clientStatic,
      psk: usePsk,
      ephemeral: clientEphemeral,
    );
    expect(OuterFrames.encode(client.hs1.toJson()), jsonEncode(expected['hs1']), reason: 'hs1 ($key)');

    final server = TestResponder(hostId, hostStatic, client.hs1, usePsk);
    expect(server.clientStatic, clientStatic.pub, reason: 'the host recovers the device static key');
    final (hs2, hostKeys) = server.complete(hostEphemeral);
    expect(OuterFrames.encode(hs2.toJson()), jsonEncode(expected['hs2']), reason: 'hs2 ($key)');

    final clientKeys = client.finish(hs2);
    expect(B64u.encode(clientKeys.send), str(expected, 'c2s'), reason: 'c2s ($key)');
    expect(B64u.encode(clientKeys.recv), str(expected, 's2c'), reason: 's2c ($key)');
    expect(B64u.encode(clientKeys.th), str(expected, 'th'), reason: 'th ($key)');
    expect(clientKeys.send, hostKeys.recv);
    expect(clientKeys.recv, hostKeys.send);

    final messages = obj(input, 'messages');
    final c2sTexts = (messages['c2s']! as List).cast<String>();
    final s2cTexts = (messages['s2c']! as List).cast<String>();

    final c2sSealer = FrameSealer(clientKeys.send);
    final s2cSealer = FrameSealer(hostKeys.send);
    expect(
      [for (final text in c2sTexts) OuterFrames.encode(c2sSealer.seal(text).toJson())],
      [for (final frame in expected['framesC2s']! as List) jsonEncode(frame)],
      reason: 'framesC2s ($key)',
    );
    expect(
      [for (final text in s2cTexts) OuterFrames.encode(s2cSealer.seal(text).toJson())],
      [for (final frame in expected['framesS2c']! as List) jsonEncode(frame)],
      reason: 'framesS2c ($key)',
    );

    // Backwards: open the vector's frames and get the original text.
    final hostOpener = FrameOpener(hostKeys.recv);
    expect(
      [
        for (final frame in expected['framesC2s']! as List)
          hostOpener.open((OuterFrames.parseObject(frame as Map<String, Object?>) as OuterData).frame),
      ],
      c2sTexts,
    );
    final clientOpener = FrameOpener(clientKeys.recv);
    expect(
      [
        for (final frame in expected['framesS2c']! as List)
          clientOpener.open((OuterFrames.parseObject(frame as Map<String, Object?>) as OuterData).frame),
      ],
      s2cTexts,
    );
  }

  test('enroll handshake and frames', () => checkHandshake(HandshakeMode.enroll, 'enroll'));
  test('connect handshake and frames', () => checkHandshake(HandshakeMode.connect, 'connect'));

  test('key wrap', () {
    final wrapInput = obj(input, 'wrap');
    final wrapOut = obj(output, 'wrap');
    final epoch = wrapInput['epoch']! as int;
    final context = HistoryCrypto.wrapContext(hostId, epoch);
    expect(B64u.encode(clientStatic.pub), str(wrapOut, 'recipientPub'));
    expect(B64u.encode(context), str(wrapOut, 'context'));

    final key = hexToBytes(str(wrapInput, 'key'));
    final ephemeral = Primitives.keyPairFromPrivate(hexToBytes(str(wrapInput, 'ephemeralPriv')));
    final wrapped = HistoryCrypto.wrapKey(key, clientStatic.pub, context, ephemeral: ephemeral);
    expect(B64u.encode(wrapped), str(wrapOut, 'wrapped'));

    // Backwards: the device unwraps the vector's bytes with its static key.
    expect(HistoryCrypto.unwrapKey(B64u.decode(str(wrapOut, 'wrapped')), clientStatic, context), key);
  });

  test('history blob', () {
    final blobInput = obj(input, 'blob');
    final blobOut = obj(output, 'blob');
    final epoch = blobInput['epoch']! as int;
    final aad = HistoryCrypto.historyAad(hostId, str(blobInput, 'sessionKey'), epoch);
    expect(B64u.encode(aad), str(blobOut, 'aad'));

    final key = hexToBytes(str(blobInput, 'key'));
    final plaintext = str(blobInput, 'plaintext');
    final blob = HistoryCrypto.sealBlob(key, aad, utf8Bytes(plaintext), nonce: hexToBytes(str(blobInput, 'nonce')));
    expect(B64u.encode(blob), str(blobOut, 'blob'));
    expect(utf8.decode(HistoryCrypto.openBlob(key, aad, B64u.decode(str(blobOut, 'blob')))), plaintext);
  });

  test('grant token', () async {
    // The phone never verifies grants (the host does); this only proves the
    // Ed25519 path and the claims serialisation agree with the reference.
    final grantInput = obj(input, 'grant');
    final grantOut = obj(output, 'grant');
    final ed25519 = DartEd25519();
    final keyPair = await ed25519.newKeyPairFromSeed(hexToBytes(str(grantInput, 'seed')));
    final publicKey = await keyPair.extractPublicKey();
    expect(B64u.encode(publicKey.bytes), str(grantOut, 'publicKey'));

    final claims = obj(grantOut, 'claims');
    expect(claims['dpk'], B64u.encode(clientStatic.pub));
    final body = B64u.encode(utf8Bytes(jsonEncode(claims)));
    final signature = await ed25519.sign(utf8Bytes(body), keyPair: keyPair);
    // Pure-Dart Ed25519 is RFC 8032's deterministic signature: byte for byte.
    expect('$body.${B64u.encode(signature.bytes)}', str(grantOut, 'token'));

    final parts = str(grantOut, 'token').split('.');
    expect(parts[0], body);
    expect(
      await ed25519.verify(
        utf8Bytes(parts[0]),
        signature: Signature(B64u.decode(parts[1], 64), publicKey: publicKey),
      ),
      isTrue,
    );
  });

  test('host fingerprint', () {
    expect(hostFingerprint(hostStatic.pub), str(output, 'fingerprint'));
    expect(hostFingerprint(hostStatic.pub), 'D511-0BBB-BA1D-667B');
  });
}
