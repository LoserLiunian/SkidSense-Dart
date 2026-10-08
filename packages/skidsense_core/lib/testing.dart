/// Test doubles for code built on the core: an in-memory desktop host that
/// speaks the real protocol (handshake, sealed frames, parted responses,
/// events, uploads, the terminal) over in-memory carriers.
///
/// Not for production use.
library;

export 'src/testing/fake_host.dart';
export 'src/testing/test_responder.dart';
