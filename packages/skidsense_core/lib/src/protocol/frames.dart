import 'dart:typed_data';

import 'bytes.dart';
import 'crypto_error.dart';
import 'gcm.dart';
import 'outer_frames.dart';
import 'protocol.dart';

/// Data frames (spec §5): `nonce = 4×0x00 ‖ u64be(n)`, `aad = "skidsense-rc/1 d" ‖ u64be(n)`.
abstract final class FrameCrypto {
  static const _labelData = '${Protocol.name} d';

  static Uint8List nonce(int n) => concat([Uint8List(4), u64be(n)]);
  static Uint8List aad(int n) => concat([utf8Bytes(_labelData), u64be(n)]);
}

/// One direction's sealing state. The counter is the nonce: it starts at 0,
/// only goes up, and the sealer refuses to continue past the per-key limits
/// rather than wrap — reusing a GCM nonce under one key leaks the
/// authentication key outright.
class FrameSealer {
  FrameSealer(List<int> key) : _key = GcmKey(key);

  final GcmKey _key;
  int _n = 0;
  int _bytes = 0;

  /// How many frames this key has sealed.
  int get sent => _n;

  DataFrame seal(String plaintext) {
    final data = utf8Bytes(plaintext);
    // The far end refuses anything larger and closes the connection over it
    // (spec §5), so it is refused here, where the caller still has a
    // connection to report the error on.
    if (data.length > Protocol.maxPlaintext) throw CryptoError('too-large', 'message exceeds one frame');
    if (_n >= Protocol.maxFramesPerKey || _bytes + data.length > Protocol.maxBytesPerKey) {
      throw CryptoError('rekey', 'this key has sealed all it may; reconnect');
    }
    final counter = _n;
    _n += 1;
    _bytes += data.length;
    return DataFrame(
      n: counter,
      c: B64u.encode(_key.seal(FrameCrypto.nonce(counter), FrameCrypto.aad(counter), data)),
    );
  }
}

/// The receiving direction. Every carrier is reliable and ordered, so `n`
/// must be exactly the next one: smaller is `replayed`, larger is
/// `out-of-order`, and either ends the connection. Stricter than a replay
/// window on purpose — a frame can only go missing on an ordered stream if
/// something removed it.
class FrameOpener {
  FrameOpener(List<int> key) : _key = GcmKey(key);

  final GcmKey _key;
  int _n = 0;
  int _bytes = 0;

  int get received => _n;

  String open(DataFrame frame) {
    if (frame.n != _n) {
      if (frame.n < _n) throw CryptoError('replayed', 'replayed frame');
      throw CryptoError('out-of-order', 'frame out of order');
    }
    // The per-key limits bind the receiver too (spec §5): a peer that carried
    // on past them is using a key the protocol calls spent.
    if (frame.n >= Protocol.maxFramesPerKey) throw CryptoError('rekey', 'peer passed the per-key frame limit');
    final plaintext = _key.open(FrameCrypto.nonce(frame.n), FrameCrypto.aad(frame.n), B64u.decode(frame.c));
    if (plaintext.length > Protocol.maxPlaintext) throw CryptoError('too-large', 'frame too large');
    if (_bytes + plaintext.length > Protocol.maxBytesPerKey) {
      throw CryptoError('rekey', 'peer passed the per-key byte limit');
    }
    final text = strictUtf8(plaintext);
    _n += 1;
    _bytes += plaintext.length;
    return text;
  }

  /// Test seam: start the counter elsewhere, to reach the per-key limit
  /// without 2^32 frames.
  void startAt(int counter) => _n = counter;
}
