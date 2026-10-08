# skidsense_core

The SkidSense phone client's core, in pure Dart: the `skidsense-rc/1` protocol
(handshake, frames, pairing, history cryptography), the transport to the
desktop (LAN and relay carriers, reconnecting client), the new-api backend
client, and the app's state machines. No Flutter imports, so it is tested
with plain `dart test`.

The normative protocol text is the desktop repo's `docs/remote-control.md`;
`test/fixtures/remote-vectors.json` is that repo's known-answer vector file,
copied verbatim.
